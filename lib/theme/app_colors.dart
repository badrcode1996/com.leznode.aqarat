import 'package:flutter/material.dart';

/// Semantic colour tokens, resolved per brightness.
///
/// Every screen used to hold its own `const Color primaryDarkBlue = …` plus a
/// scattering of `Colors.white` / `Colors.grey.shade600`, which is exactly what
/// made a dark theme impossible: a hardcoded white card stays white however the
/// [ThemeData] is configured.
///
/// Tokens are named for their ROLE, not their colour, so the dark palette can
/// invert them without any screen knowing. Reach them through
/// `context.c.<token>` — see [AppColorsX].
///
/// Note [brand] and [textStrong] are separate on purpose: in light mode a
/// heading and an app bar are both the navy, but in dark mode the app bar stays
/// navy while heading text has to go light or it disappears.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.onBrand,
    required this.accent,
    required this.onAccent,
    required this.pageBg,
    required this.card,
    required this.paper,
    required this.inputFill,
    required this.textStrong,
    required this.textBody,
    required this.textMuted,
    required this.textFaint,
    required this.divider,
    required this.success,
    required this.danger,
    required this.warning,
    required this.info,
    required this.violet,
    required this.shadow,
  });

  /// App bars, primary buttons, selected states.
  final Color brand;

  /// Text and icons drawn ON [brand].
  final Color onBrand;

  /// The yellow used for the FAB, tab indicators and highlights.
  final Color accent;

  /// Text and icons drawn ON a solid [accent] fill. Navy in BOTH themes — the
  /// yellow does not darken in dark mode, so anything on it would vanish if it
  /// followed [textStrong].
  final Color onAccent;

  /// Scaffold background.
  final Color pageBg;

  /// Card / sheet / dialog surface.
  final Color card;

  /// The sheet a rendered document sits on. WHITE in both themes — it stands
  /// for a printed A4 page, and paper does not turn dark because the phone did.
  ///
  /// It matters more than it looks: rasterising a PDF leaves the areas the
  /// document never painted TRANSPARENT, so whatever is behind shows through.
  /// Backing a page with [card] made contracts and receipts come out navy in
  /// dark mode.
  final Color paper;

  /// Form field fill, and the neutral chip background.
  final Color inputFill;

  /// Headings and emphasised values.
  final Color textStrong;

  /// Ordinary body text.
  final Color textBody;

  /// Labels, subtitles, secondary metadata.
  final Color textMuted;

  /// Timestamps, disabled text, empty-state icons.
  final Color textFaint;

  /// Dividers and hairline borders.
  final Color divider;

  // Status accents. Kept as tokens rather than literals so the dark palette can
  // brighten them — the light-mode greens and reds are too dark on a near-black
  // background to hit contrast.
  final Color success;
  final Color danger;
  final Color warning;
  final Color info;
  final Color violet;

  /// Card drop shadow — barely-there in light, much stronger in dark where the
  /// surfaces are closer together in luminance.
  final Color shadow;

  /// The palette matching the theme currently on screen.
  ///
  /// Every screen used to declare `const Color primaryDarkBlue = …` at the top
  /// of its own file, and those constants are referenced ~600 times. Rather
  /// than rewrite every call site, each file now declares
  /// `Color get primaryDarkBlue => AppColors.current.brand;` — one line changed
  /// per file, and the references keep working while becoming theme-aware.
  ///
  /// It is a plain static because those getters have no BuildContext to reach
  /// through. [MaterialApp.builder] refreshes it before any descendant builds,
  /// and a theme change rebuilds the entire app below that point, so it is
  /// always the brightness actually being painted.
  static AppColors current = light;

  static const light = AppColors(
    brand: Color(0xFF0F2C59),
    onBrand: Colors.white,
    accent: Color(0xFFF8B115),
    onAccent: Color(0xFF0F2C59),
    pageBg: Color(0xFFF5F7FA),
    card: Colors.white,
    paper: Colors.white,
    inputFill: Color(0xFFF3F4F6),
    textStrong: Color(0xFF0F2C59),
    textBody: Color(0xFF374151),
    textMuted: Color(0xFF6B7280),
    textFaint: Color(0xFF9CA3AF),
    divider: Color(0xFFE5E7EB),
    success: Color(0xFF10B981),
    danger: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF0EA5E9),
    violet: Color(0xFF8B5CF6),
    shadow: Color(0x0A000000),
  );

  static const dark = AppColors(
    // The navy survives into dark mode — it is the brand — but lifted a little
    // so the app bar still separates from the near-black page behind it.
    brand: Color(0xFF16305C),
    onBrand: Colors.white,
    accent: Color(0xFFF8B115),
    onAccent: Color(0xFF0F2C59),
    pageBg: Color(0xFF0D1117),
    card: Color(0xFF161B22),
    // White even here — see the field doc.
    paper: Colors.white,
    inputFill: Color(0xFF21262D),
    textStrong: Color(0xFFE6EDF3),
    textBody: Color(0xFFC9D1D9),
    textMuted: Color(0xFF8B949E),
    textFaint: Color(0xFF6E7681),
    divider: Color(0xFF30363D),
    success: Color(0xFF3FB950),
    danger: Color(0xFFF85149),
    warning: Color(0xFFD29922),
    info: Color(0xFF58A6FF),
    violet: Color(0xFFA371F7),
    shadow: Color(0x59000000),
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? accent,
    Color? onAccent,
    Color? pageBg,
    Color? card,
    Color? paper,
    Color? inputFill,
    Color? textStrong,
    Color? textBody,
    Color? textMuted,
    Color? textFaint,
    Color? divider,
    Color? success,
    Color? danger,
    Color? warning,
    Color? info,
    Color? violet,
    Color? shadow,
  }) =>
      AppColors(
        brand: brand ?? this.brand,
        onBrand: onBrand ?? this.onBrand,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        pageBg: pageBg ?? this.pageBg,
        card: card ?? this.card,
        paper: paper ?? this.paper,
        inputFill: inputFill ?? this.inputFill,
        textStrong: textStrong ?? this.textStrong,
        textBody: textBody ?? this.textBody,
        textMuted: textMuted ?? this.textMuted,
        textFaint: textFaint ?? this.textFaint,
        divider: divider ?? this.divider,
        success: success ?? this.success,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        violet: violet ?? this.violet,
        shadow: shadow ?? this.shadow,
      );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      card: Color.lerp(card, other.card, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// `context.c.card` instead of
/// `Theme.of(context).extension<AppColors>()!.card`.
///
/// The bang is safe: both themes in [AppTheme] register the extension, and a
/// widget that renders outside them would be broken for many other reasons too.
extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

/// Marks the app-wide state that the static accessors read.
///
/// Holds nothing but a [revision], bumped whenever the brightness OR the
/// interface language changes. Screens depend on it through [watchAppShell];
/// it lives here, rather than alongside the language, only so that
/// `theme/app_colors.dart` stays the single import a screen needs.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.revision,
    required super.child,
  });

  final int revision;

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      oldWidget.revision != revision;
}

/// Call this at the top of any `build` that reads [AppColors.current] or the
/// string catalogue.
///
/// Both are statics, so they can be reached from enum members and model getters
/// that have no BuildContext. The price is that Flutter cannot SEE those
/// dependencies: a widget reading a static never registers with anything, so
/// changing brightness or language leaves it rendering the old values until
/// something unrelated happens to rebuild it.
///
/// That is why dark mode first landed as a patchwork — only freshly-pushed
/// routes came out dark, and the tab screens (held in a `const` list, so never
/// rebuilt) stayed light. Registering the Theme fixed brightness but NOT
/// language: Kurdish and Arabic are both RTL, so switching between them changed
/// nothing Flutter tracks and every screen stayed Kurdish. Hence the scope.
///
/// It reads nothing. The values still come from the statics, which are
/// refreshed before any of this builds.
void watchAppShell(BuildContext context) {
  Theme.of(context);
  context.dependOnInheritedWidgetOfExactType<AppShellScope>();
}
