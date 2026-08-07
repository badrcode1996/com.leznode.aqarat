import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/l10n/app_language.dart';
import 'package:aqarat/l10n/app_strings.dart';
import 'package:aqarat/theme/app_colors.dart';
import 'package:aqarat/theme/app_theme.dart';

/// Regression tests for two rounds of the same mistake.
///
/// Colours and strings are read from statics, so Flutter cannot see that a
/// screen depends on them. First that made dark mode a patchwork: only
/// freshly-pushed routes came out dark, and the tab screens — held in a `const`
/// list, so never rebuilt — stayed light. Registering the Theme fixed
/// brightness but NOT language: Kurdish and Arabic are both RTL, so switching
/// between them changed nothing Flutter tracks, and every screen stayed
/// Kurdish.
///
/// [watchAppShell] registers both. These tests fail if it is ever dropped.

/// A screen in the style the app uses: values come from the statics, and the
/// dependency is declared by [watchAppShell].
class _WatchingScreen extends StatelessWidget {
  const _WatchingScreen();

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    return ColoredBox(
      key: const Key('surface'),
      color: AppColors.current.card,
      child: Text(S.settings, textDirection: TextDirection.ltr),
    );
  }
}

/// The same, but WITHOUT the dependency — what the broken versions did.
class _StaleScreen extends StatelessWidget {
  const _StaleScreen();

  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const Key('surface'),
        color: AppColors.current.card,
        child: Text(S.settings, textDirection: TextDirection.ltr),
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
  AppLanguage language = AppLanguage.ku;

  /// setState is protected; the tests drive the app through these.
  void setMode(ThemeMode m) => setState(() => mode = m);
  void setLanguage(AppLanguage l) => setState(() => language = l);

  @override
  Widget build(BuildContext context) {
    AppStrings.current = AppStrings.of(language);
    return MaterialApp(
      theme: AppTheme.light(AppLanguage.ku),
      darkTheme: AppTheme.dark(AppLanguage.ku),
      themeMode: mode,
      builder: (context, child) {
        final palette = Theme.of(context).extension<AppColors>()!;
        AppColors.current = palette;
        return AppShellScope(
          revision: Object.hash(palette.pageBg, language),
          child: Directionality(
            textDirection: language.direction,
            child: child!,
          ),
        );
      },
      // const, exactly like MainShell's tab list — the case that broke.
      home: widget.child,
    );
  }
}

Color _surfaceOf(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(const Key('surface'))).color;

void main() {
  setUp(() {
    AppColors.current = AppColors.light;
    AppStrings.current = AppStrings.ku;
  });

  testWidgets('a const screen repaints when the brightness changes',
      (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _WatchingScreen()));
    expect(_surfaceOf(tester), AppColors.light.card);

    key.currentState!.setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(_surfaceOf(tester), AppColors.dark.card,
        reason: 'watchAppShell did not register the theme dependency');
  });

  testWidgets('a const screen re-renders when the language changes',
      (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _WatchingScreen()));
    expect(find.text(AppStrings.ku.settings), findsOneWidget);

    // Kurdish -> Arabic keeps the layout RTL, so nothing Flutter tracks by
    // itself changes. This is exactly the case that shipped broken.
    key.currentState!.setLanguage(AppLanguage.ar);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.ar.settings), findsOneWidget,
        reason: 'watchAppShell did not register the language dependency');
  });

  testWidgets('and neither happens without watchAppShell', (tester) async {
    // Pins both failure modes, so nobody removes the call believing the statics
    // alone are enough.
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _StaleScreen()));

    key.currentState!.setMode(ThemeMode.dark);
    key.currentState!.setLanguage(AppLanguage.ar);
    await tester.pumpAndSettle();

    expect(_surfaceOf(tester), AppColors.light.card,
        reason: 'a screen without the dependency is expected to go stale');
    expect(find.text(AppStrings.ku.settings), findsOneWidget);
  });

  testWidgets('the statics track what is being rendered', (tester) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, child: const _WatchingScreen()));
    expect(AppColors.current, AppColors.light);
    expect(AppStrings.current.language, AppLanguage.ku);

    key.currentState!.setMode(ThemeMode.dark);
    key.currentState!.setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();

    expect(AppColors.current, AppColors.dark);
    expect(AppStrings.current.language, AppLanguage.en);
  });
}
