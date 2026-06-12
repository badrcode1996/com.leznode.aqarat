import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';

import 'auth/session.dart';
import 'firebase_options.dart';
import 'models/enums.dart';
import 'theme/app_theme.dart';
import 'ui/admin/super_admin_panel.dart';
import 'ui/auth/login_screen.dart';
import 'ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        return const HomeScreen();
      },
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
