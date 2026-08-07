import 'package:flutter/material.dart';

/// The languages the interface is offered in.
///
/// Kurdish is the product's first language and stays the fallback: a string not
/// yet translated shows in Kurdish rather than as a blank or a key.
///
/// [direction] is carried here rather than derived, because the app previously
/// forced RTL globally — English needs the layout to mirror back.
enum AppLanguage {
  ku('ku', 'کوردی', TextDirection.rtl),
  ar('ar', 'العربية', TextDirection.rtl),
  en('en', 'English', TextDirection.ltr);

  const AppLanguage(this.wire, this.label, this.direction);

  /// Stable key for storage — never derive it from the enum index.
  final String wire;

  /// Shown in the picker, always in the language itself.
  final String label;

  final TextDirection direction;

  bool get isRtl => direction == TextDirection.rtl;

  /// The UI typeface for this language, or null to let the platform choose.
  ///
  /// SPEDA is a Kurdish face. It sets Kurdish beautifully, but it is not an
  /// Arabic font: several Arabic letters fail to join, which is exactly why the
  /// PDF renderer already switches to Amiri for Arabic documents. Its Latin is
  /// an afterthought too.
  ///
  /// Arabic and English therefore fall back to the platform's own UI font —
  /// Segoe UI on Windows, SF on Apple, Noto on Android — each of which shapes
  /// its script correctly. That beats bundling a second webfont for every
  /// visitor who will never switch language.
  String? get fontFamily => this == AppLanguage.ku ? 'Speda' : null;

  /// The locale handed to Flutter's own widget localizations. Central Kurdish
  /// has no bundled delegate, so it borrows Arabic — also RTL, and the only
  /// thing it drives is built-in labels like the date picker's buttons.
  Locale get materialLocale => switch (this) {
        AppLanguage.en => const Locale('en'),
        _ => const Locale('ar'),
      };

  static AppLanguage fromWire(String? value) => AppLanguage.values.firstWhere(
        (l) => l.wire == value,
        orElse: () => AppLanguage.ku,
      );
}
