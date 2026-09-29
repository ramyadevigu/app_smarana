import 'package:app_smarana/app/app.dart';
import 'package:app_smarana/theme/theme_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('theme selection switches immediately and persists', (
    tester,
  ) async {
    await tester.pumpWidget(const AppSmarana());
    await _openSettings(tester);

    expect(_themeMode(tester), ThemeMode.system);
    expect(
      _activeBrightness(tester),
      tester.binding.platformDispatcher.platformBrightness,
    );

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.light);
    expect(_activeBrightness(tester), Brightness.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.dark);
    expect(_activeBrightness(tester), Brightness.dark);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.system);
    expect(
      (await SharedPreferences.getInstance()).getString('themeMode'),
      'system',
    );
  });

  testWidgets('system mode follows operating system brightness', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpWidget(const AppSmarana());
    await _openSettings(tester);
    expect(_activeBrightness(tester), Brightness.light);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    await tester.pumpAndSettle();
    expect(_themeMode(tester), ThemeMode.system);
    expect(_activeBrightness(tester), Brightness.dark);
  });

  testWidgets('saved theme mode is restored after app recreation', (
    tester,
  ) async {
    await tester.pumpWidget(const AppSmarana());
    await _openSettings(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    final restoredThemeMode = await const ThemePreferenceStore()
        .loadThemeMode();
    await tester.pumpWidget(AppSmarana(initialThemeMode: restoredThemeMode));

    expect(_themeMode(tester), ThemeMode.dark);
    expect(_activeBrightness(tester), Brightness.dark);
  });

  testWidgets('reminders, form, and pickers use light and dark themes', (
    tester,
  ) async {
    await tester.pumpWidget(const AppSmarana());

    for (final (modeLabel, brightness) in [
      ('Light', Brightness.light),
      ('Dark', Brightness.dark),
    ]) {
      await _openSettings(tester);
      await tester.tap(find.text(modeLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();
      expect(_activeBrightness(tester), brightness);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('title-field')), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byKey(const ValueKey('title-field'))))
            .brightness,
        brightness,
      );

      await tester.tap(find.byKey(const ValueKey('date-field')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(DatePickerDialog))).brightness,
        brightness,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('time-field')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(TimePickerDialog))).brightness,
        brightness,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  expect(find.text('Appearance'), findsOneWidget);
}

ThemeMode _themeMode(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ??
      ThemeMode.system;
}

Brightness _activeBrightness(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
}
