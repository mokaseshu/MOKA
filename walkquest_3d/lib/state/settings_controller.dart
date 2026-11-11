import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _settings = AppSettings.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  static const _key = 'wq_settings';
  final SharedPreferences _prefs;
  AppSettings _settings = const AppSettings();

  AppSettings get value => _settings;

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    _settings = change(_settings);
    notifyListeners();
    await _prefs.setString(_key, json.encode(_settings.toJson()));
  }
}
