import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/services/notification_service.dart';

class FakeReminderNotificationScheduler
    implements ReminderNotificationScheduler {
  final operations = <String>[];
  final scheduledReminders = <String, Reminder>{};

  @override
  Future<void> scheduleReminder(Reminder reminder) async {
    operations.add('schedule:${reminder.id}');
    scheduledReminders[reminder.id] = reminder;
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    operations.add('cancel:$reminderId');
    scheduledReminders.remove(reminderId);
  }
}