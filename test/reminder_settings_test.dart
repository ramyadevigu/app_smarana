import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/screens/add_reminder_screen.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:app_smarana/features/settings/services/reminder_preferences_store.dart';
import 'package:app_smarana/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_reminder_notification_scheduler.dart';

void main() {
  testWidgets('settings persist and become defaults for new reminders', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const soundChannel = MethodChannel('smarana/reminder_sounds');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          soundChannel,
          (call) async => [
            {'name': 'Morning Bell', 'uri': 'content://alarms/morning-bell'},
          ],
        );
    const preferencesStore = ReminderPreferencesStore();
    final storage = ReminderStorage(
      notificationScheduler: FakeReminderNotificationScheduler(),
    );
    var selectedThemeMode = ThemeMode.system;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const ValueKey('open-settings'),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(
                        selectedThemeMode: selectedThemeMode,
                        preferencesStore: preferencesStore,
                        onThemeModeChanged: (mode) async {
                          selectedThemeMode = mode;
                        },
                      ),
                    ),
                  ),
                  child: const Text('Settings'),
                ),
                TextButton(
                  key: const ValueKey('open-add-reminder'),
                  onPressed: () => Navigator.of(context).push<Reminder>(
                    MaterialPageRoute<Reminder>(
                      builder: (_) => AddReminderScreen(
                        storage: storage,
                        preferencesStore: preferencesStore,
                        initialDate: DateTime(2030, 1, 15),
                      ),
                    ),
                  ),
                  child: const Text('Add reminder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notification only'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-default-ringtone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning Bell').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-default-snooze')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20 minutes'));
    await tester.pumpAndSettle();
    final vibrationSwitch = find.descendant(
      of: find.byKey(const ValueKey('settings-default-vibration')),
      matching: find.byType(Switch),
    );
    await tester.tap(vibrationSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final defaults = await preferencesStore.loadDefaults();
    expect(
      defaults.notificationMode,
      ReminderNotificationMode.notificationOnly,
    );
    expect(defaults.soundUri, 'content://alarms/morning-bell');
    expect(defaults.soundName, 'Morning Bell');
    expect(defaults.snoozeDurationMinutes, 20);
    expect(defaults.vibrate, isFalse);
    expect(selectedThemeMode, ThemeMode.dark);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-add-reminder')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'Uses saved defaults',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
    await tester.tap(find.byKey(const ValueKey('save-reminder')));
    await tester.pumpAndSettle();

    final savedReminder = (await storage.getReminders()).single;
    expect(
      savedReminder.notificationMode,
      ReminderNotificationMode.notificationOnly,
    );
    expect(savedReminder.soundUri, 'content://alarms/morning-bell');
    expect(savedReminder.snoozeDurationMinutes, 20);
    expect(savedReminder.vibrate, isFalse);
  });
}
