import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color deepBlack = Color(0xFF0B0F14);
  static const Color white = Color(0xFFFFFFFF);

  static const Color lightBackground = Color(0xFFF4F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFF8FAFD);
  static const Color lightOutline = Color(0xFF748294);
  static const Color lightOutlineVariant = Color(0xFFD5DEE8);

  static const Color darkSurface = Color(0xFF121A24);
  static const Color darkSurfaceLow = Color(0xFF182330);
  static const Color darkSurfaceHigh = Color(0xFF202D3A);
  static const Color darkOnSurface = Color(0xFFEAF1F8);
  static const Color darkOnSurfaceVariant = Color(0xFFB4C2D0);
  static const Color darkOutline = Color(0xFF8291A0);
  static const Color darkOutlineVariant = Color(0xFF344352);

  static Color highContrastForeground(Color background) {
    final luminance = background.computeLuminance();
    final blackContrast = (luminance + 0.05) / 0.05;
    final whiteContrast = 1.05 / (luminance + 0.05);
    return blackContrast >= whiteContrast ? Colors.black : Colors.white;
  }
}
