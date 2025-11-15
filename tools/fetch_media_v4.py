#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fetch_media_v6.py
- Imagen de portada = Wikimedia Commons (search filetype:bitmap) -> fallback GBIF (occurrence media StillImage)
- Espectrograma = Xeno-Canto (recordings[].sono.med o .small) con fix de 'https:'
- NO descarga audio.
- Actualiza assets en offline_db.json: image_cover y spectrograms[0]

REQUISITOS:
  pip install requests
  (si vas a construir JSON desde Excel: pip install pandas openpyxl)
"""

import argparse, json, os, time, unicodedata, re, pathlib, sys
from typing import Optional, Dict, Any, List
import requests

UA = "MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)"
HEADERS = {"User-Agent": UA}

def slugify(t: str) -> str:
    t = unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", t.lower()).strip("_")

def ensure_folder(p: pathlib.Path): p.mkdir(parents=True, exist_ok=True)
def save_bytes(p: pathlib.Path, b: bytes): open(p, "wb").write(b)

# -------------------- HELPERS URL --------------------
def _is_image_url(u: Optional[str]) -> bool:
    if not u: return False
    url = u.lower()
    if not (url.startswith("http://") or url.startswith("https://")): return False
    if url.endswith(".svg") or "format=svg" in url: return False
    return url.endswith(".jpg") or url.endswith(".jpeg") or url.endswith(".png") \
           or ".jpg?" in url or ".jpeg?" in url or ".png?" in url

# -------------------- COMMONS (igual a tu Dart) --------------------
def commons_first_bitmap(scientific_name: str) -> Optional[str]:
    """Usa generator=search, gsrsearch='<sci> filetype:bitmap', iiprop=url, iiurlwidth=1024; devuelve thumburl/url."""
    try:
        params = {
            "action": "query",
            "generator": "search",
            "gsrsearch": f"{scientific_name} filetype:bitmap",
            "gsrlimit": "30",
            "prop": "imageinfo",
            "iiprop": "url",
            "iiurlwidth": "1024",
            "format": "json",
            "origin": "*",
        }
        r = requests.get("https://commons.wikimedia.org/w/api.php",
                         params=params, headers=HEADERS, timeout=25)
        if r.status_code != 200:
            return None
        j = r.json()
        pages: Dict[str, Any] = (j.get("query", {}) or {}).get("pages", {}) or {}
        # mismas reglas de tu _isImage
        for p in pages.values():
            ii = p.get("imageinfo", []) or []
            if not ii: continue
            url = ii[0].get("thumburl") or ii[0].get("url")
            if _is_image_url(url):
                return url
        return None
    except Exception:
        return None

# -------------------- GBIF (igual lógica a tu Dart) --------------------
def gbif_taxon_key(scientific_name: str) -> Optional[int]:
    """Busca taxonKey por nombre científico: /species/match o /species?name=..."""
    try:
        r = requests.get("https://api.gbif.org/v1/species/match",
                         params={"name": scientific_name},
                         headers=HEADERS, timeout=20)
        if r.status_code != 200: return None
        j = r.json()
        key = j.get("usageKey") or j.get("speciesKey") or j.get("acceptedUsageKey")
        return int(key) if key else None
    except Exception:
        return None

def gbif_first_occurrence_image(taxon_key: int) -> Optional[str]:
    """Devuelve el primer media.identifier que sea imagen de /occurrence/search?mediaType=StillImage&hasCoordinate=true"""
    try:
        r = requests.get("https://api.gbif.org/v1/occurrence/search",
                         params={"taxonKey": str(taxon_key), "mediaType": "StillImage", "hasCoordinate": "true", "limit": "200"},
                         headers=HEADERS, timeout=30)
        if r.status_code != 200: return None
        j = r.json()
        results = j.get("results", []) or []
        for item in results:
            media = item.get("media", []) or []
            for mm in media:
                id_ = mm.get("identifier") or mm.get("references")
                if _is_image_url(id_):
                    return id_
        return None
    except Exception:
        return None

# -------------------- XENO-CANTO (spectrograma) --------------------
def xeno_sono_png(scientific_name: str) -> Optional[str]:
    """recordings[0].sono.med o .small; corrige esquema 'https:' si viene '//...'"""
    try:
        r = requests.get("https://xeno-canto.org/api/2/recordings",
                         params={"query": scientific_name},
                         headers=HEADERS, timeout=30)
        if r.status_code != 200: return None
        recs = (r.json().get("recordings", []) or [])
        if not recs: return None
        sono = recs[0].get("sono", {}) or {}
        url = sono.get("med") or sono.get("small")
        if url and url.startswith("//"):
            url = "https:" + url
        return url
    except Exception:
        return None

# -------------------- FETCH --------------------
def fetch(db_path: str, out_db: str, base_dir: str, delay: float = 1.5, overwrite: bool = False):
    db = json.load(open(db_path, encoding="utf-8"))
    updated = False
    species: List[Dict[str, Any]] = db.get("species", []) or []

    for i, sp in enumerate(species, start=1):
        sci = (sp.get("scientific_name") or "").strip()
        sid = sp.get("species_id") or slugify(sci)
        folder = pathlib.Path(base_dir) / sid
        ensure_folder(folder)
        print(f"[{i}/{len(species)}] {sci or sid}")

        # --- IMAGEN (Commons -> GBIF) ---
        cover = folder / "cover.jpg"
        if overwrite or not cover.exists():
            # 1) Commons
            img_url = commons_first_bitmap(sci)
            # 2) GBIF si falla Commons
            if not img_url:
                key = gbif_taxon_key(sci)
                if key:
                    img_url = gbif_first_occurrence_image(key)

            if img_url:
                try:
                    ri = requests.get(img_url, headers=HEADERS, timeout=60)
                    if ri.ok and ri.content:
                        save_bytes(cover, ri.content)
                        sp.setdefault("assets", {}).setdefault("image_cover", f"assets/aves/{sid}/cover.jpg")
                        sp.setdefault("sources", {}).setdefault("attribution", []).append({
                            "type": "image",
                            "source": "Wikimedia Commons" if "wikimedia" in img_url.lower() or "wikipedia" in img_url.lower() else "GBIF",
                            "url": img_url
                        })
                        print("  image: OK")
                        updated = True
                    else:
                        print("  image: FAIL (download)")
                except Exception as e:
                    print("  image: ERROR", e)
            else:
                print("  image: not found")
            time.sleep(delay)
        else:
            print("  image: skip (exists)")

        # --- ESPECTROGRAMA (Xeno-Canto) ---
        spec = folder / "spec_1.png"
        if overwrite or not spec.exists():
            sono = xeno_sono_png(sci)
            if sono:
                try:
                    rs = requests.get(sono, headers=HEADERS, timeout=60)
                    if rs.ok and rs.content:
                        save_bytes(spec, rs.content)
                        sp.setdefault("assets", {}).setdefault("spectrograms", [f"assets/aves/{sid}/spec_1.png"])
                        sp.setdefault("sources", {}).setdefault("attribution", []).append({
                            "type": "spectrogram",
                            "source": "Xeno-Canto",
                            "url": sono
                        })
                        print("  spectrogram: OK")
                        updated = True
                    else:
                        print("  spectrogram: FAIL (download)")
                except Exception as e:
                    print("  spectrogram: ERROR", e)
            else:
                print("  spectrogram: not found")
            time.sleep(delay)
        else:
            print("  spectrogram: skip (exists)")

    if updated:
        json.dump(db, open(out_db, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print(f"[fetch] DB actualizada en {out_db}")
    else:
        print("[fetch] Sin cambios")

# -------------------- MAIN --------------------
def main():
    ap = argparse.ArgumentParser(description="MuroBird fetch v6 (Commons/GBIF image + XenoCanto spectrogram)")
    ap.add_argument("--db", required=True, help="Ruta a assets/offline/offline_db.json")
    ap.add_argument("--out-db", required=True, help="Ruta de salida para JSON actualizado")
    ap.add_argument("--base-dir", required=True, help="Carpeta base de assets (p.ej. assets/aves)")
    ap.add_argument("--delay", type=float, default=2.0)
    ap.add_argument("--overwrite", action="store_true")
    args = ap.parse_args()
    fetch(args.db, args.out_db, args.base_dir, args.delay, args.overwrite)

if __name__ == "__main__":
    main()
