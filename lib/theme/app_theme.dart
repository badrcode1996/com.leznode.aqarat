import 'package:flutter/material.dart';

/// App-wide theme. Uses the SPEDA font family (declared in pubspec) so the
/// whole UI renders Kurdish/Arabic correctly.
/// Updated with Modern UI/UX Design System.
class AppTheme {
  // ڕەنگە بنەڕەتییەکانی دیزاینە نوێیەکەمان
  static const Color primaryDarkBlue = Color(0xFF0F2C59);
  static const Color accentYellow = Color(0xFFF8B115);
  static const Color appBackgroundColor = Color(0xFFF5F7FA);
  static const Color inputFillColor = Color(0xFFF3F4F6);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Speda',
      brightness: Brightness.light,
      scaffoldBackgroundColor: appBackgroundColor,

      // ڕێکخستنی ڕەنگە سەرەکییەکان
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDarkBlue,
        primary: primaryDarkBlue,
        secondary: accentYellow,
        surface: appBackgroundColor,
      ),

      // دیزاینی سەرەوەی شاشەکان (AppBar) بەشێوەی گشتی
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Speda', // بۆ ئەوەی فۆنتەکە وەرگرێت
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // دیزاینی فۆڕم و بۆشاییەکان (TextFields) بەشێوەی گشتی
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        isDense: true,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentYellow, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
      ),

      // دیزاینی دوگمە پڕەکان (ElevatedButton) بەشێوەی گشتی
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Speda',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // دیزاینی دوگمە هێڵدارەکان (OutlinedButton)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDarkBlue,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: const BorderSide(color: primaryDarkBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Speda',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // دیزاینی کارتەکان (Cards)
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // دیزاینی خشتەی ڕێکخستنی تابەکان (TabBar) — چاککراوە بۆ وەشانی نوێی فلاتەر
      tabBarTheme: const TabBarThemeData(
        indicatorColor: accentYellow,
        labelColor: accentYellow,
        unselectedLabelColor: Colors.white70,
        labelStyle: TextStyle(
          fontFamily: 'Speda',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}