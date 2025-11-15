// lib/offline/offline_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

class OfflinePrefs {
  static const _kEnabled = 'offline_enabled';
  static const _kReady = 'offline_ready';
  static const _kBaseDir = 'offline_base_dir';

  // ===== NUEVO: auto guardado de grabaciones =====
  static const _kAutoSave = 'auto_save_recordings';

  static Future<bool> get autoSaveRecordings async =>
      (await SharedPreferences.getInstance()).getBool(_kAutoSave) ?? false;

  static Future<void> setAutoSaveRecordings(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kAutoSave, v);

  static Future<bool> get enabled async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? false;

  static Future<void> setEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kEnabled, v);

  static Future<bool> get ready async =>
      (await SharedPreferences.getInstance()).getBool(_kReady) ?? false;

  static Future<void> setReady(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kReady, v);

  static Future<String?> get baseDir async =>
      (await SharedPreferences.getInstance()).getString(_kBaseDir);

  static Future<void> setBaseDir(String dir) async =>
      (await SharedPreferences.getInstance()).setString(_kBaseDir, dir);
}
