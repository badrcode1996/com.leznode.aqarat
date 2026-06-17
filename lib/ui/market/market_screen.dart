import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_config_repository.dart';
import '../../models/enums.dart';
import '../widgets/plan_locked.dart';
import 'global_market_tab.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);

/// Global Market tab with Offers / Demands sub-tabs. Locked below the Silver
/// plan.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(currentPlanFeaturesProvider).market) {
      return Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          title: const Text('بازاڕی گشتی',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: const PlanLocked(
          message:
              'بازاڕی گشتی لە پلانی سیلڤەر بەرەوژوور بەردەستە.\nبۆ بەکارهێنانی، پلانەکەت بەرز بکەرەوە.',
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'بازاڕی گشتی',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          backgroundColor: primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: accentYellow,
            indicatorWeight: 4,
            labelColor: accentYellow,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: 'پێشکەشکراوەکان'),
              Tab(text: 'داواکارییەکان'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            GlobalMarketTab(kind: ListingKind.offer),
            GlobalMarketTab(kind: ListingKind.demand),
          ],
        ),
      ),
    );
  }
}