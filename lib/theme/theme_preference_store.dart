import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemePreferenceStore {
  const ThemePreferenceStore();

  static const String _key = 'themeMode';
  static const String _colorThemeKey = 'colorTheme';

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

  Future<SmaranaColorTheme> loadColorTheme() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return SmaranaColorTheme.values.firstWhere(
        (colorTheme) =>
            colorTheme.name == preferences.getString(_colorThemeKey),
        orElse: () => SmaranaColorTheme.blue,
      );
    } on Exception {
      return SmaranaColorTheme.blue;
    }
  }

  Future<void> saveColorTheme(SmaranaColorTheme colorTheme) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_colorThemeKey, colorTheme.name);
    if (!saved) {
      throw StateError('Unable to save the color theme preference.');
    }
  }
}
