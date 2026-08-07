import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_config_repository.dart';
import '../../models/enums.dart';
import '../../services/push_service.dart';
import '../archive/archive_screen.dart';
import '../contracts/create_rent_contract_stepper.dart';
import '../contracts/create_sale_contract_stepper.dart';
import '../dashboard/dashboard_screen.dart';
import '../listings/create_listing_screen.dart';
import '../listings/my_listings_screen.dart';
import '../receipts/create_receipt_screen.dart';
import '../tenants/tenants_screen.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;

/// Main app shell: 4-tab bottom navigation with a centered docked FAB.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Registered here rather than in main(): the shell is the first screen that
    // only ever builds for a signed-in, provisioned, non-expired member, which
    // is exactly who should have a device token stored. Not awaited — the
    // permission prompt must not hold up the first frame.
    ref.read(pushServiceProvider).start();
  }

  static const _tabs = [
    DashboardScreen(),
    TenantsScreen(),
    ArchiveScreen(),
    // داواکاری و خستنەڕوو — بازاڕی گشتیش لێرەوەیە، وەک بەشێکی سێیەمی
    // فلتەرەکە (بۆ سیلڤەر بەرەوژوور).
    MyListingsScreen(),
  ];

  void _openQuickActions() {
    final features = ref.read(currentPlanFeaturesProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.current.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(S.quickActions, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
                ),
              ),
              // گرێبەستی کرێ و فرۆشتن و پسولەکان — کردارە بنەڕەتییەکانن،
              // لە هەموو پلانێکدا بەردەستن و بە پلان gate ناکرێن.
              _action(Icons.home_work_outlined, S.rentContract, AppColors.current.success, () => _push(const CreateRentContractStepper())),
              _action(Icons.sell_outlined, S.saleContract, AppColors.current.info, () => _push(const CreateSaleContractStepper())),
              if (features.offers)
                _action(Icons.add_home_work_outlined, S.listProperty, AppColors.current.warning, () => _push(const CreateListingScreen(kind: ListingKind.offer))),
              if (features.requests)
                _action(Icons.person_search_outlined, S.customerRequest, AppColors.current.violet, () => _push(const CreateListingScreen(kind: ListingKind.demand))),
              const Divider(indent: 20, endIndent: 20, height: 8),
              _action(Icons.south_west_rounded, S.receiptIn, AppColors.current.success, () => _push(const CreateReceiptScreen(type: ReceiptType.externalReceive))),
              _action(Icons.north_east_rounded, S.receiptOut, AppColors.current.danger, () => _push(const CreateReceiptScreen(type: ReceiptType.externalPay))),
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
    watchAppShell(context);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickActions,
        backgroundColor: accentYellow,
        foregroundColor: AppColors.current.onAccent,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 70,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: AppColors.current.card,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_outlined, Icons.home_rounded, S.navHome),
            _navItem(1, Icons.people_outline, Icons.people_rounded, S.navTenants),
            const SizedBox(width: 40), // notch gap
            _navItem(2, Icons.inventory_2_outlined, Icons.inventory_2, S.navArchive),
            _navItem(3, Icons.storefront_outlined, Icons.storefront_rounded,
                S.navListings),
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
            Icon(selected ? active : icon, size: 24, color: selected ? AppColors.current.textStrong : AppColors.current.textMuted),
            const SizedBox(height: 2),
            // FittedBox ناوە درێژەکان بچووک دەکاتەوە بۆ پانی خانەکە
            // (بۆ نموونە «داواکاری و خستنەڕوو») بەبێ شکان یان بڕان.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? AppColors.current.textStrong : AppColors.current.textMuted
                    )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}