import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class CalendarEventColor {
  const CalendarEventColor(this.baseColor);

  final Color baseColor;

  Color foreground(bool isDark) {
    return HSLColor.fromColor(baseColor)
        .withLightness(isDark ? 0.78 : 0.3)
        .toColor();
  }

  Color surface(bool isDark) =>
      baseColor.withValues(alpha: isDark ? 0.22 : 0.14);
}

abstract final class CalendarColors {
  static final List<CalendarEventColor> events =
      List<CalendarEventColor>.unmodifiable([
        for (final theme in SmaranaColorTheme.values)
          CalendarEventColor(theme.color),
      ]);

  static CalendarEventColor forReminder(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return events[hash % events.length];
  }
}
