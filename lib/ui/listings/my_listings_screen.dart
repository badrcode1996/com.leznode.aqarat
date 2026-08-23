import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/listing_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../market/global_market_tab.dart';
import '../widgets/deal_filter_bar.dart';
import '../widgets/house_cover_image.dart';
import '../widgets/location_view.dart';
import 'create_listing_screen.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

/// What the list below the فرۆشتن/کرێ bar is showing: the company's own active
/// listings, its archive, or the cross-company Global Market (Silver and up).
enum _ListSource { active, archived, market }

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;
Color get inputFillColor => AppColors.current.inputFill;

/// Manage the company's own Offers and Demands: see active ones, mark them
/// completed (→ archive), and browse/restore archived ones.
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          title: Text(S.myListings, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: primaryDarkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: accentYellow,
            indicatorWeight: 4,
            labelColor: accentYellow,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: S.tabOffers),
              Tab(text: S.tabDemands),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ListingsTab(kind: ListingKind.offer),
            _ListingsTab(kind: ListingKind.demand),
          ],
        ),
      ),
    );
  }
}

class _ListingsTab extends ConsumerStatefulWidget {
  const _ListingsTab({required this.kind});
  final ListingKind kind;

  @override
  ConsumerState<_ListingsTab> createState() => _ListingsTabState();
}

class _ListingsTabState extends ConsumerState<_ListingsTab> {
  _ListSource _source = _ListSource.active;
  DealKind _deal = DealKind.sale;

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    // بازاڕی گشتی لە پلانی سیلڤەر بەرەوژوور. بۆ بڕۆنز هەر دەرناکەوێت —
    // وەک کردارە خێراکانی گەڕاوە، فیچەری نەکڕدراو نیشان نادرێت.
    final hasMarket = ref.watch(currentPlanFeaturesProvider).market;
    // A plan downgrade must not strand the user on a segment that no longer
    // exists.
    if (!hasMarket && _source == _ListSource.market) {
      _source = _ListSource.active;
    }

