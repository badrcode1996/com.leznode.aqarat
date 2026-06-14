import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../models/enums.dart';
import '../lawyers/lawyers_screen.dart';

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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentYellow, width: 2)),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: primaryDarkBlue.withValues(alpha: 0.1),
                    backgroundImage: (company?.logoUrl.isNotEmpty ?? false) ? NetworkImage(company!.logoUrl) : null,
                    child: (company?.logoUrl.isNotEmpty ?? false)
                        ? null
                        : const Icon(Icons.person, size: 40, color: primaryDarkBlue),
                  ),
                ),
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
              child: ListTile(
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
            ),
          ],

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

  Widget _tile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: primaryDarkBlue),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.grey)),
  );
}