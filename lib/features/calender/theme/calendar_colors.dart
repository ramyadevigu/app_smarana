import 'package:flutter/material.dart';

class CalendarEventColor {
  const CalendarEventColor(this.baseColor);

  final Color baseColor;

  Color foreground(bool isDark) {
    return HSLColor.fromColor(baseColor)
        .withLightness(isDark ? 0.78 : 0.25)
        .toColor();
  }

  Color surface(bool isDark) =>
      baseColor.withValues(alpha: isDark ? 0.22 : 0.14);
}

abstract final class CalendarColors {
  static CalendarEventColor forReminder(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return CalendarEventColor(HSLColor.fromAHSL(1, hue, 0.72, 0.48).toColor());
  }
}
