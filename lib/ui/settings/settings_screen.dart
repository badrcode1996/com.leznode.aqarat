import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../models/enums.dart';

/// Settings / Profile tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final company = ref.watch(currentCompanyProvider).value;
    final scheme = Theme.of(context).colorScheme;

    final roleLabel = switch (user.role) {
      UserRole.companyAdmin => 'بەڕێوەبەری کۆمپانیا',
      UserRole.agent => 'گوماشتە',
      UserRole.superAdmin => 'بەڕێوەبەری گشتی',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('ڕێکخستن')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              backgroundImage: (company?.logoUrl.isNotEmpty ?? false)
                  ? NetworkImage(company!.logoUrl)
                  : null,
              child: (company?.logoUrl.isNotEmpty ?? false)
                  ? null
                  : Icon(Icons.person, size: 44, color: scheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(user.displayName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Center(
            child: Text(roleLabel,
                style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(height: 16),
          if (company != null)
            _tile(Icons.business, 'کۆمپانیا', company.displayName),
          if (company != null)
            _tile(Icons.phone, 'تەلەفۆن', company.phone1),
          _tile(Icons.badge_outlined, 'ژمارەی مۆبایل', user.phone),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('دەرچوون',
                style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value.isEmpty ? '—' : value),
      );
}
