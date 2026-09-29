import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/utils/recurrence_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one-time reminders have no next occurrence', () {
    final reminder = _reminderAt(
      DateTime(2026, 10, 15, 9, 30),
      RecurrenceType.none,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 10, 15, 9, 30)),
      isNull,
    );
  });

  test('returns the scheduled start when it is still in the future', () {
    final scheduled = DateTime(2026, 10, 15, 9, 30);
    final reminder = _reminderAt(scheduled, RecurrenceType.daily);

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 10, 14, 12)),
      scheduled,
    );
  });

  test('advances daily reminders at their scheduled time', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 28, 9, 30),
      RecurrenceType.daily,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 28, 9, 30)),
      DateTime(2026, 9, 29, 9, 30),
    );
  });

  test('advances weekly reminders to their configured weekday', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 28, 9, 30),
      RecurrenceType.weekly,
      dayOfWeek: DateTime.monday,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 29, 10)),
      DateTime(2026, 10, 5, 9, 30),
    );
  });

  test('supports selected weekdays within each eligible week', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 28, 9, 30),
      RecurrenceType.weekly,
      weekdays: const [DateTime.monday, DateTime.wednesday, DateTime.friday],
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 29, 10)),
      DateTime(2026, 9, 30, 9, 30),
    );
  });

  test('anchors every-two-week recurrence to the selected start week', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 28, 9, 30),
      RecurrenceType.weekly,
      interval: 2,
      weekdays: const [DateTime.monday],
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 28, 9, 30)),
      DateTime(2026, 10, 12, 9, 30),
    );
  });

  test('advances monthly reminders to the configured day', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 3, 9, 30),
      RecurrenceType.monthly,
      dayOfMonth: 3,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 3, 9, 30)),
      DateTime(2026, 10, 3, 9, 30),
    );
  });

  test('supports every-two-month recurrence', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 3, 9, 30),
      RecurrenceType.monthly,
      interval: 2,
      dayOfMonth: 3,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 3, 9, 30)),
      DateTime(2026, 11, 3, 9, 30),
    );
  });

  test('clamps invalid monthly dates to each month end', () {
    final commonYearReminder = _reminderAt(
      DateTime(2026, 1, 31, 9, 30),
      RecurrenceType.monthly,
    );
    final leapYearReminder = _reminderAt(
      DateTime(2028, 1, 31, 9, 30),
      RecurrenceType.monthly,
    );

    expect(
      nextOccurrence(commonYearReminder, after: DateTime(2026, 1, 31, 9, 30)),
      DateTime(2026, 2, 28, 9, 30),
    );
    expect(
      nextOccurrence(leapYearReminder, after: DateTime(2028, 1, 31, 9, 30)),
      DateTime(2028, 2, 29, 9, 30),
    );
  });

  test('handles monthly days 28 through 31 in common and leap February', () {
    for (final day in [28, 29, 30, 31]) {
      final reminder = _reminderAt(
        DateTime(2026, 1, 1, 9, 30),
        RecurrenceType.monthly,
        dayOfMonth: day,
      );
      final commonFebruaryDay = day.clamp(1, 28);
      expect(
        nextOccurrence(reminder, after: DateTime(2026, 1, 31, 9, 30)),
        DateTime(2026, 2, commonFebruaryDay, 9, 30),
      );
      expect(
        nextOccurrence(
          reminder,
          after: DateTime(2026, 2, commonFebruaryDay, 9, 30),
        ),
        DateTime(2026, 3, day, 9, 30),
      );

      final leapReminder = _reminderAt(
        DateTime(2028, 1, 1, 9, 30),
        RecurrenceType.monthly,
        dayOfMonth: day,
      );
      final leapFebruaryDay = day.clamp(1, 29);
      expect(
        nextOccurrence(leapReminder, after: DateTime(2028, 1, 31, 9, 30)),
        DateTime(2028, 2, leapFebruaryDay, 9, 30),
      );
      expect(
        nextOccurrence(
          leapReminder,
          after: DateTime(2028, 2, leapFebruaryDay, 9, 30),
        ),
        DateTime(2028, 3, day, 9, 30),
      );
    }
  });

  test('advances yearly reminders across year boundaries', () {
    final reminder = _reminderAt(
      DateTime(2026, 12, 31, 9, 30),
      RecurrenceType.yearly,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 12, 31, 9, 30)),
      DateTime(2027, 12, 31, 9, 30),
    );
  });

  test('supports a configured yearly month and day', () {
    final reminder = _reminderAt(
      DateTime(2026, 1, 1, 9, 30),
      RecurrenceType.yearly,
      monthOfYear: 6,
      dayOfMonth: 15,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 1, 1, 9, 30)),
      DateTime(2026, 6, 15, 9, 30),
    );
  });

  test('does not schedule an occurrence after the configured end date', () {
    final reminder = _reminderAt(
      DateTime(2026, 9, 28, 9, 30),
      RecurrenceType.daily,
      endDate: DateTime(2026, 9, 29),
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2026, 9, 29, 9, 30)),
      isNull,
    );
  });

  test('clamps yearly leap-day reminders and restores leap days', () {
    final reminder = _reminderAt(
      DateTime(2024, 2, 29, 9, 30),
      RecurrenceType.yearly,
    );

    expect(
      nextOccurrence(reminder, after: DateTime(2024, 2, 29, 9, 30)),
      DateTime(2025, 2, 28, 9, 30),
    );
    expect(
      nextOccurrence(reminder, after: DateTime(2027, 2, 28, 9, 30)),
      DateTime(2028, 2, 29, 9, 30),
    );
  });

  test(
    'calculates the next future occurrence when the start is in the past',
    () {
      final reminder = _reminderAt(
        DateTime(2020, 1, 1, 9, 30),
        RecurrenceType.daily,
      );

      expect(
        nextOccurrence(reminder, after: DateTime(2026, 9, 28, 10)),
        DateTime(2026, 9, 29, 9, 30),
      );
    },
  );
}

Reminder _reminderAt(
  DateTime dateTime,
  RecurrenceType recurrence, {
  int interval = 1,
  int? dayOfMonth,
  int? dayOfWeek,
  List<int> weekdays = const [],
  int? monthOfYear,
  DateTime? endDate,
}) {
  return Reminder(
    id: 'reminder',
    title: 'Reminder',
    dateTime: dateTime,
    recurrenceRule: RecurrenceRule(
      type: recurrence,
      interval: interval,
      dayOfMonth: dayOfMonth,
      dayOfWeek: dayOfWeek,
      weekdays: weekdays,
      monthOfYear: monthOfYear,
      endDate: endDate,
    ),
    createdAt: DateTime(2026),
  );
}
