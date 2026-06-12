import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';

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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('هەڵە: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('هیچ بڵاوکراوەیەکی گشتی نییە'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _MarketCard(view: items[i]),
        );
      },
    );
  }
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
        const SnackBar(content: Text('ناتوانرێت پەیوەندی بکرێت')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  view.kind == ListingKind.offer
                      ? Icons.home_work_outlined
                      : Icons.search,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  view.propertyType.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text('${view.area} m²'),
              ],
            ),
            const SizedBox(height: 4),
            Text('شوێن: ${view.location.label}'),
            const Divider(height: 20),
            // Owner is intentionally absent — only the agent + company phone.
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text('گوماشتە: ${view.agentName}')),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _call(context),
                icon: const Icon(Icons.call),
                label: Text('پەیوەندی: ${view.agentPhone}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
