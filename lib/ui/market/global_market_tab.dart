import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';
import '../widgets/house_cover_image.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color inputFillColor = Color(0xFFF3F4F6);

/// Global B2B Market — shows public listings from ALL companies.
///
/// PRIVACY: it binds to [globalMarketProvider] which yields [PublicListingView]
/// (no owner name/mobile). Contact is the creating agent + company phone, with
/// a url_launcher "Click to Call" button.
class GlobalMarketTab extends ConsumerWidget {
  const GlobalMarketTab({super.key, this.kind = ListingKind.offer});

  final ListingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(globalMarketProvider(kind));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
      error: (e, _) => Center(child: Text('هەڵە: $e', style: const TextStyle(color: Colors.red))),
      data: (items) {
        if (items.isEmpty) {
          return _emptyBox(
            kind == ListingKind.offer ? 'هیچ خستنەڕوویەک لە بازاڕی گشتیدا نییە' : 'هیچ داواکارییەک لە بازاڕی گشتیدا نییە',
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
          content: const Text('ناتوانرێت پەیوەندی بکرێت', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffer = view.kind == ListingKind.offer;
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
            // وێنەی خانوو (ئەگەر هەبێت)
            HouseCoverImage(url: view.imageUrl),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryDarkBlue),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              view.projectName,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // تاگی ڕووبەر
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: inputFillColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.square_foot_rounded, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${view.area} م²',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),

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
                  child: const Icon(Icons.support_agent_rounded, size: 20, color: primaryDarkBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نوێنەر / بریکار',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        view.agentName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
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
                  backgroundColor: const Color(0xFF10B981), // ڕەنگی سەوزی مۆدێرن بۆ Call
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _call(context),
                icon: const Icon(Icons.phone_enabled_rounded, size: 20),
                label: Text(
                  'پەیوەندی بکە (${view.agentPhone})',
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