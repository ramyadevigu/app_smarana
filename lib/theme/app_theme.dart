import 'package:flutter/material.dart';

import 'app_colors.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: AppColors.royalBlue,
    onPrimary: AppColors.white,
    secondary: AppColors.azureBlue,
    onSecondary: AppColors.deepBlack,
    tertiary: AppColors.cyanBlue,
    onTertiary: AppColors.deepBlack,
    surface: AppColors.lightSurface,
    onSurface: AppColors.deepBlack,
    surfaceContainerLowest: AppColors.lightBackground,
    surfaceContainerLow: AppColors.lightSurfaceLow,
    surfaceContainer: AppColors.lightSurface,
    surfaceContainerHigh: AppColors.lightSurface,
    surfaceContainerHighest: AppColors.lightSurface,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
  ),
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBackground,
    foregroundColor: AppColors.deepBlack,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.lightOutlineVariant),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.lightOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.lightOutline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.5),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.royalBlue,
    foregroundColor: AppColors.white,
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.royalBlue,
    onPrimary: AppColors.white,
    secondary: AppColors.azureBlue,
    onSecondary: AppColors.deepBlack,
    tertiary: AppColors.cyanBlue,
    onTertiary: AppColors.deepBlack,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceContainerLowest: AppColors.deepBlack,
    surfaceContainerLow: AppColors.darkSurfaceLow,
    surfaceContainer: AppColors.darkSurface,
    surfaceContainerHigh: AppColors.darkSurfaceHigh,
    surfaceContainerHighest: AppColors.darkSurfaceHigh,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVariant,
  ),
  scaffoldBackgroundColor: AppColors.deepBlack,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.deepBlack,
    foregroundColor: AppColors.darkOnSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkSurfaceLow,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.darkOutlineVariant),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurfaceLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.darkOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.darkOutline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.cyanBlue, width: 1.5),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.royalBlue,
    foregroundColor: AppColors.white,
  ),
);
