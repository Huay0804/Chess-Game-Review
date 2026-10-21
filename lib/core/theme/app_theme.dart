import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const background = Color(0xFF101820);
  static const surface = Color(0xFF1B2732);
  static const accent = Color(0xFFECC477);
  static const muted = Color(0xFF9BAAB8);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
      primary: accent,
    ),
    fontFamily: 'Segoe UI',
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
