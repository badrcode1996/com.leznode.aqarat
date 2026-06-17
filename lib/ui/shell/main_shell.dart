import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_config_repository.dart';
import '../../models/enums.dart';
import '../archive/archive_screen.dart';
import '../contracts/create_rent_contract_stepper.dart';
import '../contracts/create_sale_contract_stepper.dart';
import '../dashboard/dashboard_screen.dart';
import '../listings/create_listing_screen.dart';
import '../market/market_screen.dart';
import '../receipts/create_receipt_screen.dart';
import '../tenants/tenants_screen.dart';

// ڕەنگە سەرەکییەکان
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);

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
    TenantsScreen(),
    ArchiveScreen(),
    MarketScreen(),
  ];

  void _openQuickActions() {
    final features = ref.read(currentPlanFeaturesProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('کردارە خێراکان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDarkBlue)),
                ),
              ),
              _action(Icons.home_work_outlined, 'گرێبەستی کرێ', const Color(0xFF10B981), () => _push(const CreateRentContractStepper())),
              if (features.sale)
                _action(Icons.sell_outlined, 'گرێبەستی فرۆشتن', const Color(0xFF3B82F6), () => _push(const CreateSaleContractStepper())),
              if (features.offers)
                _action(Icons.add_home_work_outlined, 'خستنەڕووی موڵک', const Color(0xFFF59E0B), () => _push(const CreateListingScreen(kind: ListingKind.offer))),
              if (features.requests)
                _action(Icons.person_search_outlined, 'داواکاری موشتەری', const Color(0xFF8B5CF6), () => _push(const CreateListingScreen(kind: ListingKind.demand))),
              const Divider(indent: 20, endIndent: 20, height: 8),
              _action(Icons.south_west_rounded, 'پسولەی پارە وەرگرتن', const Color(0xFF10B981), () => _push(const CreateReceiptScreen(type: ReceiptType.externalReceive))),
              _action(Icons.north_east_rounded, 'پسولەی پارەدان', const Color(0xFFEF4444), () => _push(const CreateReceiptScreen(type: ReceiptType.externalPay))),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickActions,
        backgroundColor: accentYellow,
        foregroundColor: primaryDarkBlue,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 70,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_outlined, Icons.home_rounded, 'سەرەکی'),
            _navItem(1, Icons.people_outline, Icons.people_rounded, 'کرێچیەکان'),
            const SizedBox(width: 40), // notch gap
            _navItem(2, Icons.inventory_2_outlined, Icons.inventory_2, 'ئەرشیف'),
            _navItem(3, Icons.public_outlined, Icons.public_rounded, 'بازاڕ'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData active, String label) {
    final selected = _index == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? active : icon, size: 24, color: selected ? primaryDarkBlue : Colors.grey.shade500),
            const SizedBox(height: 2),
            Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? primaryDarkBlue : Colors.grey.shade500
                )
            ),
          ],
        ),
      ),
    );
  }
}