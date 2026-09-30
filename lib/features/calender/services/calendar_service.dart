import '../../reminders/models/reminder.dart';
import '../../reminders/services/recurrence_service.dart';

class CalendarOccurrence {
  const CalendarOccurrence({required this.reminder, required this.dateTime});

  final Reminder reminder;
  final DateTime dateTime;
}

class CalendarService {
  CalendarService({RecurrenceService? recurrenceService})
    : _recurrenceService = recurrenceService ?? RecurrenceService();

  final RecurrenceService _recurrenceService;

  Map<DateTime, List<CalendarOccurrence>> occurrencesBetween(
    Iterable<Reminder> reminders, {
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final rangeStart = _dateOnly(start);
    final rangeEnd = _dateOnly(endExclusive);
    if (!rangeEnd.isAfter(rangeStart)) {
      return {};
    }

    final occurrences = <DateTime, List<CalendarOccurrence>>{};
    for (final reminder in reminders) {
      if (!reminder.enabled || reminder.isCompleted) {
        continue;
      }

      final localReminder = reminder.dateTime.isUtc
          ? reminder.copyWith(dateTime: reminder.dateTime.toLocal())
          : reminder;
      if (localReminder.recurrenceRule.type == RecurrenceType.none) {
        _addIfInRange(
          occurrences,
          localReminder,
          localReminder.dateTime,
          rangeStart,
          rangeEnd,
        );
        continue;
      }

      var cursor = rangeStart.subtract(const Duration(microseconds: 1));
      while (true) {
        final occurrence = _recurrenceService.nextOccurrence(
          localReminder,
          after: cursor,
        );
        if (occurrence == null || !occurrence.isBefore(rangeEnd)) {
          break;
        }
        if (!occurrence.isBefore(rangeStart)) {
          _addIfInRange(
            occurrences,
            localReminder,
            occurrence,
            rangeStart,
            rangeEnd,
          );
        }
        if (!occurrence.isAfter(cursor)) {
          break;
        }
        cursor = occurrence;
      }
    }

    for (final dayOccurrences in occurrences.values) {
      dayOccurrences.sort((first, second) {
        final timeComparison = first.dateTime.compareTo(second.dateTime);
        return timeComparison != 0
            ? timeComparison
            : first.reminder.title.compareTo(second.reminder.title);
      });
    }
    return occurrences;
  }

  void _addIfInRange(
    Map<DateTime, List<CalendarOccurrence>> occurrences,
    Reminder reminder,
    DateTime dateTime,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final day = _dateOnly(dateTime);
    if (day.isBefore(rangeStart) || !day.isBefore(rangeEnd)) {
      return;
    }
    occurrences
        .putIfAbsent(day, () => [])
        .add(CalendarOccurrence(reminder: reminder, dateTime: dateTime));
  }

  DateTime _dateOnly(DateTime dateTime) {
    final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateTime(localDateTime.year, localDateTime.month, localDateTime.day);
  }
}
