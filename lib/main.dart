import 'package:flutter/material.dart';

import 'features/reminders/services/reminder_storage.dart';
import 'services/notification_service.dart';
import 'theme/theme_preference_store.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reminderStorage = ReminderStorage();
  await reminderStorage.initialize();
  await NotificationService.instance.initialize();
  await reminderStorage.rescheduleAllReminders();
  const themePreferenceStore = ThemePreferenceStore();
  final themeMode = await themePreferenceStore.loadThemeMode();
  final colorTheme = await themePreferenceStore.loadColorTheme();
  runApp(
    AppSmarana(
      initialThemeMode: themeMode,
      initialColorTheme: colorTheme,
      themePreferenceStore: themePreferenceStore,
    ),
  );
}
