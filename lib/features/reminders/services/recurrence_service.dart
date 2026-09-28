import '../models/reminder.dart';
import '../../../utils/recurrence_utils.dart' as recurrence_utils;

class RecurrenceService {
  DateTime? nextOccurrence(Reminder reminder, {required DateTime after}) {
    return recurrence_utils.nextOccurrence(reminder, after: after);
  }
}
