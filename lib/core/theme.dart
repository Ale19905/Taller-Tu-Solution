import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF226A62);
  static const lightBackground = Color(0xFFF5F7F6);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        surface: const Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: lightBackground,
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarThemeData(
        backgroundColor: lightBackground,
        foregroundColor: Color(0xFF183A35),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE4EBE8)),
        ),
      ),
    );
  }
}
