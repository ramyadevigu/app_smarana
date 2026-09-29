import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/reminders/services/reminder_storage.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> reminderNotificationActionCallback(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (response.actionId != 'snooze') {
    return;
  }

  final reminderId = response.payload;
  if (reminderId == null || reminderId.isEmpty) {
    return;
  }

  final preferences = await SharedPreferences.getInstance();
  final exactAlarmAllowed =
      preferences.getBool('reminderExactAlarmAllowed') ?? false;
  final notificationService = NotificationService.instance;
  await notificationService.initializeInBackground(
    exactAlarmAllowed: exactAlarmAllowed,
  );

  final storage = ReminderStorage();
  final reminders = await storage.getReminders();
  for (final reminder in reminders) {
    if (reminder.id != reminderId ||
        !reminder.enabled ||
        reminder.isCompleted) {
      continue;
    }

    await storage.updateReminder(
      reminder.copyWith(
        snoozedUntil: DateTime.now().add(
          Duration(minutes: reminder.snoozeDurationMinutes),
        ),
      ),
    );
    return;
  }
}
