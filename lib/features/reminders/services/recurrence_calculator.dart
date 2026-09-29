import '../models/reminder.dart';
import '../../../utils/recurrence_utils.dart';

class RecurrenceCalculator {
  /// Returns the next occurrence of a reminder.
  ///
  /// Returns null when the reminder does not repeat.
  static DateTime? getNextOccurrence(Reminder reminder, {DateTime? from}) {
    return nextOccurrence(reminder, after: from ?? DateTime.now());
  }
}
