import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceStore {
  const ThemePreferenceStore();

  static const String _key = 'themeMode';

  Future<ThemeMode> loadThemeMode() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return switch (preferences.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } on Exception {
      return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, themeMode.name);
    if (!saved) {
      throw StateError('Unable to save the theme preference.');
    }
  }
}
