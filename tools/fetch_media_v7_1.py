#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fetch_meta_v7_1.py
Descripción (Wikipedia es/en) + Distribución (GBIF -> GeoJSON)
- Guardado inmediato por especie (write-through) para evitar pérdidas.
- Logs con longitud de texto guardado.
- Filtro para no escribir strings vacías.
- Opción --only "<scientific name>" para depurar una especie.
"""

import argparse, json, time, re, unicodedata, pathlib, sys
from typing import Optional, Dict, Any, List
import requests

UA = "MuroBird/1.6.1 (https://example.com; contacto: dev@murobird.app)"
HEADERS = {"User-Agent": UA}

def ensure_folder(p: pathlib.Path): p.mkdir(parents=True, exist_ok=True)

def write_json(path: pathlib.Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def smart_capitalize(s: str) -> str:
    if not s: return s
    parts = s.split()
    if not parts: return s
    parts[0] = parts[0][:1].upper() + parts[0][1:]
    return " ".join(parts)

def extract_binomial(text: str) -> Optional[str]:
    m = re.search(r"\b([A-Z][a-z]+ [a-z]+)\b", smart_capitalize(text or ""))
    return m.group(1) if m else None

def candidate_queries(raw: str) -> List[str]:
    out = set()
    s = (raw or "").strip().replace("_", " ")
    s = re.sub(r"\s*[-–—]\s*", " ", s)
    s = re.sub(r"\s*\(.*?\)\s*$", "", s).strip()
    if s: out.add(s)
    if "," in s: out.update([p.strip() for p in s.split(",") if p.strip()])
    latin = extract_binomial(s)
    if latin: out.add(latin)
    out.update([re.sub(r"\s+"," ",p.strip()) for p in (raw or "").split("_") if p.strip()])
    out.update([smart_capitalize(x) for x in list(out)])
    lst = list(out)
    lst.sort(key=lambda x: (0 if extract_binomial(x) else 1, len(x)))
    return lst

def wiki_rest_summary(lang: str, title: str) -> Optional[Dict[str, Any]]:
    try:
        base = f"https://{lang}.wikipedia.org/api/rest_v1"
        url = f"{base}/page/summary/{requests.utils.quote(title)}?redirect=true"
        r = requests.get(url, headers=HEADERS, timeout=20)
        if r.status_code != 200: return None
        j = r.json()
        return {
            "display_title": j.get("displaytitle") or j.get("title") or title,
            "description": j.get("description"),
            "extract": j.get("extract"),
        }
    except Exception:
        return None

def wiki_search_title(lang: str, q: str) -> Optional[str]:
    try:
        api = f"https://{lang}.wikipedia.org/w/api.php"
        r = requests.get(api, params={
            "action":"query","list":"search","format":"json",
            "srlimit":"1","srprop":"snippet","srsearch": q
        }, headers=HEADERS, timeout=20)
        if r.status_code != 200: return None
        j = r.json()
        res = ((j.get("query") or {}).get("search") or [])
        if not res: return None
        return (res[0] or {}).get("title")
    except Exception:
        return None

def fetch_description(raw_label: str) -> Dict[str, Optional[str]]:
    langs = ["es","en"]
    candidates = candidate_queries(raw_label)
    out = {"es": None, "en": None}
    for lang in langs:
        for q in candidates:
            s = wiki_rest_summary(lang, q)
            if s:
                text = s.get("extract") or s.get("description") or ""
                text = text.strip()
                if text:
                    out[lang] = text
                    break
        if out[lang]: continue
        for q in candidates:
            title = wiki_search_title(lang, q)
            if title:
                s = wiki_rest_summary(lang, title)
                if s:
                    text = (s.get("extract") or s.get("description") or "").strip()
                    if text:
                        out[lang] = text
                        break
    return out

def gbif_species_key(scientific_name: str) -> Optional[int]:
    cleaned = re.sub(r"<[^>]+>", "", scientific_name or "")
    cleaned = re.sub(r"_", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    m = re.search(r"([A-Z][a-zA-Z\-]+)\s+([a-z\-]+)", cleaned)
    binomial = f"{m.group(1)} {m.group(2)}" if m else cleaned
    r = requests.get("https://api.gbif.org/v1/species/match",
                     params={"name": binomial}, headers=HEADERS, timeout=20)
    if r.status_code == 200:
        j = r.json()
        key = j.get("usageKey")
        if isinstance(key, int): return key
    r = requests.get("https://api.gbif.org/v1/species/search",
                     params={"q": binomial, "limit":"1"}, headers=HEADERS, timeout=20)
    if r.status_code != 200: return None
    j = r.json()
    results = j.get("results") or []
    if not results: return None
    maybe = results[0].get("key")
    return int(maybe) if isinstance(maybe, int) else None

def gbif_occurrences_geojson(taxon_key: int, max_occ: int = 1000) -> Dict[str, Any]:
    features = []
    limit = 300
    offset = 0
    while offset < max_occ:
        r = requests.get("https://api.gbif.org/v1/occurrence/search",
                         params={
                             "taxonKey": str(taxon_key),
                             "hasCoordinate": "true",
                             "limit": str(min(limit, max_occ - offset)),
                             "offset": str(offset)
                         },
                         headers=HEADERS, timeout=30)
        if r.status_code != 200: break
        j = r.json()
        results = j.get("results") or []
        if not results: break
        for rec in results:
            lat = rec.get("decimalLatitude"); lon = rec.get("decimalLongitude")
            if lat is None or lon is None: continue
            features.append({
                "type":"Feature",
                "geometry":{"type":"Point","coordinates":[lon, lat]},
                "properties":{
                    "key": rec.get("key"),
                    "country": rec.get("country"),
                    "eventDate": rec.get("eventDate") or rec.get("year"),
                    "basisOfRecord": rec.get("basisOfRecord")
                }
            })
        offset += limit
        if len(results) < limit: break

    fc = {"type":"FeatureCollection","features":features}
    if features:
        lons = [f["geometry"]["coordinates"][0] for f in features]
        lats = [f["geometry"]["coordinates"][1] for f in features]
        fc["bbox"] = [min(lons), min(lats), max(lons), max(lats)]
    return fc

def run(db_path: str, out_db: str, base_dir: str, max_occ: int, delay: float, overwrite: bool, only: Optional[str]):
    db_path = pathlib.Path(db_path)
    out_db = pathlib.Path(out_db)
    db = json.loads(db_path.read_text(encoding="utf-8"))
    species = db.get("species") or []

    total = len(species)
    for idx, sp in enumerate(species, start=1):
        sci = (sp.get("scientific_name") or "").strip()
        if only and only.lower() != sci.lower():
            continue

        sid = sp.get("species_id") or slugify(sci)
        print(f"[{idx}/{total}] {sci or sid}")
        folder = pathlib.Path(base_dir) / sid
        ensure_folder(folder)

        # ---- DESCRIPCIÓN ----
        desc_map = sp.get("description") or {}
        es_curr = (desc_map.get("es") or "").strip()
        en_curr = (desc_map.get("en") or "").strip()

        need_desc_es = overwrite or not es_curr
        need_desc_en = overwrite or not en_curr

        if need_desc_es or need_desc_en:
            got = fetch_description(sci)
            wrote = False
            if need_desc_es and (got.get("es") or "").strip():
                sp.setdefault("description", {})["es"] = got["es"].strip()
                wrote = True
            if need_desc_en and (got.get("en") or "").strip():
                sp.setdefault("description", {})["en"] = got["en"].strip()
                wrote = True
            if wrote:
                # write-through: guardamos el JSON completo tras esta especie
                write_json(out_db, db)
                le = len(sp["description"].get("es","") or "")
                ln = len(sp["description"].get("en","") or "")
                print(f"  description: es={le} chars, en={ln} chars")
            else:
                print("  description: not found")
            time.sleep(delay)
        else:
            print("  description: skip (already present)")

        # ---- DISTRIBUCIÓN ----
        geo_path = folder / "range.geo.json"
        need_geo = overwrite or not geo_path.exists()
        if need_geo:
            key = gbif_species_key(sci)
            if key:
                fc = gbif_occurrences_geojson(key, max_occ=max_occ)
                if fc.get("features"):
                    ensure_folder(geo_path.parent)
                    write_json(geo_path, fc)
                    sp.setdefault("assets", {})["distribution_geojson"] = f"assets/aves/{sid}/range.geo.json"
                    write_json(out_db, db)  # write-through
                    print(f"  distribution: {len(fc['features'])} pts")
                else:
                    print("  distribution: 0 pts")
            else:
                print("  distribution: no taxonKey")
            time.sleep(delay)
        else:
            print("  distribution: skip (exists)")

    print(f"[done] JSON actualizado -> {out_db}")

def main():
    ap = argparse.ArgumentParser(description="Descripción (Wikipedia) + Distribución (GBIF) con write-through")
    ap.add_argument("--db", required=True)
    ap.add_argument("--out-db", required=True)
    ap.add_argument("--base-dir", required=True)
    ap.add_argument("--max-occ", type=int, default=1200)
    ap.add_argument("--delay", type=float, default=0.8)
    ap.add_argument("--overwrite", action="store_true")
    ap.add_argument("--only", type=str, default=None, help="Procesar solo una especie por su nombre científico exacto")
    args = ap.parse_args()
    run(args.db, args.out_db, args.base_dir, args.max_occ, args.delay, args.overwrite, args.only)

if __name__ == "__main__":
    main()
