import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/screens/add_reminder_screen.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_reminder_notification_scheduler.dart';

void main() {
  testWidgets('saves the requested fields and preserves edit metadata', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = ReminderStorage(
      notificationScheduler: FakeReminderNotificationScheduler(),
    );
    final selectedDate = DateTime(2030, 1, 15);

    await _openForm(tester, storage: storage, initialDate: selectedDate);
    await _saveForm(tester);
    expect(find.text('Title is required.'), findsOneWidget);
    expect(await storage.getReminders(), isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'Dentist appointment',
    );
    await tester.enterText(
      find.byKey(const ValueKey('description-field')),
      'Bring the insurance card',
    );

    await tester.tap(find.byKey(const ValueKey('date-field')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('time-field')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final timeLabel =
        tester
                .widget<ListTile>(find.byKey(const ValueKey('time-field')))
                .subtitle!
            as Text;
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(AddReminderScreen)),
    );

    await _saveForm(tester);

    final saved = (await storage.getReminders()).single;
    expect(saved.title, 'Dentist appointment');
    expect(saved.description, 'Bring the insurance card');
    expect(saved.dateTime.year, selectedDate.year);
    expect(saved.dateTime.month, selectedDate.month);
    expect(saved.dateTime.day, selectedDate.day);
    expect(
      localizations.formatTimeOfDay(
        TimeOfDay(hour: saved.dateTime.hour, minute: saved.dateTime.minute),
      ),
      timeLabel.data,
    );
    expect(saved.recurrenceRule.type, RecurrenceType.none);

    final recurring = saved.copyWith(
      recurrenceRule: const RecurrenceRule(
        type: RecurrenceType.weekly,
        dayOfWeek: DateTime.tuesday,
      ),
      enabled: false,
    );
    await storage.updateReminder(recurring);
    await _openForm(tester, storage: storage, reminder: recurring);
    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'Updated appointment',
    );
    await _saveForm(tester);

    final updated = (await storage.getReminders()).single;
    expect(updated.title, 'Updated appointment');
    expect(updated.dateTime, saved.dateTime);
    expect(updated.recurrenceRule.type, RecurrenceType.weekly);
    expect(updated.recurrenceRule.dayOfWeek, DateTime.tuesday);
    expect(updated.enabled, isFalse);
  });

  testWidgets('selects recurrence options and updates custom summary', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = ReminderStorage(
      notificationScheduler: FakeReminderNotificationScheduler(),
    );

    await _openForm(
      tester,
      storage: storage,
      initialDate: DateTime(2030, 1, 15),
    );
    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'Recurring reminder',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byKey(const ValueKey('repeat-field')));
    await tester.pumpAndSettle();
    for (final label in [
      'Does not repeat',
      'Every day',
      'Every week',
      'Every 2 weeks',
      'Alternate weeks',
      'Every month',
      'Every 2 months',
      'Alternate months',
      'Every year',
      'Custom',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }

    final weeklyOption = find.text('Every week');
    await tester.ensureVisible(weeklyOption);
    await tester.tap(weeklyOption);
    await tester.pumpAndSettle();
    for (final weekday in [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ]) {
      final weekdayChip = find.byKey(ValueKey('weekday-$weekday'));
      await tester.ensureVisible(weekdayChip);
      await tester.tap(weekdayChip);
    }
    final tuesdayChip = find.byKey(const ValueKey('weekday-2'));
    await tester.ensureVisible(tuesdayChip);
    await tester.tap(tuesdayChip);
    final weeklyDoneButton = find.text('Done');
    await tester.ensureVisible(weeklyDoneButton);
    await tester.tap(weeklyDoneButton);
    await tester.pumpAndSettle();
    expect(find.text('Every Monday, Wednesday, Friday'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('repeat-field')));
    await tester.pumpAndSettle();
    final customOption = find.text('Custom');
    await tester.ensureVisible(customOption);
    await tester.tap(customOption);
    await tester.pumpAndSettle();
    final intervalField = find.byKey(const ValueKey('repeat-interval-custom'));
    await tester.ensureVisible(intervalField);
    await tester.enterText(intervalField, '2');
    final startDateOption = find.text('Start date');
    await tester.ensureVisible(startDateOption);
    await tester.tap(startDateOption);
    await tester.pumpAndSettle();
    await tester.tap(find.text('18').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final endDateButton = find.byTooltip('Choose end date');
    await tester.ensureVisible(endDateButton);
    await tester.tap(endDateButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final customDoneButton = find.text('Done');
    await tester.ensureVisible(customDoneButton);
    await tester.tap(customDoneButton);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Every 2 weeks on Monday, Wednesday, Friday'),
      findsOneWidget,
    );
    expect(find.textContaining('until'), findsOneWidget);
    expect(
      (tester
                  .widget<ListTile>(find.byKey(const ValueKey('date-field')))
                  .subtitle!
              as Text)
          .data,
      contains('18'),
    );
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  required ReminderStorage storage,
  Reminder? reminder,
  DateTime? initialDate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open-form'),
            onPressed: () {
              Navigator.of(context).push<Reminder>(
                MaterialPageRoute(
                  builder: (_) => AddReminderScreen(
                    reminder: reminder,
                    storage: storage,
                    initialDate: initialDate,
                  ),
                ),
              );
            },
            child: const Text('Open form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-form')));
  await tester.pumpAndSettle();
}

Future<void> _saveForm(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
  await tester.tap(find.byKey(const ValueKey('save-reminder')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
