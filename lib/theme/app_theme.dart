import 'package:flutter/material.dart';

/// App-wide theme. Uses the SPEDA font family (declared in pubspec) so the
/// whole UI renders Kurdish/Arabic correctly.
class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF1565C0),
      fontFamily: 'Speda',
      brightness: Brightness.light,
    );
    return base.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
