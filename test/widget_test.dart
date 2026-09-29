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
import 'package:app_smarana/features/reminders/reminders_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts on the calendar screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AppSmarana());

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byType(RemindersScreen), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final key in [
      'nav-calendar',
      'nav-alarms',
      'nav-stopwatch',
      'nav-timer',
      'nav-world-clock',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }

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

    await tester.tap(find.text('Alarms'));
    await tester.pumpAndSettle();

    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(find.text('Alarms'), findsNWidgets(2));
  });
}
