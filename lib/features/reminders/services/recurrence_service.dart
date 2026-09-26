import '../models/reminder.dart';

class RecurrenceService {
  DateTime? nextOccurrence(Reminder reminder, {required DateTime after}) {
    final start = reminder.dateTime;

    switch (reminder.recurrenceRule.type) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        return _nextByDays(start, after, 1);
      case RecurrenceType.weekly:
        return _nextByDays(start, after, 7);
      case RecurrenceType.monthly:
        return _nextByMonths(start, after, 1);
      case RecurrenceType.yearly:
        return _nextByMonths(start, after, 12);
    }
  }

  DateTime _nextByDays(DateTime start, DateTime after, int interval) {
    var candidate = start;
    while (!candidate.isAfter(after)) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + interval,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
        start.microsecond,
      );
    }
    return candidate;
  }

  DateTime _nextByMonths(DateTime start, DateTime after, int interval) {
    var monthOffset = interval;
    var candidate = _dateInMonth(start, monthOffset);

    while (!candidate.isAfter(after)) {
      monthOffset += interval;
      candidate = _dateInMonth(start, monthOffset);
    }
    return candidate;
  }

  DateTime _dateInMonth(DateTime start, int monthOffset) {
    final month = start.month + monthOffset;
    final year = start.year + (month - 1) ~/ 12;
    final monthOfYear = (month - 1) % 12 + 1;
    final lastDay = DateTime(year, monthOfYear + 1, 0).day;

    return DateTime(
      year,
      monthOfYear,
      start.day.clamp(1, lastDay),
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
  }
}
