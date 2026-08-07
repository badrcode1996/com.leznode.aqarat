import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide theme. Uses the SPEDA font family (declared in pubspec) so the
/// whole UI renders Kurdish/Arabic correctly.
///
/// Both brightnesses are built from the same [_build] so a widget-level tweak
/// can never land in one theme and be forgotten in the other. Everything
/// colour-related comes from an [AppColors] palette, which is also registered
/// as a theme extension for the screens to read via `context.c`.
class AppTheme {
  /// Kept for the few places that still want the raw brand colours outside a
  /// BuildContext (e.g. the web launch background).
  static const Color primaryDarkBlue = Color(0xFF0F2C59);
  static const Color accentYellow = Color(0xFFF8B115);

  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Speda',
      brightness: brightness,
      scaffoldBackgroundColor: c.pageBg,
      extensions: [c],

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primaryDarkBlue,
        brightness: brightness,
        primary: isDark ? c.accent : c.brand,
        onPrimary: isDark ? Colors.black : c.onBrand,
        secondary: c.accent,
        surface: c.card,
        onSurface: c.textBody,
        error: c.danger,
      ),

      // The app bar keeps the brand navy in BOTH themes — it is the strongest
      // brand cue in the product, and a surface-coloured bar in dark mode makes
      // the app unrecognisable.
      appBarTheme: AppBarTheme(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.onBrand),
        titleTextStyle: TextStyle(
          fontFamily: 'Speda',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: c.onBrand,
        ),
      ),

      dividerTheme: DividerThemeData(color: c.divider, space: 1, thickness: 1),

      iconTheme: IconThemeData(color: c.textBody),

      textTheme: Typography.material2021(
        platform: TargetPlatform.android,
      ).black.apply(
            fontFamily: 'Speda',
            bodyColor: c.textBody,
            displayColor: c.textStrong,
          ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        isDense: true,
        labelStyle: TextStyle(color: c.textMuted, fontSize: 14),
        hintStyle: TextStyle(color: c.textFaint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.danger, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
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

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? c.textStrong : c.brand,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: BorderSide(color: isDark ? c.divider : c.brand, width: 1.5),
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

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? c.textStrong : c.brand,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: isDark ? c.textStrong : c.brand,
        textColor: c.textBody,
      ),

      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: isDark ? c.accent : c.brand),

      // The tab bar lives inside the navy app bar in both themes, so its
      // colours are fixed against the brand rather than the page.
      tabBarTheme: TabBarThemeData(
        indicatorColor: c.accent,
        labelColor: c.accent,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
          fontFamily: 'Speda',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
