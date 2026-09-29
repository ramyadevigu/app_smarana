// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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

    await tester.tap(find.text('Reminders').last);
    await tester.pumpAndSettle();

    expect(find.byType(RemindersScreen), findsOneWidget);
  });
}
