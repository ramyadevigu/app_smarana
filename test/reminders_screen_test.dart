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
      await tester.scrollUntilVisible(
        find.text('Disabled one-time'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Does not repeat'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);

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

      final editedReminderId = (await storage.getReminders())
          .singleWhere((reminder) => reminder.title == 'Edited reminder')
          .id;
      final reminderCard = find.ancestor(
        of: find.text('Edited reminder'),
        matching: find.byType(Card),
      );
      expect(reminderCard, findsOneWidget);
      final reminderMenu = find.descendant(
        of: reminderCard,
        matching: find.byKey(ValueKey('reminder-menu-$editedReminderId')),
      );
      await tester.tap(reminderMenu);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('delete-reminder-$editedReminderId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete reminder?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edited reminder'), findsOneWidget);

      await tester.tap(reminderMenu);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('delete-reminder-$editedReminderId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Edited reminder'), findsNothing);
      expect(await storage.getReminders(), hasLength(4));
      expect(
        (await storage.getReminders()).map((reminder) => reminder.id).toSet(),
        {'weekly', 'monthly', 'yearly', 'disabled'},
      );
    },
  );

  testWidgets('shows a designed empty state with an add action', (
    tester,
  ) async {
    final storage = _RecoveringReminderStorage()..shouldFail = false;
    await tester.pumpWidget(
      MaterialApp(home: RemindersScreen(storage: storage)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No reminders yet'), findsOneWidget);
    expect(find.text('Your reminders will appear here.'), findsOneWidget);
    expect(find.byTooltip('Add reminder'), findsOneWidget);
  });

  testWidgets('shows loading and recoverable error states', (tester) async {
    final storage = _RecoveringReminderStorage();
    await tester.pumpWidget(
      MaterialApp(home: RemindersScreen(storage: storage)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Unable to load reminders'), findsOneWidget);

    storage.shouldFail = false;
    await tester.tap(find.byKey(const ValueKey('retry-reminders')));
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet'), findsOneWidget);
  });
}

class _RecoveringReminderStorage extends ReminderStorage {
  bool shouldFail = true;

  @override
  Future<List<Reminder>> getReminders() async {
    if (shouldFail) {
      throw StateError('Read failed');
    }
    return [];
  }
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
