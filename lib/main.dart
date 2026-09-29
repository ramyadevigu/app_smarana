import 'package:flutter/material.dart';

import 'features/reminders/services/reminder_storage.dart';
import 'services/notification_service.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await ReminderStorage().rescheduleAllReminders();
  runApp(const AppSmarana());
}
