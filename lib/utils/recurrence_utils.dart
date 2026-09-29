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

  final endDate = recurrence.endDate;
  if (endDate != null &&
      DateTime(
        start.year,
        start.month,
        start.day,
      ).isAfter(DateTime(endDate.year, endDate.month, endDate.day))) {
    return null;
  }

  final boundary = start.isUtc ? after.toUtc() : after.toLocal();
  if (start.isAfter(boundary)) {
    return start;
  }

  final occurrence = switch (recurrence.type) {
    RecurrenceType.none => null,
    RecurrenceType.daily => _nextDaily(start, recurrence, boundary),
    RecurrenceType.weekly => _nextWeekly(start, recurrence, boundary),
    RecurrenceType.monthly => _nextMonthly(start, recurrence, boundary),
    RecurrenceType.yearly => _nextYearly(start, recurrence, boundary),
  };

  if (occurrence == null || endDate == null) {
    return occurrence;
  }

  final occurrenceDate = DateTime(
    occurrence.year,
    occurrence.month,
    occurrence.day,
  );
  final finalDate = DateTime(endDate.year, endDate.month, endDate.day);
  return occurrenceDate.isAfter(finalDate) ? null : occurrence;
}

DateTime _nextDaily(DateTime start, RecurrenceRule recurrence, DateTime after) {
  final startDate = DateTime(start.year, start.month, start.day);
  final afterDate = DateTime(after.year, after.month, after.day);
  final daysAfterStart = afterDate.difference(startDate).inDays;
  var daysUntil =
      daysAfterStart +
      (recurrence.interval - daysAfterStart % recurrence.interval) %
          recurrence.interval;
  var candidate = _atTimeOn(
    start,
    start.year,
    start.month,
    start.day + daysUntil,
  );
  if (!candidate.isAfter(after)) {
    daysUntil += recurrence.interval;
    candidate = _atTimeOn(
      start,
      start.year,
      start.month,
      start.day + daysUntil,
    );
  }
  return candidate;
}

DateTime _nextWeekly(
  DateTime start,
  RecurrenceRule recurrence,
  DateTime after,
) {
  final weekdays = recurrence.weekdays.isNotEmpty
      ? recurrence.weekdays
      : [recurrence.dayOfWeek ?? start.weekday];
  final startDate = DateTime(start.year, start.month, start.day);
  final startWeek = DateTime(
    start.year,
    start.month,
    start.day - (start.weekday - DateTime.monday),
  );
  final afterDate = DateTime(after.year, after.month, after.day);
  final daysAfterStart = afterDate.difference(startDate).inDays;

  for (
    var daysUntil = 0;
    daysUntil <= recurrence.interval * DateTime.daysPerWeek + 7;
    daysUntil++
  ) {
    final date = afterDate.add(Duration(days: daysUntil));
    final dayOffset = date.difference(startDate).inDays;
    final weekOffset =
        date.difference(startWeek).inDays ~/ DateTime.daysPerWeek;
    if (dayOffset < daysAfterStart ||
        dayOffset < 0 ||
        weekOffset % recurrence.interval != 0 ||
        !weekdays.contains(date.weekday)) {
      continue;
    }

    final candidate = _atTimeOn(start, date.year, date.month, date.day);
    if (!candidate.isBefore(start) && candidate.isAfter(after)) {
      return candidate;
    }
  }
  throw StateError('Unable to find the next weekly occurrence.');
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

  final startMonth = start.year * 12 + start.month - 1;
  final afterMonth = after.year * 12 + after.month - 1;
  var monthsAfterStart = afterMonth - startMonth;
  monthsAfterStart +=
      (recurrence.interval - monthsAfterStart % recurrence.interval) %
      recurrence.interval;

  while (true) {
    final targetMonth = _atTimeOn(
      start,
      start.year,
      start.month + monthsAfterStart,
      1,
    );
    final candidate = _monthlyDate(
      start,
      targetMonth.year,
      targetMonth.month,
      targetDay,
    );
    if (!candidate.isBefore(start) && candidate.isAfter(after)) {
      return candidate;
    }
    monthsAfterStart += recurrence.interval;
  }
}

DateTime _nextYearly(
  DateTime start,
  RecurrenceRule recurrence,
  DateTime after,
) {
  var yearsAfterStart = after.year - start.year;
  yearsAfterStart +=
      (recurrence.interval - yearsAfterStart % recurrence.interval) %
      recurrence.interval;
  final month = recurrence.monthOfYear ?? start.month;
  final day = recurrence.dayOfMonth ?? start.day;

  while (true) {
    final candidate = _monthlyDate(
      start,
      start.year + yearsAfterStart,
      month,
      day,
    );
    if (!candidate.isBefore(start) && candidate.isAfter(after)) {
      return candidate;
    }
    yearsAfterStart += recurrence.interval;
  }
}

DateTime _monthlyDate(DateTime start, int year, int month, int requestedDay) {
  final lastDay = _atTimeOn(start, year, month + 1, 0).day;
  return _atTimeOn(start, year, month, requestedDay.clamp(1, lastDay));
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
