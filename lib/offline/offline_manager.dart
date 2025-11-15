import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'offline_prefs.dart';

class OfflineManager {
  static Map<String, dynamic>? _db; // caché del JSON

  /// Carpeta raíz donde se instala el paquete offline.
  static Future<String> _offlineRoot() async {
    final dir = await getApplicationSupportDirectory();
    final base = '${dir.path}/murobird_offline';
    await Directory(base).create(recursive: true);
    return base;
  }

  /// ¿El modo offline está instalado y con ruta válida?
  static Future<bool> isReady() async {
    final ready = await OfflinePrefs.ready;
    final base = await OfflinePrefs.baseDir;
    return ready && base != null && Directory(base).existsSync();
  }

  /// Descarga + descomprime con reporte de progreso [0..1].
  static Future<void> downloadAndInstallWithProgress(
    void Function(double) onProgress,
  ) async {
    final base = await _offlineRoot();
    final zipPath = '$base/aves.zip';
    final url = Uri.parse(
      'https://github.com/Darling-P11/murobird/releases/download/v1.0.0/aves.zip',
    );

    await Directory(base).create(recursive: true);

    final client = http.Client();
    try {
      final req = http.Request('GET', url);
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw Exception(
          'HTTP ${res.statusCode}: no se pudo descargar el paquete.',
        );
      }

      final total = res.contentLength; // puede ser null
      int received = 0;
      final sink = File(zipPath).openWrite(mode: FileMode.write);

      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);

