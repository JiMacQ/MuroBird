import 'dart:convert';
import 'package:http/http.dart' as http;

const _headers = {
  'User-Agent':
      'MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)',
};

class SpeciesGalleryService {
  /// Devuelve URLs de imágenes (jpg/png) para la [scientificName].
  /// Une resultados de Wikimedia Commons y GBIF (si hay taxonKey).
  static Future<List<String>> fetch({
    required String scientificName,
    int? gbifTaxonKey,
    int limit = 12,
    bool debug = false,
  }) async {
    final urls = <String>{};

    // 1) Wikimedia Commons (busca el binomio)
    try {
      final q = scientificName.trim();
      final uri = Uri.parse('https://commons.wikimedia.org/w/api.php').replace(
        queryParameters: {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': '$q filetype:bitmap', // jpg/png principalmente
          'gsrlimit': '30',
          'prop': 'imageinfo',
          'iiprop': 'url',
          'iiurlwidth': '1024',
          'format': 'json',
          'origin': '*',
        },
      );
      if (debug) print('[GALLERY] Commons GET $uri');
      final r = await http.get(uri, headers: _headers);
      if (r.statusCode == 200) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        final pages = (j['query']?['pages'] ?? {}) as Map<String, dynamic>;
        for (final p in pages.values) {
          final ii = (p['imageinfo'] ?? []) as List;
          if (ii.isEmpty) continue;
          final url = (ii.first['thumburl'] ?? ii.first['url']) as String?;
          if (_isImage(url)) urls.add(url!);
        }
      }
    } catch (_) {}

    // 2) GBIF occurrence media (si tenemos key)
    if (gbifTaxonKey != null) {
      try {
        final uri = Uri.parse('https://api.gbif.org/v1/occurrence/search')
            .replace(
              queryParameters: {
                'taxonKey': '$gbifTaxonKey',
                'mediaType': 'StillImage',
                'hasCoordinate': 'true',
                'limit': '200',
              },
            );
        if (debug) print('[GALLERY] GBIF GET $uri');
        final r = await http.get(uri, headers: _headers);
        if (r.statusCode == 200) {
          final j = json.decode(r.body) as Map<String, dynamic>;
          final results = (j['results'] ?? []) as List;
          for (final m in results) {
            final media = (m['media'] ?? []) as List;
            for (final mm in media) {
              final id = (mm['identifier'] ?? mm['references']) as String?;
              if (_isImage(id)) urls.add(id!);
            }
          }
        }
      } catch (_) {}
    }

    // normaliza, corta y devuelve
    final out = urls.where(_isGood).take(limit).toList();
    if (debug) print('[GALLERY] total=${out.length}');
    return out;
  }

  static bool _isImage(String? u) {
    if (u == null) return false;
    final url = u.toLowerCase();
    if (!(url.startsWith('http://') || url.startsWith('https://')))
      return false;
    if (url.endsWith('.svg') || url.contains('format=svg')) return false;
    return url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.contains('.jpg?') ||
        url.contains('.jpeg?') ||
        url.contains('.png?');
  }

  static bool _isGood(String u) =>
      !u.toLowerCase().contains('placeholder') &&
      !u.toLowerCase().contains('logo') &&
      !u.toLowerCase().contains('icon');
}
