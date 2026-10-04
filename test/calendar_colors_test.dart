import 'package:app_smarana/features/calender/theme/calendar_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder colors are deterministic and span a broad hue range', () {
    final colors = <Color>{};
    for (var index = 0; index < 1000; index++) {
      final reminderId = 'reminder-$index';
      expect(
        CalendarColors.forReminder(reminderId).baseColor,
        CalendarColors.forReminder(reminderId).baseColor,
      );
      colors.add(CalendarColors.forReminder(reminderId).baseColor);
    }
    expect(colors.length, greaterThan(200));
  });

  test('reminder foreground colors remain readable in both theme modes', () {
    for (var hue = 0; hue < 360; hue++) {
      final event = CalendarEventColor(
        HSLColor.fromAHSL(1, hue.toDouble(), 0.72, 0.48).toColor(),
      );
      expect(
        _contrastRatio(event.foreground(false), Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: 'Light mode hue $hue',
      );
      expect(
        _contrastRatio(event.foreground(true), const Color(0xFF0B0F14)),
        greaterThanOrEqualTo(4.5),
        reason: 'Dark mode hue $hue',
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
