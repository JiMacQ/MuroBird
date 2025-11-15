import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../offline/offline_prefs.dart';

class RecordingsManager {
  /// Guarda un archivo de audio [bytes] si la preferencia de guardado automático está activa.
  static Future<void> saveIfEnabled(List<int> bytes, {String? fileName}) async {
    final enabled = await OfflinePrefs.autoSaveRecordings;
    if (!enabled) return; // No hacer nada si está desactivado

    try {
      final dir = await _recordingsDir();
      final name =
          fileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      // (Opcional) podrías devolver la ruta o hacer logs
      print('✅ Grabación guardada en: ${file.path}');
    } catch (e) {
      print('⚠️ Error al guardar grabación: $e');
    }
  }

  static Future<Directory> _recordingsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/recordings');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    return folder;
  }
}
