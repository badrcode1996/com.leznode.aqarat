import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/enums.dart';
import '../../services/push_service.dart';
import '../../theme/theme_mode_controller.dart';
import '../../l10n/app_language.dart';
import '../../l10n/language_controller.dart';
import '../lawyers/lawyers_screen.dart';
import '../widgets/house_cover_image.dart';
import 'about_screen.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;

/// Settings / Profile tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final user = ref.watch(currentUserProvider);
    final features = ref.watch(currentPlanFeaturesProvider);
    final company = ref.watch(currentCompanyProvider).value;

    final roleLabel = switch (user.role) {
      UserRole.companyAdmin => S.roleCompanyAdmin,
      UserRole.agent => S.roleAgent,
      UserRole.superAdmin => S.roleSuperAdmin,
    };

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(S.settings, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بەشی پرۆفایل
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.current.card,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                _ProfileAvatar(user: user, companyLogoUrl: company?.logoUrl ?? ''),
                const SizedBox(height: 16),
                Text(user.displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: accentYellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(roleLabel, style: TextStyle(color: AppColors.current.textStrong, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بەشی زانیارییەکان
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
            child: Text(S.sectionInfo, style: TextStyle(color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
          ),

          Container(
            decoration: BoxDecoration(
              color: AppColors.current.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                if (company != null) ...[
                  _tile(Icons.business_rounded, S.company, company.displayName),
                  const Divider(indent: 60, height: 1),
                  _tile(Icons.phone_rounded, S.companyPhone, company.phone1),
                  const Divider(indent: 60, height: 1),
                ],
                _tile(Icons.badge_outlined, S.mobileNumber, user.phone),
              ],
            ),
          ),

          // بەشی بەڕێوەبردن — تەنها بۆ ئەدمین
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
              child: Text(S.sectionAdmin,
                  style: TextStyle(color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.current.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  // پارێزەران — بەپێی کۆنفیگی پلان
                  if (features.lawyers) ...[
                    ListTile(
                      leading: Icon(Icons.gavel_rounded, color: AppColors.current.textStrong),
                      title: Text(S.lawyers, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(S.lawyersSubtitle,
                          style: TextStyle(color: AppColors.current.textMuted)),
                      trailing: Icon(Icons.chevron_left_rounded, color: AppColors.current.textMuted),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LawyersScreen()),
                      ),
                    ),
                    const Divider(indent: 60, height: 1),
                  ],
                  // نوێکردنەوەی قاسە و ئامار (دووبارە حیسابکردن لە گرێبەستەکانەوە).
                  // تەنها ئادمینی گشتی — حیسابکردنەوە پێویستی بە هەموو گرێبەستەکانی
                  // کۆمپانیا هەیە، کە ئادمینی لق ناتوانێت بیانخوێنێتەوە.
                  if (user.isCompanyWide)
                    ListTile(
                      leading: Icon(Icons.calculate_outlined, color: AppColors.current.textStrong),
                      title: Text(S.recalcStats, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(S.recalcStatsSubtitle,
                          style: TextStyle(color: AppColors.current.textMuted)),
                      trailing: Icon(Icons.chevron_left_rounded, color: AppColors.current.textMuted),
                      onTap: () => _recalcStats(context, ref),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ڕووکار — ڕووناک / تاریک
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
            child: Text(S.appearance,
                style: TextStyle(
                    color: AppColors.current.textMuted,
                    fontWeight: FontWeight.bold)),
          ),
          const _ThemePicker(),

          const SizedBox(height: 20),

          // زمان
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
            child: Text(S.languageLabel,
                style: TextStyle(
                    color: AppColors.current.textMuted,
                    fontWeight: FontWeight.bold)),
          ),
          const _LanguagePicker(),

          const SizedBox(height: 20),

          // دەربارەی ئێمە — بۆ هەموو بەکارهێنەرێک
          Container(
            decoration: BoxDecoration(
              color: AppColors.current.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: AppColors.current.textStrong),
              title: Text(S.aboutUs, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(S.aboutUsSubtitle,
                  style: TextStyle(color: AppColors.current.textMuted)),
              trailing: Icon(Icons.chevron_left_rounded, color: AppColors.current.textMuted),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // دوگمەی دەرچوون
          Container(
            decoration: BoxDecoration(
              color: AppColors.current.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: AppColors.current.danger),
              title: Text(S.signOut, style: TextStyle(color: AppColors.current.danger, fontWeight: FontWeight.bold)),
              // Drop the device's push token BEFORE signing out — afterwards
              // this account can no longer write its own user document, so the
              // token would linger and keep ringing for whoever signs in next.
              onTap: () async {
                await ref.read(pushServiceProvider).stop();
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recalcStats(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.recalcStats,
            style: TextStyle(
                color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: Text(
            S.recalcStatsBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.cancel,
                  style: TextStyle(color: AppColors.current.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDarkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.refresh),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(contractRepositoryProvider).recalculateStats();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.recalcStatsDone),
            backgroundColor: AppColors.current.success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    }
  }

  Widget _tile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: AppColors.current.textStrong),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(value.isEmpty ? S.emptyValue : value, style: TextStyle(color: AppColors.current.textMuted)),
  );
}

/// Light / dark / follow-the-system. The choice is stored on the device, so it
/// survives a restart and applies before the first frame — see
/// [themeModeProvider].
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final mode = ref.watch(themeModeProvider);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.current.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          for (final m in ThemeMode.values)
            Expanded(child: _option(ref, m, m == mode)),
        ],
      ),
    );
  }

  Widget _option(WidgetRef ref, ThemeMode mode, bool active) => GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).set(mode),
        // The gaps between options must react to a tap too, otherwise the
        // target is visibly narrower than the tile it sits in.
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: active ? AppColors.current.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(themeModeIcon(mode),
                  size: 22,
                  color: active
                      ? AppColors.current.onBrand
                      : AppColors.current.textMuted),
              const SizedBox(height: 4),
              Text(
                themeModeLabel(mode),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? AppColors.current.onBrand
                      : AppColors.current.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Interface language. Each option is written in its own language, so someone
/// stranded in a language they can't read can still find their way out.
class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final current = ref.watch(languageProvider);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.current.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < AppLanguage.values.length; i++) ...[
            if (i > 0) const Divider(indent: 60, height: 1),
            _option(ref, AppLanguage.values[i],
                AppLanguage.values[i] == current),
          ],
        ],
      ),
    );
  }

  Widget _option(WidgetRef ref, AppLanguage language, bool active) => ListTile(
        onTap: () => ref.read(languageProvider.notifier).set(language),
        leading: Icon(
          active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color:
              active ? AppColors.current.accent : AppColors.current.textFaint,
        ),
        title: Text(
          language.label,
          // Each label is in its own script, so it needs its own direction —
          // "English" inside an RTL column otherwise renders detached from its
          // row.
          textDirection: language.direction,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active
                ? AppColors.current.textStrong
                : AppColors.current.textBody,
          ),
        ),
      );
}

