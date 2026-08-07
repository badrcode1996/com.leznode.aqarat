import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/theme/app_colors.dart';
import 'package:aqarat/theme/app_theme.dart';

/// Regression test for the first dark mode, which came out as a patchwork:
/// only freshly-pushed routes were dark, and the tab screens — held in a
/// `const` list, so never rebuilt — stayed light.
///
/// The cause was that colours are read from the static [AppColors.current],
/// which Flutter cannot see as a dependency. [watchPalette] registers it. These
/// tests fail if that call is ever dropped from a screen.

/// A screen in the style the app uses: colours come from the static, and the
/// dependency is declared by [watchPalette].
class _PaletteScreen extends StatelessWidget {
  const _PaletteScreen();

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    return ColoredBox(
      key: const Key('surface'),
      color: AppColors.current.card,
      child: const SizedBox.expand(),
    );
  }
}

/// The same, but WITHOUT the dependency — what the broken version did.
class _StaleScreen extends StatelessWidget {
  const _StaleScreen();

  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const Key('surface'),
        color: AppColors.current.card,
        child: const SizedBox.expand(),
      );
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.child});
  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  ThemeMode mode = ThemeMode.light;

  /// setState is protected; the tests flip the theme through this instead.
  void setMode(ThemeMode m) => setState(() => mode = m);

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, child) {
          AppColors.current = Theme.of(context).extension<AppColors>()!;
          return child!;
        },
        // const, exactly like MainShell's tab list — the case that broke.
        home: widget.child,
      );
}

Color _cardColorOf(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(const Key('surface'))).color;

void main() {
  setUp(() => AppColors.current = AppColors.light);

  testWidgets('a const screen repaints when the brightness changes',
      (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _PaletteScreen()));
    expect(_cardColorOf(tester), AppColors.light.card);

    key.currentState!.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(_cardColorOf(tester), AppColors.dark.card,
        reason: 'watchPalette did not register the theme dependency');
  });

  testWidgets('and would NOT without watchPalette — the original bug',
      (tester) async {
    // Pins the failure mode, so nobody "simplifies" watchPalette away believing
    // the static alone is enough.
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _StaleScreen()));
    expect(_cardColorOf(tester), AppColors.light.card);

    key.currentState!.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(_cardColorOf(tester), AppColors.light.card,
        reason: 'a screen without the dependency is expected to go stale');
  });

  testWidgets('the palette static tracks the theme being painted',
      (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _PaletteScreen()));
    expect(AppColors.current, AppColors.light);

    key.currentState!.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(AppColors.current, AppColors.dark);
  });
}
