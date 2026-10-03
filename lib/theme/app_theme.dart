import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';

enum SmaranaColorTheme {
  blue('Blue', 0xFF4773FA),
  cyan('Cyan', 0xFF93DCED),
  mint('Mint', 0xFF9CE3D3),
  lightGreen('Light Green', 0xFFCAE0B9),
  peach('Peach / Amber', 0xFFFBD6A1),
  pink('Pink', 0xFFF7BED1),
  lavender('Lavender', 0xFFD0C6FA);

  const SmaranaColorTheme(this.label, this.value);

  final String label;
  final int value;

  Color get color => Color(value);
}

ThemeData buildLightTheme(SmaranaColorTheme colorTheme) =>
    _buildTheme(colorTheme, brightness: Brightness.light);

ThemeData buildDarkTheme(SmaranaColorTheme colorTheme) =>
    _buildTheme(colorTheme, brightness: Brightness.dark);

final ThemeData lightTheme = buildLightTheme(SmaranaColorTheme.blue);
final ThemeData darkTheme = buildDarkTheme(SmaranaColorTheme.blue);

ThemeData _buildTheme(
  SmaranaColorTheme colorTheme, {
  required Brightness brightness,
}) {
  final isLight = brightness == Brightness.light;
  final primary = colorTheme.color;
  final onPrimary = primary.computeLuminance() > 0.45
      ? AppColors.deepBlack
      : AppColors.white;
  final surface = isLight ? AppColors.lightSurface : AppColors.darkSurface;
  final outline = isLight ? AppColors.lightOutline : AppColors.darkOutline;
  final outlineVariant = isLight
      ? AppColors.lightOutlineVariant
      : AppColors.darkOutlineVariant;
  final focusColor = isLight
      ? primary
      : Color.lerp(primary, AppColors.white, 0.18)!;
  final colorScheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: primary,
        onSecondary: onPrimary,
        tertiary: primary,
        onTertiary: onPrimary,
        surface: surface,
        onSurface: isLight ? AppColors.deepBlack : AppColors.darkOnSurface,
        surfaceContainerLowest: isLight
            ? AppColors.lightBackground
            : AppColors.deepBlack,
        surfaceContainerLow: isLight
            ? AppColors.lightSurfaceLow
            : AppColors.darkSurfaceLow,
        surfaceContainer: surface,
        surfaceContainerHigh: isLight
            ? AppColors.lightSurface
            : AppColors.darkSurfaceHigh,
        surfaceContainerHighest: isLight
            ? AppColors.lightSurface
            : AppColors.darkSurfaceHigh,
        onSurfaceVariant: isLight ? null : AppColors.darkOnSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: isLight
        ? AppColors.lightBackground
        : AppColors.deepBlack,
    appBarTheme: AppBarTheme(
      backgroundColor: isLight
          ? AppColors.lightBackground
          : AppColors.deepBlack,
      foregroundColor: isLight ? AppColors.deepBlack : AppColors.darkOnSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: isLight ? AppColors.lightSurface : AppColors.darkSurfaceLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.lightSurface : AppColors.darkSurfaceLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
    ),
  );
}