    return Column(
      children: [
        // فرۆشتن / کرێ — دابەشکردنی سەرەکی. لە سەرەوەی فلتەری ئەرشیفە چونکە
        // بەشێکی جیایە، نەک دۆخێکی لیستەکە.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: DealFilterBar(
            selected: _deal,
            onChanged: (d) => setState(() => _deal = d),
            kind: widget.kind,
          ),
        ),
        // دیزاینی مۆدێرن بۆ دوگمەی فلتەرکردن
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_ListSource>(
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.current.card,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: primaryDarkBlue,
                side: BorderSide(color: primaryDarkBlue.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              segments: [
                _segment(_ListSource.active, S.filterActive, Icons.flash_on_rounded,
                    hasMarket),
                // The long form only fits while there are two segments.
                _segment(
                    _ListSource.archived,
                    hasMarket ? S.filterArchived : S.filterArchivedLong,
                    Icons.inventory_2_outlined,
                    hasMarket),
                if (hasMarket)
                  _segment(_ListSource.market, S.filterMarket,
                      Icons.public_outlined, hasMarket),
              ],
              selected: {_source},
              onSelectionChanged: (s) => setState(() => _source = s.first),
            ),
          ),
        ),
        Expanded(
          child: _source == _ListSource.market
              // The global market reuses the فرۆشتن/کرێ bar above rather than
              // stacking a second identical one.
              ? GlobalMarketTab(kind: widget.kind, deal: _deal)
              : _myListings(),
        ),
      ],
    );
  }

  ButtonSegment<_ListSource> _segment(
          _ListSource value, String label, IconData icon, bool tight) =>
      ButtonSegment(
        value: value,
        label: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: tight ? 13 : 15)),
        icon: Icon(icon),
      );

  Widget _myListings() {
    final archived = _source == _ListSource.archived;
    final async = archived
        ? ref.watch(myArchivedListingsProvider(widget.kind))
        : ref.watch(myListingsProvider(widget.kind));

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
      error: (e, _) =>
          Center(child: Text(S.error(e), style: TextStyle(color: AppColors.current.danger))),
      data: (all) {
        // وەک فلتەری ئەرشیف، ئەمەش لای کلاینت دەکرێت — بۆ ئەوەی
        // ئیندێکسێکی composite ی نوێ نەوێت.
        final items = all.where((l) => l.deal == _deal).toList();
        if (items.isEmpty) {
          return _emptyBox(
            archived
                ? S.archiveEmptyFor(_deal.labelFor(widget.kind))
                : S.noActiveListingsFor(_deal.labelFor(widget.kind)),
            archived ? Icons.inbox_outlined : Icons.search_off_rounded,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ListingCard(
            listing: items[i],
            kind: widget.kind,
            archived: archived,
          ),
        );
      },
    );
  }

  // دیزاینی مۆدێرن بۆ شاشەی بەتاڵ
  Widget _emptyBox(String text, IconData icon) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.current.divider, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: inputFillColor, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: AppColors.current.textFaint),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: AppColors.current.textMuted, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({
    required this.listing,
    required this.kind,
    required this.archived,
  });

  final PropertyListing listing;
  final ListingKind kind;
  final bool archived;

  void _edit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateListingScreen(kind: kind, existing: listing),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.delete,
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
        content: Text(
          S.deleteListingConfirm(listing.ownerName),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel, style: TextStyle(color: AppColors.current.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.current.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(listingRepositoryProvider).delete(kind, listing.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.deleted),
          backgroundColor: primaryDarkBlue,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    }
  }

  Future<void> _setArchived(BuildContext context, WidgetRef ref, bool value) async {
    try {
      await ref.read(listingRepositoryProvider).setArchived(kind, listing.id, value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? S.dealDoneToast : S.restoredToast),
            backgroundColor: value ? AppColors.current.success : AppColors.current.textStrong,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final isOffer = kind == ListingKind.offer;
    final iconColor = isOffer ? AppColors.current.textStrong : accentYellow;
    final bgColor = isOffer ? primaryDarkBlue.withValues(alpha: 0.1) : accentYellow.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.current.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // گەلەری وێنەکان (ئەگەر هەبن)
            HouseGallery(urls: listing.imageUrls),
            // بەشی سەرەوە (ناوی خاوەن و ئایکۆن)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                    isOffer ? Icons.home_work_outlined : Icons.person_search_outlined,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.ownerName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.current.textStrong),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_iphone, size: 12, color: AppColors.current.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            listing.ownerMobile.isNotEmpty ? listing.ownerMobile : S.unknown,
                            style: TextStyle(color: AppColors.current.textMuted, fontSize: 12, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // تاگی فرۆشتن/کرێ
                DealBadge(deal: listing.deal, kind: listing.kind),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            // نرخ — بەرچاوترین زانیاری، بۆیە ڕیزی خۆی هەیە نەک چیپێک.
            if (listing.priceLabel.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 18, color: AppColors.current.success),
                  const SizedBox(width: 6),
                  Text(
                    listing.priceLabel,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.current.success),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // زانیارییەکانی موڵکەکە. ژوور و حەمام تەنها کاتێک دەردەکەون
            // کە دیاریکرابن — زەوی و دوکان هیچیان نییە.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.category_outlined, listing.propertyType.label),
                _infoChip(Icons.location_on_outlined, listing.projectName),
                _infoChip(Icons.square_foot, S.areaSqm(listing.area)),
                if (listing.floors > 0)
                  _infoChip(Icons.layers_outlined, S.floorsCount(listing.floors)),
                if (listing.rooms > 0)
                  _infoChip(Icons.bed_outlined, S.roomsCount(listing.rooms)),
                if (listing.bathrooms > 0)
                  _infoChip(
                      Icons.bathtub_outlined, S.bathroomsCount(listing.bathrooms)),
              ],
            ),

            const SizedBox(height: 16),

            // دوگمەی کردارەکان (تەواوکردن / گەڕاندنەوە، دەستکاری، سڕینەوە)
            Row(
              children: [
                Expanded(child: _mainAction(context, ref)),
                // ماپ تەنها بۆ ئەو موڵکانەی شوێنیان دانراوە، و تەنها بۆ ئەو
                // پلانانەی ماپیان هەیە — بەبێ ئەمە، بەکارهێنەرێکی بڕۆنز
                // دوگمەیەک دەبینێت کە شاشەیەکی خۆڵەمێشی دەکاتەوە.
                if (listing.hasLocation &&
                    ref.watch(currentPlanFeaturesProvider).map) ...[
                  const SizedBox(width: 8),
                  _iconAction(
                    icon: Icons.location_on_outlined,
                    color: AppColors.current.brand,
                    tooltip: S.propertyLocation,
                    onPressed: () => LocationView.show(
                      context,
                      lat: listing.lat!,
                      lng: listing.lng!,
                      title: listing.projectName,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                _iconAction(
                  icon: Icons.edit_outlined,
                  color: AppColors.current.textStrong,
                  tooltip: S.edit,
                  onPressed: () => _edit(context),
                ),
                const SizedBox(width: 8),
                _iconAction(
                  icon: Icons.delete_outline,
                  color: AppColors.current.danger,
                  tooltip: S.delete,
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainAction(BuildContext context, WidgetRef ref) => SizedBox(
              width: double.infinity,
              child: archived
                  ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.current.textStrong,
                  side: BorderSide(color: primaryDarkBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.unarchive_outlined, size: 20),
                label: Text(S.restoreToActive, style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _setArchived(context, ref, false),
              )
                  : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.current.success, // سەوزێکی مۆدێرن بۆ مامەڵەی سەرکەوتوو
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: Text(S.dealDone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () => _setArchived(context, ref, true),
              ),
      );

  /// A square, outlined counterpart to the wide primary action, so edit and
  /// delete stay reachable without competing with it for attention.
  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) =>
      Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 46,
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 20),
          ),
        ),
      );

  // یارمەتیدەرێک بۆ دروستکردنی تاگەکانی زانیاری موڵک
  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.current.textBody),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.current.textBody),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}