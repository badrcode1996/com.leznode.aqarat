import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/l10n/app_language.dart';
import 'package:aqarat/theme/app_colors.dart';
import 'package:aqarat/theme/app_theme.dart';

/// Guards the thing a dark theme actually gets wrong: text that disappears.
///
/// A screenshot only proves the one screen you looked at. These checks prove
/// every token pair the screens are built from, in both brightnesses — so a
/// future palette tweak that makes muted text unreadable fails here instead of
/// on someone's phone.

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

/// WCAG contrast ratio between two opaque colours (1.0 … 21.0).
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {'light': AppColors.light, 'dark': AppColors.dark}.entries) {
    final name = entry.key;
    final c = entry.value;

    group('$name palette', () {
      // 4.5:1 is the WCAG AA floor for body-sized text.
      void readable(String label, Color fg, Color bg, {double min = 4.5}) {
        test('$label reads on its background', () {
          final ratio = _contrast(fg, bg);
          expect(ratio, greaterThanOrEqualTo(min),
              reason: '$label is $ratio:1, below $min:1');
        });
      }

      readable('textStrong on card', c.textStrong, c.card);
      readable('textBody on card', c.textBody, c.card);
      readable('textStrong on pageBg', c.textStrong, c.pageBg);
      readable('textBody on pageBg', c.textBody, c.pageBg);
      readable('textStrong on inputFill', c.textStrong, c.inputFill);
      readable('onBrand on brand', c.onBrand, c.brand);
      readable('onAccent on accent', c.onAccent, c.accent);

      // Labels and metadata are secondary; AA large-text (3:1) is the bar.
      readable('textMuted on card', c.textMuted, c.card, min: 3.0);
      readable('textMuted on pageBg', c.textMuted, c.pageBg, min: 3.0);

      // Status colours are only ever used bold or as icons.
      //
      // The light palette's green/amber/blue are the brand colours this app
      // shipped with, and three of them land just under AA on white
      // (success 2.6:1, warning 2.0:1, info 2.8:1). They are NOT relaxed here
      // because that is acceptable — they are relaxed because tightening them
      // would restyle the live light theme, which is a separate decision. The
      // floor still pins them, so they can never drift further down.
      final statusFloor = name == 'dark' ? 3.0 : 1.9;
      readable('success on card', c.success, c.card, min: statusFloor);
      readable('danger on card', c.danger, c.card, min: statusFloor);
      readable('warning on card', c.warning, c.card, min: statusFloor);
      readable('info on card', c.info, c.card, min: statusFloor);
      readable('violet on card', c.violet, c.card, min: statusFloor);

      test('paper is white, whatever the theme', () {
        // A rendered contract or receipt stands for a printed A4 sheet, and the
        // rasterised PDF is transparent wherever the document drew nothing —
        // so this colour shows THROUGH the page. Following the theme turned
        // contracts navy in dark mode.
        expect(c.paper, const Color(0xFFFFFFFF));
      });

      test('card is distinguishable from the page behind it', () {
        expect(_contrast(c.card, c.pageBg), greaterThan(1.02),
            reason: 'cards would vanish into the background');
      });
    });
  }

  test('both themes publish the palette extension', () {
    expect(AppTheme.light(AppLanguage.ku).extension<AppColors>(), AppColors.light);
    expect(AppTheme.dark(AppLanguage.ku).extension<AppColors>(), AppColors.dark);
  });

  testWidgets('the dark theme actually resolves to the dark palette',
      (tester) async {
    late AppColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(AppLanguage.ku),
      darkTheme: AppTheme.dark(AppLanguage.ku),
      themeMode: ThemeMode.dark,
      home: Builder(builder: (context) {
        seen = context.c;
        return const SizedBox();
      }),
    ));
    expect(seen, AppColors.dark);
  });
}
