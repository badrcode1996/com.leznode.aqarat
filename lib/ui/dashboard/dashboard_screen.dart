import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/listing_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../listings/my_listings_screen.dart';
import 'widgets/property_card.dart';
import 'widgets/request_card.dart';
import 'widgets/stat_card.dart';

/// Dashboard (Home tab) built with slivers. All data is real (Firestore);
/// sections show empty states until data exists.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final company = ref.watch(currentCompanyProvider).value;
    final stats = ref.watch(companyStatsProvider).value;
    final contracts = ref.watch(contractsStreamProvider).value ?? const [];
    final offers = ref.watch(myListingsProvider(ListingKind.offer)).value;
    final demands = ref.watch(myListingsProvider(ListingKind.demand)).value;

    // Matchmaking: a demand and an offer "match" when they share the same
    // property type + project/neighborhood. Matched ones are shown green.
    final offerKeys = {for (final o in (offers ?? const [])) o.matchKey};
    final demandKeys = {for (final d in (demands ?? const [])) d.matchKey};
    bool offerMatched(PropertyListing p) => demandKeys.contains(p.matchKey);
    bool demandMatched(PropertyListing p) => offerKeys.contains(p.matchKey);

    // Computed live from the contracts stream.
    final now = DateTime.now();
    final contractsThisMonth = contracts
        .where((c) =>
            c.createdAt.year == now.year && c.createdAt.month == now.month)
        .length;
    num overdue = 0;
    for (final c in contracts) {
      if (c is RentContract) {
        for (final inst in c.installments) {
          if (inst.status == PaymentStatus.pending &&
              inst.dueDate.isBefore(now)) {
            overdue += c.rentAmount;
          }
        }
      }
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          floating: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          toolbarHeight: 68,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('بەخێربێیتەوە 👋',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
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
                            color: Theme.of(context).colorScheme.primary),
                      ),
              ),
            ),
          ],
        ),

        // ---------- Stats (real) ----------
        SliverToBoxAdapter(
          child: SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              children: [
                StatCard(
                  title: 'قاسەی نووسینگە',
                  value: _money.format(stats?.collectedRevenue ?? 0),
                  icon: Icons.account_balance_wallet_outlined,
                  accent: const Color(0xFF1565C0),
                ),
                StatCard(
                  title: 'گرێبەستەکانی ئەم مانگە',
                  value: '$contractsThisMonth',
                  icon: Icons.description_outlined,
                  accent: const Color(0xFF2E7D32),
                ),
                StatCard(
                  title: 'پارەی دواکەوتوو',
                  value: _money.format(overdue),
                  icon: Icons.warning_amber_rounded,
                  accent: const Color(0xFFC62828),
                  highlight: true,
                ),
                StatCard(
                  title: 'کۆی گرێبەستەکان',
                  value: '${stats?.contractCount ?? 0}',
                  icon: Icons.folder_outlined,
                  accent: const Color(0xFF6A1B9A),
                ),
              ],
            ),
          ),
        ),

        // ---------- Active demands (real) ----------
        _sectionTitle('داواکارییە چالاکەکان', onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MyListingsScreen(initialIndex: 1)),
          );
        }),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 150,
            child: (demands == null)
                ? const Center(child: CircularProgressIndicator())
                : demands.isEmpty
                    ? _emptyBox('هیچ داواکارییەک نییە')
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                        itemCount: demands.length,
                        itemBuilder: (_, i) => RequestCard(
                            listing: demands[i],
                            matched: demandMatched(demands[i])),
                      ),
          ),
        ),

        // ---------- Recent offers (real) ----------
        _sectionTitle('نوێترین موڵکەکان', onSeeAll: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MyListingsScreen(initialIndex: 0)),
          );
        }),
        if (offers == null)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (offers.isEmpty)
          SliverToBoxAdapter(child: _emptyBox('هیچ موڵکێک نییە')),
        if (offers != null && offers.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            sliver: SliverList.builder(
              itemCount: offers.length,
              itemBuilder: (_, i) => PropertyCard(
                  listing: offers[i], matched: offerMatched(offers[i])),
            ),
          ),
      ],
    );
  }

  Widget _emptyBox(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, style: const TextStyle(color: Colors.black45)),
        ),
      );

  Widget _sectionTitle(String title, {VoidCallback? onSeeAll}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                  onPressed: onSeeAll ?? () {},
                  child: const Text('هەمووی')),
            ],
          ),
        ),
      );
}
