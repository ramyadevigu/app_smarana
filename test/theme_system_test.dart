import 'package:app_smarana/app/app.dart';
import 'package:app_smarana/theme/app_theme.dart';
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

  testWidgets('custom accent color updates and persists', (tester) async {
    await tester.pumpWidget(const AppSmarana());
    await _openSettings(tester);

    final picker = find.byKey(const ValueKey('settings-accent-color-picker'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('Choose accent color'), findsOneWidget);
    final hueSlider = find.byKey(const ValueKey('accent-hue-slider'));
    expect(hueSlider, findsOneWidget);
    await tester.drag(hueSlider, const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();

    final appTheme = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final selectedAccent = appTheme.theme!.colorScheme.primary;
    expect(selectedAccent, isNot(defaultAccentColor));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('colorTheme'), startsWith('#'));

    await tester.pumpWidget(const SizedBox.shrink());
    final restoredAccent = await const ThemePreferenceStore().loadAccentColor();
    expect(restoredAccent, selectedAccent);
    await tester.pumpWidget(AppSmarana(initialAccentColor: restoredAccent));
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      selectedAccent,
    );
  });

  test('custom accent colors have readable primary foregrounds', () {
    for (var hue = 0; hue <= 360; hue += 15) {
      final accentColor = HSLColor.fromAHSL(
        1,
        hue.toDouble(),
        0.8,
        0.5,
      ).toColor();
      for (final theme in [
        buildLightTheme(accentColor),
        buildDarkTheme(accentColor),
      ]) {
        final primary = theme.colorScheme.primary;
        final foreground = theme.colorScheme.onPrimary;
        final luminance = primary.computeLuminance();
        final foregroundLuminance = foreground.computeLuminance();
        final lighter = luminance > foregroundLuminance
            ? luminance
            : foregroundLuminance;
        final darker = luminance > foregroundLuminance
            ? foregroundLuminance
            : luminance;

        expect(
          (lighter + 0.05) / (darker + 0.05),
          greaterThanOrEqualTo(4.5),
          reason: '$accentColor ${theme.brightness} primary contrast',
        );
      }
    }
  });

  test('previously selected named colors remain supported', () async {
    SharedPreferences.setMockInitialValues({'colorTheme': 'lavender'});

    expect(
      await const ThemePreferenceStore().loadAccentColor(),
      const Color(0xFFD0C6FA),
    );
  });

  testWidgets('accent color picker works on a compact screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const AppSmarana());
    await _openSettings(tester);
    final picker = find.byKey(const ValueKey('settings-accent-color-picker'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();

    expect(find.text('Choose accent color'), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-hue-slider')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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

      await tester.pageBack();
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const ValueKey('nav-alarms')));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
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
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  });
}

Future<void> _openSettings(WidgetTester tester) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.byKey(const ValueKey('app-overflow-menu')));
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text('Settings'));
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('Appearance'), findsOneWidget);
}

ThemeMode _themeMode(WidgetTester tester) {
  return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode ??
      ThemeMode.system;
}

Brightness _activeBrightness(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
}
