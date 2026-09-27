import '../models/reminder.dart';

class RecurrenceCalculator {
  /// Returns the next occurrence of a reminder.
  ///
  /// Returns null when the reminder does not repeat.
  static DateTime? getNextOccurrence(
    Reminder reminder, {
    DateTime? from,
  }) {
    final current = from ?? DateTime.now();

    switch (reminder.recurrenceRule.type) {
      case RecurrenceType.none:
        return null;

      case RecurrenceType.daily:
        return _nextDaily(
          reminder.dateTime,
          current,
        );

      case RecurrenceType.weekly:
        return _nextWeekly(
          reminder.dateTime,
          reminder.recurrenceRule.dayOfWeek,
          current,
        );

      case RecurrenceType.monthly:
        return _nextMonthly(
          reminder.dateTime,
          reminder.recurrenceRule.dayOfMonth,
          current,
        );

      case RecurrenceType.yearly:
        return _nextYearly(
          reminder.dateTime,
          current,
        );
    }
  }

  static DateTime _nextDaily(
    DateTime original,
    DateTime from,
  ) {
    var next = DateTime(
      from.year,
      from.month,
      from.day,
      original.hour,
      original.minute,
      original.second,
    );

    if (!next.isAfter(from)) {
      next = next.add(const Duration(days: 1));
    }

    return next;
  }

  static DateTime _nextWeekly(
    DateTime original,
    int? dayOfWeek,
    DateTime from,
  ) {
    final targetDay = dayOfWeek ?? original.weekday;

    var daysUntil = targetDay - from.weekday;

    if (daysUntil < 0) {
      daysUntil += 7;
    }

    var next = DateTime(
      from.year,
      from.month,
      from.day,
      original.hour,
      original.minute,
      original.second,
    ).add(Duration(days: daysUntil));

    if (!next.isAfter(from)) {
      next = next.add(const Duration(days: 7));
    }

    return next;
  }

  static DateTime _nextMonthly(
    DateTime original,
    int? dayOfMonth,
    DateTime from,
  ) {
    final targetDay = dayOfMonth ?? original.day;

    var year = from.year;
    var month = from.month;

    var day = _validDayOfMonth(
      year,
      month,
      targetDay,
    );

    var next = DateTime(
      year,
      month,
      day,
      original.hour,
      original.minute,
      original.second,
    );

    if (!next.isAfter(from)) {
      month++;

      if (month > 12) {
        month = 1;
        year++;
      }

      day = _validDayOfMonth(
        year,
        month,
        targetDay,
      );

      next = DateTime(
        year,
        month,
        day,
        original.hour,
        original.minute,
        original.second,
      );
    }

    return next;
  }

  static DateTime _nextYearly(
    DateTime original,
    DateTime from,
  ) {
    var year = from.year;

    var next = DateTime(
      year,
      original.month,
      original.day,
      original.hour,
      original.minute,
      original.second,
    );

    if (!next.isAfter(from)) {
      year++;
      next = DateTime(
        year,
        original.month,
        original.day,
        original.hour,
        original.minute,
        original.second,
      );
    }

    return next;
  }

  /// Prevents invalid dates such as February 30.
  ///
  /// Example:
  /// Monthly reminder on the 31st:
  /// February → 28/29
  /// April → 30
  /// May → 31
  static int _validDayOfMonth(
    int year,
    int month,
    int requestedDay,
  ) {
    final lastDay = DateTime(
      year,
      month + 1,
      0,
    ).day;

    return requestedDay.clamp(
      1,
      lastDay,
    );
  }
}