import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/reminders_screen.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_reminder_notification_scheduler.dart';

void main() {
  testWidgets(
    'displays reminders and refreshes after create, edit, and delete',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = ReminderStorage(
        notificationScheduler: FakeReminderNotificationScheduler(),
      );
      await storage.saveReminders([
        _reminder(
          id: 'weekly',
          title: 'Weekly check-in',
          dateTime: DateTime(2026, 9, 28, 8),
          recurrenceRule: const RecurrenceRule(
            type: RecurrenceType.weekly,
            dayOfWeek: DateTime.monday,
          ),
          description: 'Call the team',
        ),
        _reminder(
          id: 'monthly',
          title: 'Monthly report',
          dateTime: DateTime(2026, 10, 3, 9, 30),
          recurrenceRule: const RecurrenceRule(
            type: RecurrenceType.monthly,
            dayOfMonth: 3,
          ),
        ),
        _reminder(
          id: 'yearly',
          title: 'Annual review',
          dateTime: DateTime(2026, 10, 15, 9, 30),
          recurrenceRule: const RecurrenceRule(type: RecurrenceType.yearly),
        ),
        _reminder(
          id: 'disabled',
          title: 'Disabled one-time',
          dateTime: DateTime(2026, 10, 16, 11),
          enabled: false,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: RemindersScreen(storage: storage)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly check-in'), findsOneWidget);
      expect(find.text('Call the team'), findsOneWidget);
      expect(find.text('Every Monday'), findsOneWidget);
      expect(find.text('3rd of every month'), findsOneWidget);
      expect(find.text('15 October every year'), findsOneWidget);
      expect(find.text('Does not repeat · Disabled'), findsOneWidget);

      await tester.tap(find.byTooltip('Add reminder'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('title-field')),
        'New reminder',
      );
      await tester.enterText(
        find.byKey(const ValueKey('description-field')),
        'Created from the list',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
      await tester.tap(find.byKey(const ValueKey('save-reminder')));
      await tester.pumpAndSettle();

      expect(find.text('New reminder'), findsOneWidget);
      expect(find.text('Created from the list'), findsOneWidget);
      expect(await storage.getReminders(), hasLength(5));

      await tester.tap(find.text('New reminder'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('title-field')),
        'Edited reminder',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
      await tester.tap(find.byKey(const ValueKey('save-reminder')));
      await tester.pumpAndSettle();

      expect(find.text('New reminder'), findsNothing);
      expect(find.text('Edited reminder'), findsOneWidget);
      expect(await storage.getReminders(), hasLength(5));

      final dismissible = find.ancestor(
        of: find.text('Edited reminder'),
        matching: find.byType(Dismissible),
      );
      await tester.ensureVisible(dismissible);
      await tester.drag(dismissible, const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Edited reminder'), findsNothing);
      expect(await storage.getReminders(), hasLength(4));
      expect(
        (await storage.getReminders()).map((reminder) => reminder.id).toSet(),
        {'weekly', 'monthly', 'yearly', 'disabled'},
      );
    },
  );
}

Reminder _reminder({
  required String id,
  required String title,
  required DateTime dateTime,
  RecurrenceRule recurrenceRule = const RecurrenceRule(
    type: RecurrenceType.none,
  ),
  String? description,
  bool enabled = true,
}) {
  return Reminder(
    id: id,
    title: title,
    description: description,
    dateTime: dateTime,
    recurrenceRule: recurrenceRule,
    enabled: enabled,
    createdAt: DateTime(2026, 9, 1),
  );
}
