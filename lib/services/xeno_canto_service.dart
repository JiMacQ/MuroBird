import 'dart:convert';
import 'package:http/http.dart' as http;

const _headers = {
  'User-Agent':
      'MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)',
};

class XCRecording {
  final String id;
  final String title;
  final String fileUrl;
  final String? locality;
  final String? length;
  final String? quality;

  XCRecording({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.locality,
    this.length,
    this.quality,
  });
}

class XenoCantoService {
  // ======================= NUEVO: SONOGRAMAS =======================

  /// Devuelve la URL del espectrograma (sonograma) grande de la
  /// primera grabación para el [scientificName] dado.
  /// Si no encuentra, retorna null.
  static Future<String?> fetchSpectrogramUrl(
    String scientificName, {
    bool debug = false,
  }) async {
    final raw = (scientificName).trim();
    if (raw.isEmpty) return null;

    // Intentamos usar binomio válido (gen + sp); si no, query libre.
    String query = raw;
    final bin = _extractBinomial(raw);
    if (bin != null) {
      final p = bin.split(RegExp(r'\s+'));
      final gen = p[0], sp = p[1];
      query = 'gen:$gen sp:$sp';
    }

    final url = Uri.parse(
      'https://xeno-canto.org/api/2/recordings?query=${Uri.encodeQueryComponent(query)}',
    );
    if (debug) print('[XC:SONO] GET $url');

    final res = await http.get(url, headers: _headers);
    if (res.statusCode != 200) return null;

    final data = json.decode(res.body) as Map<String, dynamic>;
    final recs = (data['recordings'] as List?) ?? const [];
    if (recs.isEmpty) return null;

    final first = recs.first as Map<String, dynamic>;
    final sono = (first['sono'] as Map<String, dynamic>?) ?? const {};
    final large = (sono['large'] as String?)?.trim();
    final small = (sono['small'] as String?)?.trim();

    // Xeno-Canto suele devolver URLs como //xeno-canto.org/...
    String? fix(String? u) {
      if (u == null || u.isEmpty) return null;
      if (u.startsWith('http')) return u;
      if (u.startsWith('//')) return 'https:$u';
      return 'https://$u';
    }

    return fix(large) ?? fix(small);
  }

  /// (Opcional) Devuelve la URL del espectrograma para una grabación por ID.
  static Future<String?> fetchSpectrogramUrlById(
    String recordingId, {
    bool debug = false,
  }) async {
    final id = recordingId.trim();
    if (id.isEmpty) return null;
    final url = Uri.parse(
      'https://xeno-canto.org/api/2/recordings?query=nr:$id',
    );
    if (debug) print('[XC:SONO] GET $url');

    final res = await http.get(url, headers: _headers);
    if (res.statusCode != 200) return null;

    final data = json.decode(res.body) as Map<String, dynamic>;
    final recs = (data['recordings'] as List?) ?? const [];
    if (recs.isEmpty) return null;

    final first = recs.first as Map<String, dynamic>;
    final sono = (first['sono'] as Map<String, dynamic>?) ?? const {};
    final large = (sono['large'] as String?)?.trim();
    final small = (sono['small'] as String?)?.trim();

    String? fix(String? u) {
      if (u == null || u.isEmpty) return null;
      if (u.startsWith('http')) return u;
      if (u.startsWith('//')) return 'https:$u';
      return 'https://$u';
    }

    return fix(large) ?? fix(small);
  }

  // ======================= AUDIOS (ya existente) =======================

