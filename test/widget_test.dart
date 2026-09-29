// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_smarana/app/app.dart';
import 'package:app_smarana/features/calender/calender_screen.dart';
import 'package:app_smarana/features/notes/notes_screen.dart';
import 'package:app_smarana/features/reminders/reminders_screen.dart';
import 'package:app_smarana/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts on the calendar screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AppSmarana());

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byType(RemindersScreen), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();
    expect(destinations, [
      'Calendar',
      'Notes',
      'Alarms',
      'Stop Watch',
      'Timer',
    ]);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.indicatorColor, AppColors.azureBlue);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.calendar_month)).color,
      AppColors.white,
    );
    for (final key in [
      'nav-calendar',
      'nav-notes',
      'nav-alarms',
      'nav-stopwatch',
      'nav-timer',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.text('World Clock'), findsNothing);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Send Feedback'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.byIcon(Icons.feedback_outlined), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-notes')));
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.text('World Clock'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-alarms')));
    await tester.pumpAndSettle();

    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.text('Alarms'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('nav-stopwatch')));
    await tester.pumpAndSettle();
    expect(find.text('Stop Watch'), findsNWidgets(3));
    expect(find.text('Coming soon'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-timer')));
    await tester.pumpAndSettle();
    expect(find.text('Timer'), findsNWidgets(3));
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
