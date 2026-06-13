import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contracts/contracts_screen.dart';
import '../contracts/create_rent_contract_stepper.dart';
import '../contracts/create_sale_contract_stepper.dart';
import '../dashboard/dashboard_screen.dart';
import '../market/market_screen.dart';
import '../settings/settings_screen.dart';

/// Main app shell: 4-tab bottom navigation with a centered docked FAB.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    ContractsScreen(),
    MarketScreen(),
    SettingsScreen(),
  ];

  void _openQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('کردارە خێراکان',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            _action(Icons.home_outlined, 'گرێبەستی کرێ', const Color(0xFF2E7D32),
                () => _push(const CreateRentContractStepper())),
            _action(Icons.sell_outlined, 'گرێبەستی فرۆشتن',
                const Color(0xFF1565C0),
                () => _push(const CreateSaleContractStepper())),
            _action(Icons.add_home_work_outlined, 'پێشکەشکردنی موڵک',
                const Color(0xFFEF6C00), _comingSoon),
            _action(Icons.person_search_outlined, 'داواکاری موشتەری',
                const Color(0xFF6A1B9A), _comingSoon),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _push(Widget screen) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );

  void _comingSoon() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بەم زووانە...')),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickActions,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_outlined, Icons.home, 'سەرەکی'),
            _navItem(1, Icons.description_outlined, Icons.description,
                'گرێبەست'),
            const SizedBox(width: 48), // notch gap for the FAB
            _navItem(2, Icons.public_outlined, Icons.public, 'بازاڕ'),
            _navItem(3, Icons.settings_outlined, Icons.settings, 'ڕێکخستن'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData active, String label) {
    final selected = _index == index;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade600;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? active : icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, color: color)),
          ],
        ),
      ),
    );
  }
}
