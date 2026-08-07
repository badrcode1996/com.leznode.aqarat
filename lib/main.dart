import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/session.dart';
import 'data/plan_config_repository.dart';
import 'firebase_options.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_controller.dart';
import 'models/enums.dart';
import 'services/push_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';
import 'ui/admin/super_admin_panel.dart';
import 'ui/auth/login_screen.dart';
import 'ui/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTHING here may throw or hang before runApp(): until the first frame is
  // drawn the OS keeps showing LaunchTheme's window background, so a failure
  // this early looks like the app freezing on the splash image with no error.
  Object? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, s) {
    debugPrint('Firebase.initializeApp failed: $e\n$s');
    startupError = e;
  }

  // App Check attests that requests come from our genuine app before Firebase
  // (Firestore/Storage/Functions) will serve them. Debug builds use the debug
  // provider — register the token printed in logcat once in the console;
  // release builds use Play Integrity (Android) / App Attest (iOS). Enforcement
  // must stay OFF in the console until live traffic shows valid tokens.
  //
  // Deliberately NOT awaited, and swallowed on failure: Play Integrity is
  // unavailable on emulators and on any device without Google Play Services
  // (Huawei), and App Attest needs a real iOS device. Awaiting it there killed
  // main() before runApp() and stranded the app on the launch screen. Attested
  // tokens are only needed once enforcement is switched on in the console —
  // never to render the UI.
  //
  // Web is skipped: it would need a reCAPTCHA web provider + a registered site
  // key. With enforcement OFF this isn't required for the web build to work; add
  // a ReCaptchaV3Provider here once a site key is configured.
  if (!kIsWeb && startupError == null) {
    unawaited(
      FirebaseAppCheck.instance
          .activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
            appleProvider:
                kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
          )
          .catchError((Object e) =>
              debugPrint('App Check unavailable on this device: $e')),
    );
  }

  runApp(startupError == null
      ? const ProviderScope(child: AqaratApp())
      : _StartupErrorApp(error: startupError));
}

/// Shown when Firebase itself could not start. Without it the app would sit on
/// the launch image forever, with nothing on screen to say why.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 64, color: AppColors.current.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      S.cannotConnect,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      S.checkInternet,
                      style: TextStyle(color: AppColors.current.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$error',
                      style: TextStyle(fontSize: 11, color: AppColors.current.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class AqaratApp extends ConsumerWidget {
  const AqaratApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final language = ref.watch(languageProvider);
    // Publish the catalogue BEFORE building, not in `builder`: strings are read
    // from enum members and model getters that run outside the widget tree, and
    // those must already see the right language on this frame.
    AppStrings.current = AppStrings.of(language);

    return MaterialApp(
      title: AppStrings.of(language).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(language),
      darkTheme: AppTheme.dark(language),
      // Restored from the device on startup; ThemeMode.system until it resolves.
      themeMode: ref.watch(themeModeProvider),

      // Lets a push tap open the notification centre from outside the widget
      // tree (see PushService).
      navigatorKey: navigatorKey,

      // Flutter's bundled delegates don't ship Central Kurdish (ckb), so it
      // borrows Arabic — also RTL and fully supported — for built-in widget
      // labels (date picker buttons, etc.). See AppLanguage.materialLocale.
      locale: language.materialLocale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Publish the palette for the brightness actually being painted, before
        // anything below builds. See AppColors.current.
        final palette = Theme.of(context).extension<AppColors>()!;
        AppColors.current = palette;
        // Direction follows the language rather than being pinned to RTL —
        // English has to mirror the whole layout back.
        return AppShellScope(
          // What every screen depends on through watchAppShell. Brightness
          // alone is not enough: Kurdish and Arabic are both RTL, so switching
          // between them changes nothing Flutter tracks, and without this the
          // screens would keep rendering the language they were built in.
          revision: Object.hash(palette.pageBg, language),
          child: Directionality(
            textDirection: language.direction,
            child: child!,
          ),
        );
      },

      home: const _SessionGate(),
    );
  }
}

/// Routes based on auth + profile state:
///   - signed out                    → LoginScreen
///   - Super Admin                   → SuperAdminPanel
///   - signed in, no profile yet     → _NoAccessScreen (provisioned by admin)
///   - signed in, profile loaded     → HomeScreen
class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    // On sign-out, pop any pushed routes (Settings, create screens, …) back to
    // the root. Otherwise a still-mounted pushed screen rebuilds against a null
    // session and `currentUserProvider` throws — the red "No active session"
    // error. authState turns null before the async session resolves, so this
    // tears the routes down first.
    ref.listen(authStateProvider, (prev, next) {
      if (next.value == null) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) return const LoginScreen();

    final session = ref.watch(sessionProvider);
    return session.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(S.error(e)))),
      data: (user) {
        if (user == null) return const _NoAccessScreen();
        if (user.role == UserRole.superAdmin) return const SuperAdminPanel();
        // A lapsed trial is stopped on every platform. This screen is the
        // courtesy message; the security rules are what actually withhold the
        // data, so a patched client gains nothing but empty screens.
        if (user.demoExpired) return const _DemoExpiredScreen();
        // Web-only is blocked in the mobile app — set per company OR per plan.
        final planWebOnly = ref
                .watch(planConfigProvider)
                .valueOrNull
                ?.forPlan(user.plan)
                .webOnly ??
            false;
        if (!kIsWeb && (user.webOnly || planWebOnly)) {
          return const _WebOnlyScreen();
        }
        return const MainShell();
      },
    );
  }
}

/// Shown once a demo company's 7 days are up, on every platform.
class _DemoExpiredScreen extends ConsumerWidget {
  const _DemoExpiredScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse_outlined,
                  size: 64, color: AppColors.current.danger),
              const SizedBox(height: 16),
              Text(
                S.demoOver,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(S.demoOverBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(S.signOut),
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in the mobile app for a company configured as web-only. The same
/// account works on the web build (aqarat.leznode.com).
class _WebOnlyScreen extends ConsumerWidget {
  const _WebOnlyScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 64),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(S.webOnlyBody, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(S.signOut),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a signed-in account has no profile. Accounts are provisioned by
/// the Super Admin, so there is no self-registration path.
class _NoAccessScreen extends ConsumerWidget {
  const _NoAccessScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_accounts, size: 64),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(S.noCompanyBody, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(S.signOut),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
