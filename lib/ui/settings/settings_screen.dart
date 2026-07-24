import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/enums.dart';
import '../lawyers/lawyers_screen.dart';
import 'about_screen.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);

/// Settings / Profile tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final features = ref.watch(currentPlanFeaturesProvider);
    final company = ref.watch(currentCompanyProvider).value;

    final roleLabel = switch (user.role) {
      UserRole.companyAdmin => 'بەڕێوەبەری کۆمپانیا',
      UserRole.agent => 'کارمەند',
      UserRole.superAdmin => 'بەڕێوەبەری گشتی',
    };

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: const Text('ڕێکخستن', style: TextStyle(fontWeight: FontWeight.bold)),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                _ProfileAvatar(user: user, companyLogoUrl: company?.logoUrl ?? ''),
                const SizedBox(height: 16),
                Text(user.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryDarkBlue)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: accentYellow.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(roleLabel, style: const TextStyle(color: primaryDarkBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // بەشی زانیارییەکان
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text('زانیارییەکان', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                if (company != null) ...[
                  _tile(Icons.business_rounded, 'کۆمپانیا', company.displayName),
                  const Divider(indent: 60, height: 1),
                  _tile(Icons.phone_rounded, 'تەلەفۆنی کۆمپانیا', company.phone1),
                  const Divider(indent: 60, height: 1),
                ],
                _tile(Icons.badge_outlined, 'ژمارەی مۆبایل', user.phone),
              ],
            ),
          ),

          // بەشی بەڕێوەبردن — تەنها بۆ ئەدمین
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 8),
              child: Text('بەڕێوەبردن',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  // پارێزەران — بەپێی کۆنفیگی پلان
                  if (features.lawyers) ...[
                    ListTile(
                      leading: const Icon(Icons.gavel_rounded, color: primaryDarkBlue),
                      title: const Text('پارێزەران', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('زیادکردن و دەستکاری لیستی پارێزەران',
                          style: TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
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
                      leading: const Icon(Icons.calculate_outlined, color: primaryDarkBlue),
                      title: const Text('نوێکردنەوەی قاسە و ئامار', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('دووبارە حیسابکردنیان لە گرێبەستەکانەوە',
                          style: TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
                      onTap: () => _recalcStats(context, ref),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // دەربارەی ئێمە — بۆ هەموو بەکارهێنەرێک
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: primaryDarkBlue),
              title: const Text('دەربارەی ئێمە', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('پەیوەندی و زانیاری ئەپەکە',
                  style: TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('دەرچوون', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => ref.read(authRepositoryProvider).signOut(),
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
        title: const Text('نوێکردنەوەی قاسە و ئامار',
            style: TextStyle(
                color: primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: const Text(
            'قاسە و ئامارەکان لە نوێوە لە گرێبەستەکانەوە حیساب دەکرێنەوە. ئەمە هیچ گرێبەست یان پسولەیەک ناگۆڕێت.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('پاشگەزبوونەوە',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryDarkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نوێکردنەوە'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(contractRepositoryProvider).recalculateStats();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('قاسە و ئامار نوێکرانەوە'),
            backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Widget _tile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: primaryDarkBlue),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.grey)),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('وێنەی پرۆفایل نوێ کرایەوە'),
            backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? const Icon(Icons.person, size: 40, color: primaryDarkBlue)
                  : null,
            ),
          ),
          if (_busy)
            const CircularProgressIndicator(color: primaryDarkBlue, strokeWidth: 2.5),
          // A small camera badge so it reads as changeable.
          Positioned(
            bottom: 0,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: accentYellow, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, size: 15, color: primaryDarkBlue),
            ),
          ),
        ],
      ),
    );
  }
}