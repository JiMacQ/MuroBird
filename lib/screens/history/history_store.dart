import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum HistorySource { realtime, uploaded }

class HistoryEntry {
  final String id;
  final String speciesId; // ej: "buteo_nitidus"
  final String bird; // nombre común tal como vino del modelo
  final String sci; // nombre científico
  final double confidence; // 0..1
  final HistorySource source;
  final DateTime dateTime;
  final String? audioPath;
  final String? thumb;

  HistoryEntry({
    required this.id,
    required this.speciesId,
    required this.bird,
    required this.sci,
    required this.confidence,
    required this.source,
    required this.dateTime,
    this.audioPath,
    this.thumb,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> m) => HistoryEntry(
    id: (m['id'] ?? '').toString(),
    speciesId: (m['speciesId'] ?? m['species_id'] ?? '').toString(),
    bird: (m['bird'] ?? m['common_name'] ?? '').toString(),
    sci: (m['sci'] ?? m['scientific_name'] ?? '').toString(),
    confidence: (m['confidence'] is num)
        ? (m['confidence'] as num).toDouble()
        : double.tryParse(m['confidence']?.toString() ?? '0') ?? 0,
    source: (m['source']?.toString() == 'uploaded')
        ? HistorySource.uploaded
        : HistorySource.realtime,
    dateTime:
        DateTime.tryParse(m['dateTime']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(
          (m['ts'] ?? 0) is int ? (m['ts'] as int) : 0,
          isUtc: true,
        ),
    audioPath: m['audioPath']?.toString(),
    thumb: m['thumb']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'speciesId': speciesId,
    'bird': bird,
    'sci': sci,
    'confidence': confidence,
    'source': source.name,
    'dateTime': dateTime.toIso8601String(),
    if (audioPath != null) 'audioPath': audioPath,
    if (thumb != null) 'thumb': thumb,
  };
}

/// Item agregado para la Colección (vista compacta)
class CollectionItem {
  final String speciesId;
  final String commonName;
  final String scientificName;
  final int views;
  final double? bestConfidence; // en %
  final DateTime? lastSeen; // para formatear en UI

  CollectionItem({
    required this.speciesId,
    required this.commonName,
    required this.scientificName,
    required this.views,
    required this.bestConfidence,
    required this.lastSeen,
  });
}

class HistoryStore {
  static const _fileName = 'history.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$_fileName');
    if (!await f.exists()) {
      await f.create(recursive: true);
      await f.writeAsString('{"entries": []}');
    }
    return f;
  }

  static Future<List<HistoryEntry>> all() async {
    try {
      final f = await _file();
      final raw = await f.readAsString();
      final jsonData = json.decode(raw);
      final List list = (jsonData is Map && jsonData['entries'] is List)
          ? jsonData['entries']
          : <dynamic>[];
      return list
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[HistoryStore] read error: $e');
      return [];
    }
  }

  static Future<void> add(HistoryEntry entry) async {
    final list = await all();
    list.add(entry);
    await _save(list);

    // Logea la ruta del archivo para que lo ubiques en consola/Logcat
    final f = await _file();
    // ignore: avoid_print
    print('[HistoryStore] guardado: ${f.path} (${list.length} registros)');
  }

  static Future<void> _save(List<HistoryEntry> items) async {
    final f = await _file();
    final data = {
      'entries': items.map((e) => e.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Construye la **Colección** agregada por speciesId
  static Future<List<CollectionItem>> buildCollection() async {
    final entries = await all();
    final byId = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      byId.putIfAbsent(e.speciesId, () => []).add(e);
    }

    final result = <CollectionItem>[];
    byId.forEach((id, list) {
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final views = list.length;
      final best = list
          .map((e) => e.confidence)
          .fold<double>(0, (p, c) => c > p ? c : p);
      final last = list.isNotEmpty ? list.last.dateTime : null;

      // Toma el nombre más “largo” o el más reciente para mostrar
      final latest = list.last;
      result.add(
        CollectionItem(
          speciesId: id,
          commonName: latest.bird,
          scientificName: latest.sci,
          views: views,
          bestConfidence: best * 100,
          lastSeen: last,
        ),
      );
    });

    // Ordena por última vez visto desc
    result.sort(
      (a, b) =>
          (b.lastSeen ?? DateTime(0)).compareTo(a.lastSeen ?? DateTime(0)),
    );
    return result;
  }
}
