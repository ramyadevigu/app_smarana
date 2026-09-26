import 'package:flutter_test/flutter_test.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/services/recurrence_service.dart';

void main() {
  final service = RecurrenceService();

  Reminder reminderAt(DateTime dateTime, RecurrenceType recurrence) {
    return Reminder(
      id: 'reminder',
      title: 'Reminder',
      dateTime: dateTime,
      recurrence: recurrence,
      createdAt: DateTime(2026),
    );
  }

  test('advances daily reminders while preserving local time', () {
    final reminder = reminderAt(
      DateTime(2026, 9, 26, 8, 30),
      RecurrenceType.daily,
    );

    expect(
      service.nextOccurrence(reminder, after: DateTime(2026, 9, 28, 9)),
      DateTime(2026, 9, 29, 8, 30),
    );
  });

  test('clamps monthly dates to the last day of shorter months', () {
    final reminder = reminderAt(
      DateTime(2026, 1, 31, 8),
      RecurrenceType.monthly,
    );

    expect(
      service.nextOccurrence(reminder, after: DateTime(2026, 2, 28, 8)),
      DateTime(2026, 3, 31, 8),
    );
  });

  test('clamps yearly leap-day reminders in non-leap years', () {
    final reminder = reminderAt(
      DateTime(2024, 2, 29, 8),
      RecurrenceType.yearly,
    );

    expect(
      service.nextOccurrence(reminder, after: DateTime(2025, 3, 1)),
      DateTime(2026, 2, 28, 8),
    );
  });
}
