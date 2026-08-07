import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../widgets/deal_filter_bar.dart';
import '../widgets/house_cover_image.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get inputFillColor => AppColors.current.inputFill;

/// Global B2B Market — shows public listings from ALL companies.
///
/// PRIVACY: it binds to [globalMarketProvider] which yields [PublicListingView]
/// (no owner name/mobile). Contact is the creating agent + company phone, with
/// a url_launcher "Click to Call" button.
class GlobalMarketTab extends ConsumerStatefulWidget {
  const GlobalMarketTab({super.key, this.kind = ListingKind.offer, this.deal});

  final ListingKind kind;

  /// When set, the tab uses this deal and drops its own فرۆشتن/کرێ bar —
  /// for embedding under a screen that already shows one, so the user isn't
  /// looking at two identical filters stacked on top of each other.
  final DealKind? deal;

  @override
  ConsumerState<GlobalMarketTab> createState() => _GlobalMarketTabState();
}

class _GlobalMarketTabState extends ConsumerState<GlobalMarketTab> {
  DealKind _own = DealKind.sale;

  DealKind get _deal => widget.deal ?? _own;

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    final async = ref.watch(globalMarketProvider(widget.kind));
    final isOffer = widget.kind == ListingKind.offer;

    return Column(
      children: [
        if (widget.deal == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DealFilterBar(
              selected: _deal,
              onChanged: (d) => setState(() => _own = d),
              kind: widget.kind,
            ),
          ),
        Expanded(
          child: async.when(
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
            error: (e, _) => Center(child: Text(S.error(e), style: TextStyle(color: AppColors.current.danger))),
            data: (all) {
              final items = all.where((v) => v.deal == _deal).toList();
              if (items.isEmpty) {
                return _emptyBox(
                  isOffer
                      ? S.marketEmptyOffers(_deal.labelFor(widget.kind))
                      : S.marketEmptyDemands(_deal.labelFor(widget.kind)),
                  Icons.public_off_rounded,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => _MarketCard(view: items[i]),
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

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.view});

  final PublicListingView view;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: view.agentPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.cannotCall, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.current.danger,
        ),
      );
    }
  }

  /// Small icon + number, for the room and bathroom counts.
  Widget _feature(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.current.textMuted),
          const SizedBox(width: 4),
          Text(value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.current.textBody)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    final isOffer = view.kind == ListingKind.offer;
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
            HouseGallery(urls: view.imageUrls),
            // بەشی سەرەوە (جۆری موڵک و ڕووبەر)
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
                        view.propertyType.label,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.current.textStrong),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: AppColors.current.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              view.projectName,
                              style: TextStyle(color: AppColors.current.textMuted, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // تاگی فرۆشتن/کرێ و ڕووبەر
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DealBadge(deal: view.deal, kind: view.kind),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: inputFillColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.square_foot_rounded, size: 14, color: AppColors.current.textBody),
                          const SizedBox(width: 4),
                          Text(
                            S.areaSqm(view.area),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.current.textBody),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // نرخ و تایبەتمەندییەکان — ئەوەی کڕیار سەرەتا سەیری دەکات.
            if (view.priceLabel.isNotEmpty ||
                view.floors > 0 ||
                view.rooms > 0 ||
                view.bathrooms > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (view.priceLabel.isNotEmpty)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.payments_outlined,
                              size: 18, color: AppColors.current.success),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              view.priceLabel,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.current.success),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (view.floors > 0) ...[
                    _feature(Icons.layers_outlined, '${view.floors}'),
                    const SizedBox(width: 12),
                  ],
                  if (view.rooms > 0) ...[
                    _feature(Icons.bed_outlined, '${view.rooms}'),
                    const SizedBox(width: 12),
                  ],
                  if (view.bathrooms > 0)
                    _feature(Icons.bathtub_outlined, '${view.bathrooms}'),
                ],
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),

            // زانیاری بریکار (بەبێ ناوی خاوەن بۆ پاراستنی تایبەتمەندی)
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryDarkBlue.withValues(alpha: 0.05),
                  child: Icon(Icons.support_agent_rounded, size: 20, color: AppColors.current.textStrong),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.agentLabel,
                        style: TextStyle(fontSize: 11, color: AppColors.current.textMuted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        view.agentName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.current.textBody),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // دوگمەی پەیوەندیکردن (بە ڕەنگی سەوز بۆ خێرا تێگەیشتن)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.current.success, // ڕەنگی سەوزی مۆدێرن بۆ Call
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _call(context),
                icon: const Icon(Icons.phone_enabled_rounded, size: 20),
                label: Text(
                  S.callWithNumber(view.agentPhone),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  textDirection: TextDirection.ltr, // بۆ ئەوەی ژمارەکە تێک نەچێت
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}