import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color deepBlack = Color(0xFF0B0F14);
  static const Color royalBlue = Color(0xFF0066FF);
  static const Color azureBlue = Color(0xFF008CFF);
  static const Color cyanBlue = Color(0xFF00AEEF);
  static const Color white = Color(0xFFFFFFFF);

  static const Color lightBackground = Color(0xFFF4F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFF8FAFD);
  static const Color lightOutline = Color(0xFF8795A5);
  static const Color lightOutlineVariant = Color(0xFFD8E0E9);

  static const Color darkSurface = Color(0xFF121A24);
  static const Color darkSurfaceLow = Color(0xFF182330);
  static const Color darkSurfaceHigh = Color(0xFF202D3A);
  static const Color darkOnSurface = Color(0xFFEAF1F8);
  static const Color darkOnSurfaceVariant = Color(0xFFB4C2D0);
  static const Color darkOutline = Color(0xFF8291A0);
  static const Color darkOutlineVariant = Color(0xFF344352);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF0038B8), royalBlue, cyanBlue],
  );
}