        if (total != null && total > 0) {
          onProgress(
            (received / total).clamp(0.0, 0.99),
          ); // 0..0.99 en descarga
        } else {
          onProgress(0.0); // indeterminada
        }
      }
      await sink.flush();
      await sink.close();

      final zipFile = File(zipPath);
      if (!await zipFile.exists() || (await zipFile.length()) == 0) {
        throw Exception('El archivo descargado está vacío.');
      }

      // Descomprimir (90% -> 100%)
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);

      int done = 0;
      final totalEntries = archive.isEmpty ? 1 : archive.length;
      for (final f in archive) {
        final outPath = '$base/${f.name}';
        if (f.isFile) {
          final outFile = File(outPath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(f.content as List<int>, flush: true);
        } else {
          await Directory(outPath).create(recursive: true);
        }
        done++;
        onProgress(0.9 + 0.1 * (done / totalEntries));
      }

      await OfflinePrefs.setBaseDir(base);
      await OfflinePrefs.setReady(true);
      _db = null;

      // Limpia el ZIP
      try {
        await zipFile.delete();
      } catch (_) {}

      onProgress(1.0);
    } on HandshakeException catch (e) {
      throw Exception(
        'Fallo TLS/Handshake: ${e.osError?.message ?? e.toString()}',
      );
    } on SocketException catch (e) {
      throw Exception('Error de red: ${e.osError?.message ?? e.message}');
    } catch (e) {
      throw Exception('Descarga/instalación falló: $e');
    } finally {
      client.close();
    }
  }

  /// Versión simple (por compatibilidad): descarga y no reporta progreso.
  static Future<void> downloadAndInstall() async {
    await downloadAndInstallWithProgress((_) {});
  }

  /// Verifica estado de instalación y devuelve un resumen.
  static Future<Map<String, dynamic>> verifyInstall() async {
    final base = await OfflinePrefs.baseDir;
    final ready = await OfflinePrefs.ready;
    final result = <String, dynamic>{
      'enabled': await OfflinePrefs.enabled,
      'ready_flag': ready,
      'base_dir': base,
      'db_exists': false,
      'assets_ok': false,
      'count_species': 0,
    };
    if (base == null) return result;

    try {
      final db = await _loadDb();
      final list = (db['species'] as List? ?? const []);
      result['db_exists'] = true;
      result['count_species'] = list.length;

      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map);
        final a = Map<String, dynamic>.from(m['assets'] ?? {});
        final coverRel = a['image_cover'] as String?;
        if (coverRel == null || coverRel.isEmpty) continue;

        // species-aware (evita tomar el cover.jpg de otra especie)
        String _slug(String s) => s
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp('_+'), '_')
            .replaceAll(RegExp('^_|_\$'), '');
        final sci = (m['scientific_name'] as String?) ?? '';
        final speciesId = (m['species_id'] as String?) ?? _slug(sci);

        final coverAbs = await _resolveRelForSpecies(base, coverRel, speciesId);
        if (File(coverAbs).existsSync()) {
          result['assets_ok'] = true;
          break;
        }
      }
    } catch (_) {}
    return result;
  }

  /// Elimina la instalación offline (carpeta + flags).
  static Future<void> uninstall() async {
    final base = await OfflinePrefs.baseDir;
    if (base != null && Directory(base).existsSync()) {
      await Directory(base).delete(recursive: true);
    }
    await OfflinePrefs.setReady(false);
    await OfflinePrefs.setBaseDir('');
    _db = null;
  }

  // ====================== Acceso al DB offline ======================

  static Future<Map<String, dynamic>> _loadDb() async {
    if (_db != null) return _db!;
    final base = await OfflinePrefs.baseDir;
    if (base == null) throw Exception('Offline no inicializado.');
    // intenta raíz y carpeta aves/
    for (final p in ['$base/offline_db.json', '$base/aves/offline_db.json']) {
      if (File(p).existsSync()) {
        _db = jsonDecode(await File(p).readAsString()) as Map<String, dynamic>;
        return _db!;
      }
    }
    // búsqueda recursiva de respaldo
    await for (final e in Directory(
      base,
    ).list(recursive: true, followLinks: false)) {
      if (e is File && e.path.toLowerCase().endsWith('/offline_db.json')) {
        _db =
            jsonDecode(await File(e.path).readAsString())
                as Map<String, dynamic>;
        return _db!;
      }
    }
    throw Exception('No se encontró offline_db.json dentro de $base');
  }

  /// Busca por nombre científico exacto (case-insensitive).
  static Future<Map<String, dynamic>?> findByScientificName(String name) async {
    final db = await _loadDb();
    final list = (db['species'] as List? ?? const []).cast<Map>();

    // 1) Normaliza y extrae "Genus species" aunque vengan extras
    String n = name
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final bin = RegExp(r'\b([A-Z][a-zA-Z-]+)\s+([a-z-]+)\b').firstMatch(n);
    if (bin != null) n = '${bin.group(1)!} ${bin.group(2)!}';
    final q = n.toLowerCase();
    final qId = q.replaceAll(' ', '_');

    // 2) Exacto por científico
    for (final m in list) {
      final sci = (m['scientific_name'] as String?)?.toLowerCase();
      if (sci == q) return Map<String, dynamic>.from(m);
    }

    // 3) Exacto por species_id
    for (final m in list) {
      final id = (m['species_id'] as String?)?.toLowerCase();
      if (id == qId) return Map<String, dynamic>.from(m);
    }

    // 4) Fuzzy: contiene el binomio en scientific_name (por si hay terceros términos)
    for (final m in list) {
      final sci = (m['scientific_name'] as String?)?.toLowerCase() ?? '';
      if (sci.contains(q)) return Map<String, dynamic>.from(m);
    }

    // 5) Fuzzy: empieza por genus y contiene la especie (tolerante a espacios)
    final parts = q.split(' ');
    if (parts.length == 2) {
      final genus = parts.first;
      final species = parts.last;
      for (final m in list) {
        final sci = (m['scientific_name'] as String?)?.toLowerCase() ?? '';
        if (sci.startsWith(genus) && sci.contains(species)) {
          return Map<String, dynamic>.from(m);
        }
      }
    }

    return null;
  }

  // Busca 'rel' priorizando la carpeta de la especie.
  // 1) base/aves/<id>/<rel>
  // 2) base/<id>/<rel>
  // 3) búsqueda por nombre de archivo PERO solo dentro de rutas que contengan /<id>/
  static Future<String> _resolveRelForSpecies(
    String base,
    String rel,
    String speciesId,
  ) async {
    rel = rel.replaceFirst(RegExp(r'^\./'), '').replaceAll('\\', '/');

    // 1) base/aves/<id>/<rel>
    final inAves = '$base/aves/$speciesId/$rel';
    if (File(inAves).existsSync()) return inAves;

    // 2) base/<id>/<rel>
    final inRoot = '$base/$speciesId/$rel';
    if (File(inRoot).existsSync()) return inRoot;

    // 3) Si el JSON ya trae subcarpeta, intenta directo
    final direct = '$base/$rel';
    if (File(direct).existsSync()) return direct;

    // 4) Búsqueda por nombre de archivo, pero restringida a la especie
    final tail = rel.split('/').last.toLowerCase();
    try {
      await for (final e in Directory(
        base,
      ).list(recursive: true, followLinks: false)) {
        if (e is File) {
          final p = e.path.replaceAll('\\', '/').toLowerCase();
          if (p.endsWith('/$tail') && p.contains('/$speciesId/')) {
            return e.path;
          }
        }
      }
    } catch (_) {}

    // Último recurso (útil para logs)
    return inAves;
  }

  /// Convierte rutas relativas del JSON a rutas absolutas dentro del directorio offline.
  static Future<Map<String, dynamic>> adaptAssets(
    Map<String, dynamic> m,
  ) async {
    final base = await OfflinePrefs.baseDir ?? '';

    // Toma species_id si existe; si no, deriva de scientific_name
    String _slug(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp('^_|_\$'), '');
    final speciesId =
        (m['species_id'] as String?) ??
        _slug((m['scientific_name'] as String?) ?? '');

    // Intenta primero en la carpeta de la especie (p. ej. aves/<id>/cover.jpg)
    Future<String> abs(String? rel) async {
      if (rel == null || rel.isEmpty) return '';
      if (rel.startsWith('http') || rel.startsWith('/')) return rel;
      return await _resolveRelForSpecies(base, rel, speciesId);
    }

    final a = Map<String, dynamic>.from(m['assets'] ?? {});
    return {
      ...m,
      'assets': {
        'image_cover': await abs(a['image_cover'] as String?),
        'gallery': [
          for (final e in (a['gallery'] as List? ?? const []))
            await abs(e as String?),
        ],
        'audio_samples': [
          for (final e in (a['audio_samples'] as List? ?? const []))
            await abs(e as String?),
        ],
        'spectrograms': [
          for (final e in (a['spectrograms'] as List? ?? const []))
            await abs(e as String?),
        ],
        'distribution_geojson': await abs(a['distribution_geojson'] as String?),
      },
    };
  }
}
