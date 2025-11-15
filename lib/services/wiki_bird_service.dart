import 'dart:convert';
import 'package:http/http.dart' as http;

/// Datos listos para la UI
class BirdDetails {
  final String displayTitle; // "Mochuelo de madriguera"
  final String? scientificName; // "Athene cunicularia"
  final String? description; // "Especie de búho..."
  final String? summary; // resumen extendido
  final String? mainImage; // imagen grande
  final List<String> gallery; // urls de imágenes

  BirdDetails({
    required this.displayTitle,
    this.scientificName,
    this.description,
    this.summary,
    this.mainImage,
    required this.gallery,
  });
}

class WikiBirdService {
  /// Punto de entrada. Pasa el label tal cual viene del modelo.
  static Future<BirdDetails?> fetch(String rawLabel) async {
    // Genera candidatos: limpio, partes por "_", binomio latino, etc.
    final candidates = _candidateQueries(rawLabel);
    // prueba en español y luego en inglés
    for (final lang in const ['es', 'en']) {
      // 1) prueba candidatos directos con /page/summary
      for (final q in candidates) {
        final s = await _summaryByTitle(lang, q);
        if (s != null) return s;
      }
      // 2) última bala: buscar el título correcto y luego pedir summary
      for (final q in candidates) {
        final foundTitle = await _searchTitle(lang, q);
        if (foundTitle != null) {
          final s = await _summaryByTitle(lang, foundTitle);
          if (s != null) return s;
        }
      }
    }
    return null;
  }

  /// Devuelve varios textos candidatos a consultar en Wikipedia.
  static List<String> _candidateQueries(String raw) {
    final out = <String>{};

    String s = raw.trim();
    // Underscores -> espacios
    s = s.replaceAll('_', ' ');
    // quita duplicados tipo "Athene cunicularia - Mochuelo de..."
    s = s.replaceAll(RegExp(r'\s*[-–—]\s*'), ' ');
    // quita paréntesis finales
    s = s.replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '').trim();

    // 1) full limpio
    if (s.isNotEmpty) out.add(s);

    // 2) si tiene coma, toma ambas variantes
    if (s.contains(',')) {
      final parts = s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      out.addAll(parts);
    }

    // 3) si tiene dos bloques (latín + nombre común) separados por espacios múltiples
    // ya los cubrimos, pero además intenta extraer binomio latino:
    final latin = _extractBinomial(s);
    if (latin != null) out.add(latin);

    // 4) si tenía guion bajo originalmente, prueba cada lado por separado
    final rawParts = raw
        .split('_')
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim());
    out.addAll(rawParts.where((e) => e.isNotEmpty));

    // 5) capitaliza mínimamente (por si llegó todo minúsculas)
    out.addAll(out.map(_smartCapitalize).toList());

    // ordena por preferencia: (latin primero, luego demás)
    final list = out.toList();
    list.sort((a, b) {
      final aLatin = _extractBinomial(a) != null;
      final bLatin = _extractBinomial(b) != null;
      if (aLatin && !bLatin) return -1;
      if (!aLatin && bLatin) return 1;
      return a.length.compareTo(b.length); // más corto primero
    });
    return list;
  }

  static String? _extractBinomial(String text) {
    final m = RegExp(
      r'\b([A-Z][a-z]+ [a-z]+)\b',
    ).firstMatch(_smartCapitalize(text));
    return m?.group(1);
  }

  static String _smartCapitalize(String s) {
    if (s.isEmpty) return s;
    // Capitaliza la primera palabra si parece nombre propio/científico
    final parts = s.split(' ');
    if (parts.isEmpty) return s;
    parts[0] = parts[0].isEmpty
        ? parts[0]
        : (parts[0][0].toUpperCase() + parts[0].substring(1));
    return parts.join(' ');
  }

  /// Llama a REST summary. Devuelve null si 404.
  static Future<BirdDetails?> _summaryByTitle(String lang, String title) async {
    final base = 'https://$lang.wikipedia.org/api/rest_v1';
    final url = Uri.parse(
      '$base/page/summary/${Uri.encodeComponent(title)}?redirect=true',
    );
    final r = await http.get(url);
    if (r.statusCode != 200) return null;

    final j = json.decode(r.body) as Map<String, dynamic>;
    final displayTitle = (j['displaytitle'] ?? j['title'] ?? title).toString();
    final desc = j['description'] as String?;
    final extract = j['extract'] as String?;
    String? originalImage;
    if (j['originalimage'] is Map) {
      originalImage = (j['originalimage']['source'] as String?);
    } else if (j['thumbnail'] is Map) {
      originalImage = (j['thumbnail']['source'] as String?);
    }

    // intenta deducir nombre científico
    String? sci;
    if (desc != null && RegExp(r'^[A-Z][a-z]+ [a-z]+').hasMatch(desc)) {
      sci = RegExp(r'([A-Z][a-z]+ [a-z]+)').firstMatch(desc)?.group(1);
    }
    sci ??= _extractBinomial(extract ?? '');
    sci ??= _extractBinomial(displayTitle);

    final gallery = await _mediaGallery(lang, displayTitle, originalImage);
    return BirdDetails(
      displayTitle: displayTitle,
      scientificName: sci,
      description: desc,
      summary: extract,
      mainImage: gallery.isNotEmpty ? gallery.first : originalImage,
      gallery: gallery,
    );
  }

  /// Busca el título más probable con la API clásica de MediaWiki.
  static Future<String?> _searchTitle(String lang, String query) async {
    final api = Uri.parse(
      'https://$lang.wikipedia.org/w/api.php?action=query&list=search&format=json'
      '&srlimit=1&srprop=snippet&srsearch=${Uri.encodeQueryComponent(query)}',
    );
    final r = await http.get(api);
    if (r.statusCode != 200) return null;
    final j = json.decode(r.body) as Map<String, dynamic>;
    final list = (((j['query'] ?? {}) as Map)['search'] ?? []) as List;
    if (list.isEmpty) return null;
    final title = (list.first as Map)['title'] as String?;
    return title;
  }

  /// Obtiene galería (hasta 8 imágenes) usando media-list.
  static Future<List<String>> _mediaGallery(
    String lang,
    String title,
    String? originalImage,
  ) async {
    final base = 'https://$lang.wikipedia.org/api/rest_v1';
    final url = Uri.parse(
      '$base/page/media-list/${Uri.encodeComponent(title)}',
    );
    final out = <String>[];
    try {
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        final items = (j['items'] ?? []) as List;
        for (final it in items) {
          if (it is Map && it['type'] == 'image' && it['srcset'] is List) {
            final srcset = it['srcset'] as List;
            if (srcset.isNotEmpty) out.add(srcset.last['src'] as String);
            if (out.length >= 8) break;
          }
        }
      }
    } catch (_) {}
    // Asegura incluir la principal si venía
    if (originalImage != null && !out.contains(originalImage)) {
      out.insert(0, originalImage);
    }
    return out;
  }
}
