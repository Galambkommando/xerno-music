import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../format.dart';
import '../models/settings.dart';

class SettingsStore {
  static const _key = 'xerno.settings';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      final fresh = AppSettings.defaults();
      await save(fresh);
      return fresh;
    }
    try {
      var settings = AppSettings.fromJson(jsonDecode(raw));
      if (settings.deviceId.isEmpty) {
        settings = settings.copyWith(deviceId: newDeviceId());
        await save(settings);
      }
      return settings;
    } catch (_) {
      final fresh = AppSettings.defaults();
      await save(fresh);
      return fresh;
    }
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
