import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);
const Color inputFillColor = Color(0xFFF3F4F6);

/// Manage the company's own Offers and Demands: see active ones, mark them
/// completed (→ archive), and browse/restore archived ones.
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: appBackgroundColor,
        appBar: AppBar(
          title: const Text('بڵاوکراوەکانم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
              Tab(text: 'خستنەڕووەکان'),
              Tab(text: 'داواکارییەکان'),
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
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final async = _showArchived
        ? ref.watch(myArchivedListingsProvider(widget.kind))
        : ref.watch(myListingsProvider(widget.kind));

    return Column(
      children: [
        // دیزاینی مۆدێرن بۆ دوگمەی فلتەرکردن
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                backgroundColor: Colors.white,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: primaryDarkBlue,
                side: BorderSide(color: primaryDarkBlue.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('چالاک', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    icon: Icon(Icons.flash_on_rounded)
                ),
                ButtonSegment(
                    value: true,
                    label: Text('ئەرشیف (تەواوبوو)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    icon: Icon(Icons.inventory_2_outlined)
                ),
              ],
              selected: {_showArchived},
              onSelectionChanged: (s) => setState(() => _showArchived = s.first),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
            error: (e, _) => Center(child: Text('هەڵە: $e', style: const TextStyle(color: Colors.red))),
            data: (items) {
              if (items.isEmpty) {
                return _emptyBox(
                  _showArchived ? 'ئەرشیف بەتاڵە' : 'هیچ بڵاوکراوەیەکی چالاک نییە',
                  _showArchived ? Icons.inbox_outlined : Icons.search_off_rounded,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ListingCard(
                  listing: items[i],
                  kind: widget.kind,
                  archived: _showArchived,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // دیزاینی مۆدێرن بۆ شاشەی بەتاڵ
  Widget _emptyBox(String text, IconData icon) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: inputFillColor, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16),
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

  Future<void> _setArchived(BuildContext context, WidgetRef ref, bool value) async {
    try {
      await ref.read(listingRepositoryProvider).setArchived(kind, listing.id, value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'مامەڵەکە تەواوبوو (چووە ئەرشیف)' : 'گەڕێندرایەوە بۆ لیستی چالاک'),
            backgroundColor: value ? const Color(0xFF10B981) : primaryDarkBlue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffer = kind == ListingKind.offer;
    final iconColor = isOffer ? primaryDarkBlue : accentYellow;
    final bgColor = isOffer ? primaryDarkBlue.withValues(alpha: 0.1) : accentYellow.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryDarkBlue),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_iphone, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            listing.ownerMobile.isNotEmpty ? listing.ownerMobile : 'نەزانراو',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // تاگی گشتی/تایبەت
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: listing.isPublic ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(listing.isPublic ? Icons.public : Icons.public_off, size: 12, color: listing.isPublic ? const Color(0xFF10B981) : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        listing.isPublic ? 'گشتی' : 'تایبەت',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: listing.isPublic ? const Color(0xFF10B981) : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            // زانیارییەکانی موڵکەکە
            Row(
              children: [
                _infoChip(Icons.category_outlined, listing.propertyType.label),
                const SizedBox(width: 8),
                Expanded(child: _infoChip(Icons.location_on_outlined, listing.projectName)),
                const SizedBox(width: 8),
                _infoChip(Icons.square_foot, '${listing.area} م²'),
              ],
            ),

            const SizedBox(height: 16),

            // دوگمەی کردارەکان (تەواوکردن / گەڕاندنەوە)
            SizedBox(
              width: double.infinity,
              child: archived
                  ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryDarkBlue,
                  side: const BorderSide(color: primaryDarkBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.unarchive_outlined, size: 20),
                label: const Text('گەڕاندنەوە بۆ لیستی چالاک', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _setArchived(context, ref, false),
              )
                  : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // سەوزێکی مۆدێرن بۆ مامەڵەی سەرکەوتوو
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('مامەڵەکە تەواوبوو', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () => _setArchived(context, ref, true),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}