import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color deepBlack = Color(0xFF101722);
  static const Color white = Color(0xFFFFFFFF);

  static const Color lightBackground = Color(0xFFF3F6FB);
  static const Color lightSurface = Color(0xFFFCFDFF);
  static const Color lightSurfaceLow = Color(0xFFF8FAFE);
  static const Color lightOutline = Color(0xFF748294);
  static const Color lightOutlineVariant = Color(0xFFD8E0EC);

  static const Color darkSurface = Color(0xFF151D28);
  static const Color darkSurfaceLow = Color(0xFF1A2430);
  static const Color darkSurfaceHigh = Color(0xFF222E3B);
  static const Color darkOnSurface = Color(0xFFE9EFF7);
  static const Color darkOnSurfaceVariant = Color(0xFFB3C0D0);
  static const Color darkOutline = Color(0xFF8190A1);
  static const Color darkOutlineVariant = Color(0xFF354353);

  static Color highContrastForeground(Color background) {
    final luminance = background.computeLuminance();
    final blackContrast = (luminance + 0.05) / 0.05;
    final whiteContrast = 1.05 / (luminance + 0.05);
    return blackContrast >= whiteContrast ? Colors.black : Colors.white;
  }
}