/// The tappable profile picture. Shows the user's own photo, falling back to
/// the company logo, then a person icon. Tapping picks an image, uploads it,
/// and refreshes the session so the new photo appears at once.
class _ProfileAvatar extends ConsumerStatefulWidget {
  const _ProfileAvatar({required this.user, required this.companyLogoUrl});

  final SessionUser user;
  final String companyLogoUrl;

  @override
  ConsumerState<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<_ProfileAvatar> {
  bool _busy = false;

  Future<void> _change() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final contentType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).uploadPhoto(bytes, contentType);
      // The session was read once at login; re-read it so the new photo (and
      // anything else on the user doc) shows without a restart.
      ref.invalidate(sessionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.profilePhotoUpdated),
            backgroundColor: AppColors.current.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    final photo = widget.user.photoUrl.isNotEmpty
        ? widget.user.photoUrl
        : widget.companyLogoUrl;
    return GestureDetector(
      onTap: _busy ? null : _change,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accentYellow, width: 2)),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: primaryDarkBlue.withValues(alpha: 0.1),
              backgroundImage:
                  photo.isNotEmpty ? NetworkImage(publicImageUrl(photo)) : null,
              child: photo.isEmpty
                  ? Icon(Icons.person, size: 40, color: AppColors.current.textStrong)
                  : null,
            ),
          ),
          if (_busy)
            CircularProgressIndicator(color: AppColors.current.textStrong, strokeWidth: 2.5),
          // A small camera badge so it reads as changeable.
          Positioned(
            bottom: 0,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: accentYellow, shape: BoxShape.circle),
              child: Icon(Icons.camera_alt, size: 15, color: AppColors.current.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}