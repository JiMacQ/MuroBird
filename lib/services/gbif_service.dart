import 'dart:convert';
import 'package:http/http.dart' as http;

const _headers = {
  'User-Agent':
      'MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)',
};

class GbifService {
  static Future<int?> fetchSpeciesKey(String scientificName) async {
    final cleaned = scientificName
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final m = RegExp(r'([A-Z][a-zA-Z\-]+)\s+([a-z\-]+)').firstMatch(cleaned);
    final binomial = (m != null) ? '${m.group(1)} ${m.group(2)}' : cleaned;

    final uri = Uri.parse(
      'https://api.gbif.org/v1/species/match',
    ).replace(queryParameters: {'name': binomial});

    final r = await http.get(uri, headers: _headers);
    if (r.statusCode == 200) {
      final j = json.decode(r.body) as Map<String, dynamic>;
      final key = j['usageKey'];
      if (key is int) return key;
    }

    // Fallback a /search si /match no da usageKey
    final sUri = Uri.parse(
      'https://api.gbif.org/v1/species/search',
    ).replace(queryParameters: {'q': binomial, 'limit': '1'});
    final sr = await http.get(sUri, headers: _headers);
    if (sr.statusCode != 200) return null;
    final sj = json.decode(sr.body) as Map<String, dynamic>;
    final results = (sj['results'] ?? []) as List;
    if (results.isEmpty) return null;
    final maybeKey = (results.first as Map<String, dynamic>)['key'];
    return (maybeKey is int) ? maybeKey : null;
  }

  /// Ocurrencias con coordenadas para overlay de puntos.
  static Future<List<Map<String, dynamic>>> fetchOccurrences(
    int taxonKey, {
    int limit = 200,
  }) async {
    final uri = Uri.parse('https://api.gbif.org/v1/occurrence/search').replace(
      queryParameters: {
        'taxonKey': '$taxonKey',
        'hasCoordinate': 'true',
        'limit': '$limit',
      },
    );
    final r = await http.get(uri, headers: _headers);
    if (r.statusCode != 200) return const [];
    final j = json.decode(r.body) as Map<String, dynamic>;
    final results = (j['results'] ?? []) as List;
    return results.cast<Map<String, dynamic>>();
  }
}
