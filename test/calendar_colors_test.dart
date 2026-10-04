import 'package:app_smarana/features/calender/theme/calendar_colors.dart';
import 'package:app_smarana/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar events use every selectable app theme color', () {
    expect(CalendarColors.events, hasLength(SmaranaColorTheme.values.length));
    expect(
      CalendarColors.events.map((event) => event.baseColor),
      orderedEquals(SmaranaColorTheme.values.map((theme) => theme.color)),
    );
  });

  test('reminder colors are stable and readable in both theme modes', () {
    for (var index = 0; index < 100; index++) {
      final reminderId = 'reminder-$index';
      expect(
        CalendarColors.forReminder(reminderId),
        same(CalendarColors.forReminder(reminderId)),
      );
    }
    final assignedColors = {
      for (var index = 0; index < 100; index++)
        CalendarColors.forReminder('reminder-$index').baseColor,
    };
    expect(
      assignedColors,
      containsAll(CalendarColors.events.map((event) => event.baseColor)),
    );

    for (final color in CalendarColors.events) {
      expect(
        _contrastRatio(color.foreground(false), Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(color.foreground(true), const Color(0xFF0B0F14)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
