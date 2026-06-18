import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/listing_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../listings/my_listings_screen.dart';
import '../settings/settings_screen.dart';
import 'commissions_screen.dart';
import 'guarantees_screen.dart';
import 'overdue_screen.dart';
import 'widgets/property_card.dart';
import 'widgets/request_card.dart';
import 'widgets/stat_card.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);

/// Dashboard (Home tab) built with slivers. All data is real (Firestore);
/// sections show empty states until data exists.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final features = ref.watch(currentPlanFeaturesProvider);
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
        .where((c) => c.createdAt.year == now.year && c.createdAt.month == now.month)
        .length;
    // Cashbox (received-from-tenant) and overdue (pending + past due), each
    // split by currency so دینار and دۆلار are summed separately.
    num collectedIqd = 0, collectedUsd = 0, overdueIqd = 0, overdueUsd = 0;
    num guaranteeIqd = 0, guaranteeUsd = 0;
    num commissionIqd = 0, commissionUsd = 0;
    for (final c in contracts) {
      if (c is SaleContract) {
        // Commission resets monthly — only this month's sales count, and only
        // CONFIRMED items' actual paid amount.
        final thisMonth =
            c.createdAt.year == now.year && c.createdAt.month == now.month;
        if (thisMonth) {
          for (final item in c.commissionItems) {
            if (!item.confirmed) continue;
            if (c.currency == Currency.iqd) {
              commissionIqd += item.paid;
            } else {
              commissionUsd += item.paid;
            }
          }
        }
        continue;
      }
      if (c is! RentContract) continue;
      final isIqd = c.currency == Currency.iqd;
      // Guarantee/deposit total — only those still held (not returned).
      if (!c.guaranteeReturned) {
        if (isIqd) {
          guaranteeIqd += c.guaranteeAmount;
        } else {
          guaranteeUsd += c.guaranteeAmount;
        }
      }
      for (final inst in c.installments) {
        if (inst.status == PaymentStatus.receivedFromTenant) {
          if (isIqd) {
            collectedIqd += c.rentAmount;
          } else {
            collectedUsd += c.rentAmount;
          }
        } else if (inst.status == PaymentStatus.pending &&
            inst.dueDate.isBefore(now)) {
          if (isIqd) {
            overdueIqd += c.rentAmount;
          } else {
            overdueUsd += c.rentAmount;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: appBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 0,
            scrolledUnderElevation: 4,
            toolbarHeight: 76,
            backgroundColor: primaryDarkBlue,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            leading: IconButton(
              icon: const Icon(Icons.notifications_active_outlined, color: accentYellow, size: 28),
              onPressed: () {
                // نۆتیفیکەیشنەکان
              },
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'بەخێربێیتەوە 👋',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 2),
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: accentYellow,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: (company?.logoUrl.isNotEmpty ?? false) ? NetworkImage(company!.logoUrl) : null,
                    child: (company?.logoUrl.isNotEmpty ?? false)
                        ? null
                        : Text(
                      user.displayName.isNotEmpty ? user.displayName.characters.first : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryDarkBlue, fontSize: 18),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),

          // ---------- Stats (real) ----------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 152,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    StatCard(
                      title: 'قاسەی نووسینگە',
                      value: '${_money.format(collectedIqd)} د.ع',
                      secondValue: '${_money.format(collectedUsd)} \$',
                      icon: Icons.account_balance_wallet_rounded,
                      accent: primaryDarkBlue, // ڕەنگی مۆدێرن بۆ قاسە
                    ),
                    if (features.guarantees) ...[
                      const SizedBox(width: 12),
                      StatCard(
                        title: 'کۆی دڵنیایی',
                        value: '${_money.format(guaranteeIqd)} د.ع',
                        secondValue: '${_money.format(guaranteeUsd)} \$',
                        icon: Icons.shield_outlined,
                        accent: const Color(0xFF8B5CF6), // مۆری بۆ دڵنیایی
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const GuaranteesScreen()),
                        ),
                      ),
                    ],
                    if (features.commission) ...[
                      const SizedBox(width: 12),
                      StatCard(
                        title: 'عمولەی ئەم مانگە',
                        value: '${_money.format(commissionIqd)} د.ع',
                        secondValue: '${_money.format(commissionUsd)} \$',
                        icon: Icons.percent_rounded,
                        accent: const Color(0xFF0EA5E9), // شینی بۆ عمولە
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CommissionsScreen()),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    StatCard(
                      title: 'گرێبەستەکانی ئەم مانگە',
                      value: '$contractsThisMonth',
                      icon: Icons.description_rounded,
                      accent: const Color(0xFF10B981), // سەوزی کاڵ
                    ),
                    if (features.overdue) ...[
                      const SizedBox(width: 12),
                      StatCard(
                        title: 'پارەی دواکەوتوو',
                        value: '${_money.format(overdueIqd)} د.ع',
                        secondValue: '${_money.format(overdueUsd)} \$',
                        icon: Icons.warning_rounded,
                        accent: const Color(0xFFEF4444), // سووری کاڵ
                        highlight: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OverdueScreen()),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    StatCard(
                      title: 'کۆی گرێبەستەکان',
                      value: '${stats?.contractCount ?? 0}',
                      icon: Icons.folder_copy_rounded,
                      accent: accentYellow,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------- Active demands (real) ----------
          _sectionTitle('داواکارییە چالاکەکان', icon: Icons.person_search_rounded, onSeeAll: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen(initialIndex: 1)));
          }),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: (demands == null)
                  ? const Center(child: CircularProgressIndicator(color: primaryDarkBlue))
                  : demands.isEmpty
                  ? _emptyBox('هیچ داواکارییەکی نوێ نییە', Icons.search_off_rounded)
                  : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: demands.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => RequestCard(listing: demands[i], matched: demandMatched(demands[i])),
              ),
            ),
          ),

          // ---------- Recent offers (real) ----------
          _sectionTitle('نوێترین موڵکەکان', icon: Icons.real_estate_agent_rounded, onSeeAll: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen(initialIndex: 0)));
          }),
          if (offers == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
              ),
            )
          else if (offers.isEmpty)
            SliverToBoxAdapter(child: _emptyBox('هێشتا هیچ موڵکێک داخڵ نەکراوە', Icons.maps_home_work_outlined)),
          if (offers != null && offers.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // بۆشایی خوارەوە بۆ ئەوەی دوگمەی FAB دای نەپۆشێت
              sliver: SliverList.separated(
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => PropertyCard(listing: offers[i], matched: offerMatched(offers[i])),
              ),
            ),
        ],
      ),
    );
  }

  // دیزاینی مۆدێرن بۆ ئەو کاتانەی داتا نییە
  Widget _emptyBox(String text, IconData icon) => Center(
    child: Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    ),
  );

  // دیزاینی مۆدێرن بۆ ناونیشانی بەشەکان
  Widget _sectionTitle(String title, {required IconData icon, VoidCallback? onSeeAll}) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentYellow, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryDarkBlue),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSeeAll ?? () {},
            style: TextButton.styleFrom(
              foregroundColor: primaryDarkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('هەمووی', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}