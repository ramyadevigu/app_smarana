import 'package:app_smarana/features/calender/calender_screen.dart';
import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:app_smarana/theme/app_colors.dart';
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

  testWidgets('scrolls through the full day without changing its date', (
    tester,
  ) async {
    final lateEvening = DateTime(2026, 9, 29, 20, 5);
    await _pumpCalendar(tester, () => lateEvening, storage);

    const agendaKey = ValueKey('calendar-agenda-scroll');
    final agendaFinder = find.byKey(agendaKey);
    final agenda = tester.widget<SingleChildScrollView>(agendaFinder);
    expect(agenda.scrollDirection, Axis.vertical);
    expect(_nowLabel(tester), '8:05 PM');
    expect(find.byKey(const ValueKey('calendar-hour-20')), findsOneWidget);
    expect(find.text('12:00 AM'), findsOneWidget);
    expect(find.text('11:00 PM'), findsOneWidget);
    _expectNowAtTime(tester, lateEvening);
    final indicatorRect = tester.getRect(
      find.byKey(const ValueKey('calendar-now-indicator')),
    );
    final agendaRect = tester.getRect(agendaFinder);
    expect(
      (indicatorRect.center.dy - (agendaRect.top + agendaRect.height * 0.3))
          .abs(),
      lessThan(2),
    );

    await tester.drag(agendaFinder, const Offset(0, 2400));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
    expect(agenda.controller!.offset, 0);

    await tester.drag(agendaFinder, const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
    expect(
      agenda.controller!.offset,
      agenda.controller!.position.maxScrollExtent,
    );
  });

  testWidgets('shows the requested empty-day message', (tester) async {
    await _pumpCalendar(tester, () => now, _TestReminderStorage([]));

    expect(find.text('No Reminders today'), findsOneWidget);
  });

  testWidgets('positions reminders at their exact time in the day timeline', (
    tester,
  ) async {
    final eventStorage = _TestReminderStorage([
      _reminder(
        id: 'half-hour',
        title: 'Half-hour reminder',
        dateTime: DateTime(2026, 9, 29, 15, 30),
      ),
    ]);
    await _pumpCalendar(tester, () => now, eventStorage);

    final agenda = tester.getRect(
      find.byKey(const ValueKey('calendar-agenda-scroll')),
    );
    final reminder = tester.getRect(
      find.byKey(const ValueKey('calendar-reminder-half-hour')),
    );
    expect(reminder.top, closeTo(agenda.top + 15.5 * 88, 1));
  });

  testWidgets('navigates between months and returns to today', (tester) async {
    await _pumpCalendar(tester, () => now, storage);

    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await _pumpFrames(tester);
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await _pumpFrames(tester);
    expect(find.text('September 2026'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await _pumpFrames(tester);
    expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-now-time')), findsOneWidget);
    _expectNowAtTime(tester, now);
  });

  testWidgets('navigates between years while preserving month and day', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byTooltip('Next year'));
    await _pumpFrames(tester);
    expect(find.text('September 2027'), findsOneWidget);
    expect(find.text('Wednesday, September 29, 2027'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous year'));
    await _pumpFrames(tester);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Tuesday, September 29, 2026'), findsOneWidget);
  });

  testWidgets('month heading opens date picker with year selection', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byKey(const ValueKey('calendar-select-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await _pumpFrames(tester);

    expect(find.text('September 2027'), findsOneWidget);
    expect(find.text('Wednesday, September 29, 2027'), findsOneWidget);
  });

  testWidgets('selecting an adjacent date updates its agenda', (tester) async {
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

    await tester.tap(find.byTooltip('Previous month'));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-8-31')));
    await _pumpFrames(tester);
    expect(find.text('Monday, August 31, 2026'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
  });

  testWidgets('day controls synchronize the calendar across month boundaries', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);

    await tester.tap(find.byKey(const ValueKey('calendar-next-day')));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday, September 30, 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('calendar-day-2026-9-30')),
          )
          .properties
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-next-day')));
    await tester.pumpAndSettle();
    expect(find.text('Thursday, October 1, 2026'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-next-day')));
    await tester.pumpAndSettle();
    expect(find.text('Friday, October 2, 2026'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('calendar-day-2026-10-2')),
          )
          .properties
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-previous-day')));
    await tester.pumpAndSettle();
    expect(find.text('Thursday, October 1, 2026'), findsOneWidget);
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
    await tester.dragUntilVisible(
      find.text('Created from calendar'),
      find.byKey(const ValueKey('calendar-agenda-scroll')),
      const Offset(0, -120),
    );
    await _pumpFrames(tester);
    await tester.tap(find.text('Created from calendar'));
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

    await tester.dragUntilVisible(
      find.text('Edited in calendar'),
      find.byKey(const ValueKey('calendar-agenda-scroll')),
      const Offset(0, -120),
    );
    await _pumpFrames(tester);
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

  testWidgets('NOW follows the clock and is absent on another date', (
    tester,
  ) async {
    await _pumpCalendar(tester, () => now, storage);
    expect(find.byKey(const ValueKey('calendar-now-time')), findsOneWidget);
    expect(_nowLabel(tester), '12:05 AM');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('calendar-now-time')))
          .style
          ?.color,
      AppColors.white,
    );
    final nowLabelContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('calendar-now-time')),
            matching: find.byType(Container),
          )
          .first,
    );
    final nowLabelDecoration = nowLabelContainer.decoration! as BoxDecoration;
    expect(nowLabelDecoration.color, AppColors.azureBlue);
    expect(nowLabelDecoration.borderRadius, BorderRadius.circular(8));
    _expectNowAtTime(tester, now);

    now = DateTime(2026, 9, 29, 0, 6);
    await tester.pump(const Duration(minutes: 1));
    expect(_nowLabel(tester), '12:06 AM');
    _expectNowAtTime(tester, now);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-30')));
    await _pumpFrames(tester);
    expect(find.byKey(const ValueKey('calendar-now-time')), findsNothing);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  DateTime Function() clock,
  ReminderStorage storage,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CalendarScreen(storage: storage, clock: clock),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

String? _nowLabel(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey('calendar-now-time')))
      .data;
}

void _expectNowAtTime(WidgetTester tester, DateTime time) {
  final indicator = tester.getRect(
    find.byKey(const ValueKey('calendar-now-indicator')),
  );
  final agendaWidget = tester.widget<SingleChildScrollView>(
    find.byKey(const ValueKey('calendar-agenda-scroll')),
  );
  final agenda = tester.getRect(
    find.byKey(const ValueKey('calendar-agenda-scroll')),
  );
  final expectedOffset =
      (time.hour * 60 + time.minute) / 60 * 88 -
      agendaWidget.controller!.offset;
  expect(
    (indicator.center.dy - (agenda.top + expectedOffset)).abs(),
    lessThan(2),
  );
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
