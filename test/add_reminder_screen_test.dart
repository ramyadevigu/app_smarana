import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/screens/add_reminder_screen.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('creates and edits all recurrence types without duplicates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    for (var index = 0; index < RecurrenceType.values.length; index++) {
      final recurrence = RecurrenceType.values[index];
      if (index == 0) {
        await _openForm(tester);
        await _saveForm(tester);
        expect(find.text('Title is required.'), findsOneWidget);
        expect(await ReminderStorage().getReminders(), isEmpty);
      } else {
        await _openForm(tester);
      }

      await tester.enterText(
        find.byKey(const ValueKey('title-field')),
        'New ${recurrence.name} reminder',
      );
      await tester.enterText(
        find.byKey(const ValueKey('description-field')),
        'Details for ${recurrence.name}',
      );
      await _selectRecurrence(tester, recurrence);
      if (recurrence == RecurrenceType.monthly) {
        expect(find.textContaining('of every month at'), findsOneWidget);
      }
      await _saveForm(tester);

      final reminders = await ReminderStorage().getReminders();
      expect(reminders, hasLength(index + 1));
      final saved = reminders[index];
      expect(saved.title, 'New ${recurrence.name} reminder');
      expect(saved.description, 'Details for ${recurrence.name}');
      expect(saved.recurrenceRule.type, recurrence);

      if (recurrence == RecurrenceType.weekly) {
        expect(saved.recurrenceRule.dayOfWeek, saved.dateTime.weekday);
      }
      if (recurrence == RecurrenceType.monthly) {
        expect(saved.recurrenceRule.dayOfMonth, saved.dateTime.day);
      }
      if (recurrence == RecurrenceType.yearly) {
        expect(saved.dateTime.month, greaterThanOrEqualTo(1));
        expect(saved.dateTime.month, lessThanOrEqualTo(12));
        expect(saved.dateTime.day, greaterThanOrEqualTo(1));
        expect(saved.dateTime.day, lessThanOrEqualTo(31));
      }

      await _openForm(tester, reminder: saved);

      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('title-field')))
            .controller
            ?.text,
        saved.title,
      );
      await tester.enterText(
        find.byKey(const ValueKey('title-field')),
        'Updated ${recurrence.name} reminder',
      );
      await _saveForm(tester);

      final updatedReminders = await ReminderStorage().getReminders();
      expect(updatedReminders, hasLength(index + 1));
      final updated = updatedReminders[index];
      expect(updated.id, saved.id);
      expect(updated.title, 'Updated ${recurrence.name} reminder');
      expect(updated.description, saved.description);
      expect(updated.dateTime, saved.dateTime);
      expect(updated.recurrenceRule.type, recurrence);
      expect(updated.enabled, saved.enabled);
      expect(updated.isCompleted, saved.isCompleted);
      expect(updated.createdAt, saved.createdAt);
      if (recurrence == RecurrenceType.weekly) {
        expect(updated.recurrenceRule.dayOfWeek, saved.dateTime.weekday);
      }
      if (recurrence == RecurrenceType.monthly) {
        expect(updated.recurrenceRule.dayOfMonth, saved.dateTime.day);
      }
    }
  });
}

Future<void> _openForm(WidgetTester tester, {Reminder? reminder}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open-form'),
            onPressed: () {
              Navigator.of(context).push<Reminder>(
                MaterialPageRoute(
                  builder: (_) => AddReminderScreen(reminder: reminder),
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

Future<void> _selectRecurrence(
  WidgetTester tester,
  RecurrenceType recurrence,
) async {
  await tester.ensureVisible(find.byKey(const ValueKey('repeat-field')));
  await tester.tap(find.byKey(const ValueKey('repeat-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('repeat-${recurrence.name}')));
  await tester.pumpAndSettle();
}

Future<void> _saveForm(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
  await tester.tap(find.byKey(const ValueKey('save-reminder')));
  await tester.pumpAndSettle();
}