  static Future<List<XCRecording>> fetchBySpecies(
    String label, {
    int limit = 5,
    bool debug = false,
  }) async {
    if (debug) print('[XC] label="$label"');

    // Intentar extraer binomio; si no, intentar GBIF
    String? binomial = _extractBinomial(label);
    if (binomial == null) {
      if (debug) print('[XC] no parece binomial, resolviendo vía GBIF…');
      binomial = await _resolveToBinomialViaGbif(label, debug: debug);
    }
    final latin = (binomial ?? _stripHtml(label).replaceAll('_', ' ').trim())
        .trim();
    if (debug) print('[XC] usando binomial="$latin"');

    // ---- consultas a XC (Mantenemos el print del GET) ----
    Future<List<Map<String, dynamic>>> _queryRaw(String q) async {
      final url = Uri.parse(
        'https://xeno-canto.org/api/2/recordings?query=${Uri.encodeQueryComponent(q)}',
      );
      print('[XC] GET $url'); // <-- NO lo eliminamos
      final r = await http.get(url, headers: _headers);
      if (debug) print('[XC] status=${r.statusCode}');
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      return ((j['recordings'] ?? []) as List).cast<Map<String, dynamic>>();
    }

    Future<List<Map<String, dynamic>>> _search(String latin) async {
      final out = <Map<String, dynamic>>[];
      final p = latin.split(RegExp(r'\s+'));
      // Validar que de verdad parece "Genus species"
      if (p.length >= 2 && _isValidGenus(p[0]) && _isValidSpecies(p[1])) {
        final gen = p[0], sp = p[1];
        if (debug) print('[XC] query binomial -> gen:$gen sp:$sp');
        out.addAll(await _queryRaw('gen:$gen sp:$sp'));
        if (out.isEmpty) out.addAll(await _queryRaw('gen:$gen sp:$sp q:A,B'));
        if (out.isEmpty) out.addAll(await _queryRaw('$gen $sp'));
      } else {
        if (debug) {
          print(
            '[XC] latin="$latin" no supera validación binomial; usando texto libre.',
          );
        }
      }
      if (out.isEmpty) out.addAll(await _queryRaw(latin));
      return out;
    }

    final raw = await _search(latin);

    // map + score
    final scored = <_Scored>[];
    for (final m in raw) {
      final file = (m['file'] as String?)?.trim();
      if (file == null || file.isEmpty) continue;

      final resolved = file.startsWith('http')
          ? file
          : 'https:${file.startsWith('//') ? file : '//xeno-canto.org/$file'}';

      final title = [
        (m['gen'] ?? '').toString().trim(),
        (m['sp'] ?? '').toString().trim(),
        if ((m['ssp'] ?? '').toString().trim().isNotEmpty)
          (m['ssp'] ?? '').toString().trim(),
      ].where((s) => s.isNotEmpty).join(' ');

      final lenStr = (m['length'] as String?) ?? '';
      final lenSecs = _parseLengthSeconds(lenStr);
      final q = (m['q'] as String?)?.toUpperCase() ?? '';
      final qualityScore = (q == 'A')
          ? 2
          : (q == 'B')
          ? 1
          : 0;
      final dateStr = (m['date'] as String?) ?? '';
      final uploadedStr = (m['uploaded'] as String?) ?? '';
      final recency =
          DateTime.tryParse(uploadedStr) ??
          DateTime.tryParse(dateStr) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      scored.add(
        _Scored(
          XCRecording(
            id: (m['id'] ?? '').toString(),
            title: title.isEmpty ? latin : title,
            fileUrl: resolved,
            locality: m['loc'] as String?,
            length: lenStr,
            quality: (m['q'] as String?),
          ),
          qualityScore * 1000000 -
              lenSecs * 100 +
              recency.millisecondsSinceEpoch ~/ 1000000,
        ),
      );
    }

    // dedup y top-N
    final seen = <String>{};
    final dedup = <_Scored>[];
    for (final s in scored) {
      if (seen.add(s.item.fileUrl)) dedup.add(s);
    }
    dedup.sort((a, b) => b.score.compareTo(a.score));
    return dedup.take(limit).map((e) => e.item).toList();
  }

  // ------------------------- helpers -------------------------
  static const _articles = <String>{
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
    'del',
    'de',
    'al',
    'the',
    'a',
    'an',
    'of',
  };

  static String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

  static String _normalizeAccents(String input) {
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'ñ': 'n',
      'Ñ': 'N',
    };
    final sb = StringBuffer();
    for (final ch in input.runes) {
      final s = String.fromCharCode(ch);
      sb.write(map[s] ?? s);
    }
    return sb.toString();
  }

  static String? _extractBinomial(String text) {
    var t = _stripHtml(text).replaceAll('_', ' ').trim();
    t = _normalizeAccents(t);
    final words = t
        .split(RegExp(r'\s+'))
        .where((w) => !_articles.contains(w.toLowerCase()))
        .toList();
    if (words.length < 2) return null;
    final cand = '${words[0]} ${words[1]}';
    return (_isValidGenus(words[0]) && _isValidSpecies(words[1])) ? cand : null;
  }

  static bool _isValidGenus(String w) =>
      RegExp(r'^[A-Z][a-zA-Z\-]{2,}$').hasMatch(w) &&
      !_articles.contains(w.toLowerCase());
  static bool _isValidSpecies(String w) => RegExp(r'^[a-z\-]{2,}$').hasMatch(w);

  static Future<String?> _resolveToBinomialViaGbif(
    String text, {
    bool debug = false,
  }) async {
    final q = _stripHtml(text).replaceAll('_', ' ').trim();
    if (q.isEmpty) return null;

    // /species/match
    try {
      final mr = await http.get(
        Uri.parse(
          'https://api.gbif.org/v1/species/match',
        ).replace(queryParameters: {'name': q}),
        headers: _headers,
      );
      if (mr.statusCode == 200) {
        final mj = json.decode(mr.body) as Map<String, dynamic>;
        final scn =
            (mj['scientificName'] ?? mj['canonicalName'] ?? '') as String;
        if (_isValidGenus(scn.split(' ').first) &&
            _isValidSpecies(scn.split(' ').last)) {
          if (debug) print('[XC] GBIF/match -> $scn');
          return scn;
        }
      }
    } catch (_) {}

    // /species/search
    try {
      final sr = await http.get(
        Uri.parse(
          'https://api.gbif.org/v1/species/search',
        ).replace(queryParameters: {'q': q, 'limit': '1'}),
        headers: _headers,
      );
      if (sr.statusCode == 200) {
        final sj = json.decode(sr.body) as Map<String, dynamic>;
        final results = (sj['results'] ?? []) as List;
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final scn =
              (first['scientificName'] ?? first['canonicalName'] ?? '')
                  as String;
          if (scn.isNotEmpty) {
            if (debug) print('[XC] GBIF/search -> $scn');
            return scn;
          }
        }
      }
    } catch (_) {}
    if (debug) print('[XC] GBIF no resolvió "$q"');
    return null;
  }

  static int _parseLengthSeconds(String len) {
    if (len.isEmpty) return 9999;
    final parts = len.split(':');
    if (parts.length == 1) return int.tryParse(parts[0]) ?? 9999;
    final m = int.tryParse(parts[0]) ?? 0;
    final s = int.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
}

class _Scored {
  final XCRecording item;
  final int score;
  _Scored(this.item, this.score);
}
