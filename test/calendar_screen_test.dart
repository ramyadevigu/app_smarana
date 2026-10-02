import 'package:app_smarana/features/calender/calender_screen.dart';
import 'package:app_smarana/features/calender/models/calendar_view_mode.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late _TestReminderStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 9, 29, 0, 5);
    storage = _TestReminderStorage([
      _reminder(
        id: 'daily',
        title: 'Daily reminder',
        dateTime: DateTime(2026, 9, 28, 9),
        type: RecurrenceType.daily,
      ),
      _reminder(
        id: 'tomorrow',
        title: 'Tomorrow reminder',
        dateTime: DateTime(2026, 9, 30, 10),
      ),
    ]);
  });

  testWidgets('shows full-width month grid and selected week by default', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    expect(find.text('September 2026'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-previous-month')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-next-month')), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-view-monthAndWeek')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-week-agenda')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-view-selector')),
      findsOneWidget,
    );
    final previewGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('calendar-week-preview')),
    );
    expect(previewGrid.childrenDelegate.estimatedChildCount, 14);
  });

  testWidgets('renders month only layout when selected', (tester) async {
    await _pumpCalendar(
      tester,
      () => now,
      storage,
      viewMode: CalendarViewMode.monthOnly,
    );

    expect(
      find.byKey(const ValueKey('calendar-view-monthOnly')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-week-agenda')), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('view selector switches to next three days immediately', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byKey(const ValueKey('calendar-view-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next 3 Days'));
    await _pumpFrames(tester);

    expect(
      find.byKey(const ValueKey('calendar-view-nextThreeDays')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-three-day-agenda')),
      findsOneWidget,
    );
    expect(find.text('Tomorrow reminder'), findsOneWidget);
  });

  testWidgets('shows the requested empty-day message', (tester) async {
    await _pumpCalendar(tester, () => now, _TestReminderStorage([]));

    expect(find.byKey(const ValueKey('calendar-empty-day')), findsOneWidget);
    expect(find.text('No Reminders today'), findsOneWidget);
  });

  testWidgets('navigates between months and returns to today', (tester) async {
    await _pumpCalendar(tester, () => now, storage);

    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-next-month')));
    await _pumpFrames(tester);
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-previous-month')));
    await _pumpFrames(tester);
    expect(find.text('September 2026'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await _pumpFrames(tester);
    expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
  });

  testWidgets('month heading opens date picker', (tester) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byKey(const ValueKey('calendar-select-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    Navigator.of(tester.element(find.byType(DatePickerDialog)))
        .pop(DateTime(2027, 9, 29));
    await _pumpFrames(tester);

    expect(find.text('September 2027'), findsOneWidget);
    expect(find.text('Wednesday, September 29, 2027'), findsOneWidget);
  });

  testWidgets('selecting an adjacent date updates selected header and list', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-30')));
    await _pumpFrames(tester);

    expect(find.text('Wednesday, September 30, 2026'), findsOneWidget);
    expect(find.text('Tomorrow reminder'), findsOneWidget);
  });

  testWidgets('selects dates from previous and next month grid cells', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-10-1')));
    await _pumpFrames(tester);
    expect(find.text('Thursday, October 1, 2026'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-previous-month')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-8-31')));
    await _pumpFrames(tester);
    expect(find.text('Monday, August 31, 2026'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets('calendar add action prepopulates the selected date', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-30')));
    await _pumpFrames(tester);
    await tester.tap(find.byTooltip('Add reminder for selected date'));
    await _pumpFrames(tester);

    final dateField = find.byKey(const ValueKey('date-field'));
    final expectedDate = MaterialLocalizations.of(tester.element(dateField))
        .formatMediumDate(DateTime(2026, 9, 30));
    expect(
      find.descendant(of: dateField, matching: find.text(expectedDate)),
      findsOneWidget,
    );
  });

  testWidgets('creates, edits, and deletes reminders from the calendar', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-30')));
    await _pumpFrames(tester);
    await tester.tap(find.byTooltip('Add reminder for selected date'));
    await _pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'Created from calendar',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
    await tester.tap(find.byKey(const ValueKey('save-reminder')));
    await _pumpFrames(tester);
    await _pumpFrames(tester);
    expect(storage.reminders, hasLength(3));

    final createdReminder = storage.reminders.singleWhere(
      (reminder) => reminder.title == 'Created from calendar',
    );
    await tester.tap(find.byKey(const ValueKey('calendar-view-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next 3 Days'));
    await tester.pumpAndSettle();
    final createdTitle = find.text('Created from calendar');
    await tester.tap(createdTitle);
    await _pumpFrames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('title-field')),
      'Edited in calendar',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-reminder')));
    await tester.tap(find.byKey(const ValueKey('save-reminder')));
    await _pumpFrames(tester);
    await _pumpFrames(tester);
    expect(
      storage.reminders
          .singleWhere((reminder) => reminder.id == createdReminder.id)
          .title,
      'Edited in calendar',
    );

    await tester.tap(find.byTooltip('More actions for Edited in calendar'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Delete'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Delete').last);
    await _pumpFrames(tester);
    await _pumpFrames(tester);
    expect(
      storage.reminders.any((reminder) => reminder.id == createdReminder.id),
      isFalse,
    );
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  DateTime Function() clock,
  ReminderStorage storage, {
  CalendarViewMode viewMode = CalendarViewMode.monthAndWeek,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CalendarScreen(storage: storage, clock: clock, viewMode: viewMode),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Reminder _reminder({
  required String id,
  required String title,
  required DateTime dateTime,
  RecurrenceType type = RecurrenceType.none,
}) {
  return Reminder(
    id: id,
    title: title,
    dateTime: dateTime,
    recurrenceRule: RecurrenceRule(type: type),
    createdAt: DateTime(2026),
  );
}

class _TestReminderStorage extends ReminderStorage {
  _TestReminderStorage(this.reminders);

  final List<Reminder> reminders;

  @override
  Future<List<Reminder>> getReminders() async => List.of(reminders);

  @override
  Future<void> addReminder(Reminder reminder) async {
    reminders.add(reminder);
  }

  @override
  Future<void> updateReminder(Reminder reminder) async {
    final index = reminders.indexWhere((item) => item.id == reminder.id);
    if (index != -1) {
      reminders[index] = reminder;
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    reminders.removeWhere((reminder) => reminder.id == id);
  }
}
