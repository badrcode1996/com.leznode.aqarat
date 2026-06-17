import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/session.dart';
import 'data/plan_config_repository.dart';
import 'firebase_options.dart';
import 'models/enums.dart';
import 'theme/app_theme.dart';
import 'ui/admin/super_admin_panel.dart';
import 'ui/auth/login_screen.dart';
import 'ui/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check attests that requests come from our genuine app before Firebase
  // (Firestore/Storage/Functions) will serve them. Debug builds use the debug
  // provider — register the token printed in logcat once in the console;
  // release builds use Play Integrity (Android) / App Attest (iOS). Enforcement
  // must stay OFF in the console until live traffic shows valid tokens.
  //
  // Web is skipped: it would need a reCAPTCHA web provider + a registered site
  // key. With enforcement OFF this isn't required for the web build to work; add
  // a ReCaptchaV3Provider here once a site key is configured.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  }

  runApp(const ProviderScope(child: AqaratApp()));
}

class AqaratApp extends ConsumerWidget {
  const AqaratApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'عقارات',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),

      // Flutter's bundled delegates don't ship Central Kurdish (ckb), so we
      // resolve to Arabic — also RTL and fully supported — for built-in widget
      // labels (date picker buttons, etc.). Our own UI text is hardcoded
      // Kurdish. To get fully localized `ckb`, add a custom
      // LocalizationsDelegate and list it here.
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Force RTL layout regardless of device locale resolution.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),

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
      error: (e, _) => Scaffold(body: Center(child: Text('هەڵە: $e'))),
      data: (user) {
        if (user == null) return const _NoAccessScreen();
        if (user.role == UserRole.superAdmin) return const SuperAdminPanel();
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

/// Shown in the mobile app for a company configured as web-only. The same
/// account works on the web build (aqarat.leznode.com).
class _WebOnlyScreen extends ConsumerWidget {
  const _WebOnlyScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 64),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'ئەم هەژمارە تەنها لە وێب کاردەکات.\n'
                'تکایە لە ڕێگەی aqarat.leznode.com بچۆ ژوورەوە.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('دەرچوون'),
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_accounts, size: 64),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'ئەم هەژمارە بە هیچ کۆمپانیایەکەوە پەیوەست نییە.\n'
                'تکایە پەیوەندی بە بەڕێوەبەرەوە بکە.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('دەرچوون'),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
