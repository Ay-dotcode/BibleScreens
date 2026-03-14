import 'package:flutter/material.dart';

class AppTheme {
  // ── Shared constants ───────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF6B4EFF);
  static const Color _secondary = Color(0xFF03DAC5);

  // ── Dark palette ───────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0A14);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurface2 = Color(0xFF12122A);
  static const Color darkDivider = Color(0xFF2A2A3E);

  // ── Light palette ──────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F4F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFECECF4);
  static const Color lightDivider = Color(0xFFDDDDE8);

  // ── Themes ─────────────────────────────────────────────────────────────────

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      dividerColor: darkDivider,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        secondary: _secondary,
        surface: darkSurface,
      ),
      cardColor: darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Colors.white70,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        indicatorColor: _primary,
        dividerColor: darkDivider,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary),
        ),
        hintStyle: const TextStyle(color: Colors.white30),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        bodySmall: TextStyle(color: Colors.white54),
      ),
      iconTheme: const IconThemeData(color: Colors.white60),
      chipTheme: const ChipThemeData(
        backgroundColor: darkSurface,
        side: BorderSide(color: darkDivider),
        labelStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      dividerColor: lightDivider,
      colorScheme: const ColorScheme.light(
        primary: _primary,
        secondary: _secondary,
        surface: lightSurface,
      ),
      cardColor: lightSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: Color(0xFF333344),
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: _primary,
        unselectedLabelColor: Colors.black38,
        indicatorColor: _primary,
        dividerColor: lightDivider,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary),
        ),
        hintStyle: const TextStyle(color: Colors.black38),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFF333344)),
        bodySmall: TextStyle(color: Color(0xFF666677)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF555566)),
      chipTheme: const ChipThemeData(
        backgroundColor: lightSurface2,
        side: BorderSide(color: lightDivider),
        labelStyle: TextStyle(color: Color(0xFF333344)),
      ),
    );
  }
}
