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
  final onPrimary = AppColors.highContrastForeground(primary);
  final background = isLight
      ? Color.lerp(AppColors.lightBackground, primary, 0.025)!
      : AppColors.deepBlack;
  final surface = isLight
      ? Color.lerp(AppColors.lightSurface, primary, 0.012)!
      : AppColors.darkSurface;
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
        surface: surface,
        onSurface: isLight ? AppColors.deepBlack : AppColors.darkOnSurface,
        surfaceContainerLowest: background,
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
    dividerTheme: DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 1,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: isLight ? AppColors.deepBlack : AppColors.darkOnSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: isLight ? AppColors.lightSurface : AppColors.darkSurfaceLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isLight ? AppColors.lightSurface : AppColors.darkSurface,
      elevation: 0,
      height: 72,
      indicatorColor: primary,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.lightSurface : AppColors.darkSurfaceLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isLight ? AppColors.deepBlack : AppColors.darkSurfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primary.withValues(alpha: 0.24),
      selectionHandleColor: primary,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
    ),
  );
}
