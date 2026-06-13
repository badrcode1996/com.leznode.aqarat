import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import 'dummy_data.dart';
import 'widgets/property_card.dart';
import 'widgets/request_card.dart';
import 'widgets/stat_card.dart';

/// Dashboard (Home tab) built with slivers.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final company = ref.watch(currentCompanyProvider).value;

    return CustomScrollView(
      slivers: [
        // ---------- App bar ----------
        SliverAppBar(
          pinned: true,
          floating: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            icon: const Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_outlined),
            ),
            onPressed: () {},
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('بەخێربێیتەوە 👋',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
              Text(
                user.displayName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage: (company?.logoUrl.isNotEmpty ?? false)
                    ? NetworkImage(company!.logoUrl)
                    : null,
                child: (company?.logoUrl.isNotEmpty ?? false)
                    ? null
                    : Text(
                        user.displayName.isNotEmpty
                            ? user.displayName.characters.first
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
          ],
        ),

        // ---------- Stats ----------
        SliverToBoxAdapter(
          child: SizedBox(
            height: 138,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              children: const [
                StatCard(
                  title: 'قاسەی نووسینگە',
                  value: '\$42,500',
                  icon: Icons.account_balance_wallet_outlined,
                  accent: Color(0xFF1565C0),
                  sparkline: [3, 4, 3.5, 5, 4.5, 6, 5.8],
                ),
                StatCard(
                  title: 'گرێبەستەکانی ئەم مانگە',
                  value: '18',
                  icon: Icons.description_outlined,
                  accent: Color(0xFF2E7D32),
                  sparkline: [2, 3, 2.5, 4, 3, 5, 4.5],
                ),
                StatCard(
                  title: 'پارەی دواکەوتوو',
                  value: '\$3,200',
                  icon: Icons.warning_amber_rounded,
                  accent: Color(0xFFC62828),
                  highlight: true,
                ),
                StatCard(
                  title: 'کۆی موڵکەکان',
                  value: '64',
                  icon: Icons.apartment_outlined,
                  accent: Color(0xFF6A1B9A),
                ),
              ],
            ),
          ),
        ),

        // ---------- Active demands ----------
        _sectionTitle('داواکارییە چالاکەکان'),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 132,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              itemCount: dummyDemands.length,
              itemBuilder: (_, i) => RequestCard(request: dummyDemands[i]),
            ),
          ),
        ),

        // ---------- Recent offers ----------
        _sectionTitle('نوێترین موڵک و پێشکەشکراوەکان'),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          sliver: SliverList.builder(
            itemCount: dummyOffers.length,
            itemBuilder: (_, i) => PropertyCard(offer: dummyOffers[i]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('هەمووی')),
            ],
          ),
        ),
      );
}
