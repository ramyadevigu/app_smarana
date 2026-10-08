import 'package:app_smarana/features/my_day/my_day_screen.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_reminder_notification_scheduler.dart';

void main() {
  testWidgets('completes and persists a daily task occurrence', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = ReminderStorage(
      notificationScheduler: FakeReminderNotificationScheduler(),
    );
    await storage.addReminder(
      Reminder(
        id: 'daily-task',
        title: 'Review plans',
        dateTime: DateTime(2026, 10, 7, 9),
        recurrenceRule: const RecurrenceRule(type: RecurrenceType.daily),
        createdAt: DateTime(2026, 10, 1),
      ),
    );
    final screen = MyDayScreen(
      appMenu: const SizedBox.shrink(),
      navigationDrawer: const SizedBox.shrink(),
      storage: storage,
      clock: () => DateTime(2026, 10, 8, 8),
    );

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
    expect(find.text('Review plans'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect((await storage.getReminders()).single.isCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
