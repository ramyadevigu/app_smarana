import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';

import '../features/reminders/services/reminder_storage.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> recurringReminderAlarmCallback(
  int alarmId,
  Map<String, dynamic> parameters,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final reminderId = parameters['reminderId'];
  if (reminderId is! String) {
    return;
  }

  final exactAlarmAllowed = parameters['exactAlarmAllowed'] == true;
  final notificationService = NotificationService.instance;
  await notificationService.initializeInBackground(
    exactAlarmAllowed: exactAlarmAllowed,
  );

  final reminders = await ReminderStorage().getReminders();
  for (final reminder in reminders) {
    if (reminder.id == reminderId) {
      final snoozedUntil = reminder.snoozedUntil;
      if (snoozedUntil != null && !snoozedUntil.isAfter(DateTime.now())) {
        await ReminderStorage().updateReminder(
          reminder.copyWith(clearSnoozedUntil: true),
        );
        return;
      }
      await notificationService.scheduleReminder(reminder);
      return;
    }
  }
}
