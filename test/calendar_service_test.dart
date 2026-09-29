import 'package:app_smarana/features/calender/services/calendar_service.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = CalendarService();

  test('projects single and recurring reminders into a date range', () {
    final reminders = [
      _reminder(
        id: 'monthly',
        title: 'Monthly',
        dateTime: DateTime(2026, 1, 31, 9),
        type: RecurrenceType.monthly,
        dayOfMonth: 31,
      ),
      _reminder(
        id: 'once',
        title: 'One-time',
        dateTime: DateTime(2026, 2, 28, 8),
      ),
      _reminder(
        id: 'daily',
        title: 'Daily',
        dateTime: DateTime(2026, 2, 27, 7),
        type: RecurrenceType.daily,
      ),
    ];

    final occurrences = service.occurrencesBetween(
      reminders,
      start: DateTime(2026, 2, 1),
      endExclusive: DateTime(2026, 3, 1),
    );

    expect(occurrences.keys, contains(DateTime(2026, 2, 27)));
    expect(occurrences.keys, contains(DateTime(2026, 2, 28)));
    expect(
      occurrences[DateTime(2026, 2, 28)]!.map((item) => item.reminder.id),
      ['daily', 'once', 'monthly'],
    );
    expect(occurrences.keys, isNot(contains(DateTime(2026, 3, 1))));
  });

  test('excludes disabled and completed reminders', () {
    final reminders = [
      _reminder(
        id: 'disabled',
        title: 'Disabled',
        dateTime: DateTime(2026, 9, 29, 9),
        enabled: false,
      ),
      _reminder(
        id: 'completed',
        title: 'Completed',
        dateTime: DateTime(2026, 9, 29, 10),
        isCompleted: true,
      ),
    ];

    expect(
      service.occurrencesBetween(
        reminders,
        start: DateTime(2026, 9, 1),
        endExclusive: DateTime(2026, 10, 1),
      ),
      isEmpty,
    );
  });
}

Reminder _reminder({
  required String id,
  required String title,
  required DateTime dateTime,
  RecurrenceType type = RecurrenceType.none,
  int? dayOfMonth,
  bool enabled = true,
  bool isCompleted = false,
}) {
  return Reminder(
    id: id,
    title: title,
    dateTime: dateTime,
    recurrenceRule: RecurrenceRule(type: type, dayOfMonth: dayOfMonth),
    enabled: enabled,
    isCompleted: isCompleted,
    createdAt: DateTime(2026),
  );
}
