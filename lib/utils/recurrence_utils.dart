import '../features/reminders/models/reminder.dart';

/// Returns the next scheduled occurrence strictly after [after].
///
/// A future start date is returned as the first occurrence. One-time reminders
/// have no next occurrence. Monthly and yearly dates are clamped to the final
/// valid day of the target month when necessary.
DateTime? nextOccurrence(Reminder reminder, {required DateTime after}) {
  final start = reminder.dateTime;
  final recurrence = reminder.recurrenceRule;

  if (recurrence.type == RecurrenceType.none) {
    return null;
  }

  final boundary = start.isUtc ? after.toUtc() : after.toLocal();
  if (start.isAfter(boundary)) {
    return start;
  }

  return switch (recurrence.type) {
    RecurrenceType.none => null,
    RecurrenceType.daily => _nextDaily(start, boundary),
    RecurrenceType.weekly => _nextWeekly(start, recurrence, boundary),
    RecurrenceType.monthly => _nextMonthly(start, recurrence, boundary),
    RecurrenceType.yearly => _nextYearly(start, boundary),
  };
}

DateTime _nextDaily(DateTime start, DateTime after) {
  var candidate = _atTimeOn(start, after.year, after.month, after.day);
  if (!candidate.isAfter(after)) {
    candidate = _atTimeOn(start, after.year, after.month, after.day + 1);
  }
  return candidate;
}

DateTime _nextWeekly(
  DateTime start,
  RecurrenceRule recurrence,
  DateTime after,
) {
  final configuredDay = recurrence.dayOfWeek;
  final targetDay =
      configuredDay != null &&
          configuredDay >= DateTime.monday &&
          configuredDay <= DateTime.sunday
      ? configuredDay
      : start.weekday;
  final daysUntil =
      (targetDay - after.weekday + DateTime.daysPerWeek) % DateTime.daysPerWeek;

  var candidate = _atTimeOn(
    start,
    after.year,
    after.month,
    after.day + daysUntil,
  );
  if (!candidate.isAfter(after)) {
    candidate = _atTimeOn(
      start,
      after.year,
      after.month,
      after.day + daysUntil + DateTime.daysPerWeek,
    );
  }
  return candidate;
}

DateTime _nextMonthly(
  DateTime start,
  RecurrenceRule recurrence,
  DateTime after,
) {
  final configuredDay = recurrence.dayOfMonth;
  final targetDay =
      configuredDay != null && configuredDay >= 1 && configuredDay <= 31
      ? configuredDay
      : start.day;

  var candidate = _monthlyDate(start, after.year, after.month, targetDay);
  if (!candidate.isAfter(after)) {
    final nextMonth = _atTimeOn(start, after.year, after.month + 1, 1);
    candidate = _monthlyDate(start, nextMonth.year, nextMonth.month, targetDay);
  }
  return candidate;
}

DateTime _nextYearly(DateTime start, DateTime after) {
  var candidate = _yearlyDate(start, after.year);
  if (!candidate.isAfter(after)) {
    candidate = _yearlyDate(start, after.year + 1);
  }
  return candidate;
}

DateTime _monthlyDate(DateTime start, int year, int month, int requestedDay) {
  final lastDay = _atTimeOn(start, year, month + 1, 0).day;
  return _atTimeOn(start, year, month, requestedDay.clamp(1, lastDay));
}

DateTime _yearlyDate(DateTime start, int year) {
  final lastDay = _atTimeOn(start, year, start.month + 1, 0).day;
  return _atTimeOn(start, year, start.month, start.day.clamp(1, lastDay));
}

DateTime _atTimeOn(DateTime time, int year, int month, int day) {
  if (time.isUtc) {
    return DateTime.utc(
      year,
      month,
      day,
      time.hour,
      time.minute,
      time.second,
      time.millisecond,
      time.microsecond,
    );
  }

  return DateTime(
    year,
    month,
    day,
    time.hour,
    time.minute,
    time.second,
    time.millisecond,
    time.microsecond,
  );
}
