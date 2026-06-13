import 'package:flutter/material.dart';

import '../../models/enums.dart';
import 'global_market_tab.dart';

/// Global Market tab with Offers / Demands sub-tabs.
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بازاڕی گشتی'),
          bottom: const TabBar(
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
