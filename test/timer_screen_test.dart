import 'package:app_smarana/features/time_tools/timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('saves reusable timer cards and restores them', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_timerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('timer-add')));
    await tester.pumpAndSettle();

    expect(find.text('30 sec'), findsOneWidget);
    expect(find.text('1m'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('10m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('timer-preset-30')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timer-preset-30')));
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('timer-save')));
    await tester.tap(find.byKey(const ValueKey('timer-save')));
    await tester.pumpAndSettle();

    expect(find.text('30s timer'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Start 30s timer'));
    await tester.pump();
    expect(find.byTooltip('Pause 30s timer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_timerApp());
    await tester.pumpAndSettle();

    expect(find.text('30s timer'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
  });
}

Widget _timerApp() {
  return MaterialApp(home: TimerScreen(appMenu: const SizedBox.shrink()));
}
