import 'package:flutter/material.dart';

class AppTheme {
  static const Color appBackground = Color(0xFF0A0A14);
  static const Color appSurface = Color(0xFF1A1A2E);
  static const Color appPrimary = Color(0xFF6B4EFF);
  static const Color appSecondary = Color(0xFF03DAC5);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: appBackground,
      colorScheme: const ColorScheme.dark(
        primary: appPrimary,
        secondary: appSecondary,
        surface: appSurface,
      ),
    );
  }
}
