import 'package:flutter/material.dart';

class CalendarEventColor {
  const CalendarEventColor({required this.light, required this.dark});

  final Color light;
  final Color dark;

  Color foreground(bool isDark) => isDark ? dark : light;

  Color surface(bool isDark) =>
      foreground(isDark).withValues(alpha: isDark ? 0.22 : 0.12);
}

abstract final class CalendarColors {
  static const events = <CalendarEventColor>[
    CalendarEventColor(light: Color(0xFF1769AA), dark: Color(0xFF8CC8FF)),
    CalendarEventColor(light: Color(0xFF7950A1), dark: Color(0xFFC9A5F2)),
    CalendarEventColor(light: Color(0xFF287A49), dark: Color(0xFF8AD6A4)),
    CalendarEventColor(light: Color(0xFF087E83), dark: Color(0xFF72D4D1)),
    CalendarEventColor(light: Color(0xFFB65C16), dark: Color(0xFFFFB879)),
    CalendarEventColor(light: Color(0xFFB33A45), dark: Color(0xFFFF9BA4)),
    CalendarEventColor(light: Color(0xFFAD4679), dark: Color(0xFFF2A3C9)),
    CalendarEventColor(light: Color(0xFF927000), dark: Color(0xFFE9CD70)),
    CalendarEventColor(light: Color(0xFF4059A8), dark: Color(0xFFAAB9FF)),
    CalendarEventColor(light: Color(0xFF59636E), dark: Color(0xFFBBC5CF)),
  ];

  static CalendarEventColor forReminder(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return events[hash % events.length];
  }
}
