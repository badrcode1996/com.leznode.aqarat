import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/listing_repository.dart';
import '../../models/enums.dart';
import '../../models/property_model.dart';

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
        appBar: AppBar(
          title: const Text('بڵاوکراوەکانم'),
          bottom: const TabBar(
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
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('چالاک')),
              ButtonSegment(value: true, label: Text('ئەرشیف')),
            ],
            selected: {_showArchived},
            onSelectionChanged: (s) =>
                setState(() => _showArchived = s.first),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('هەڵە: $e')),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(_showArchived
                      ? 'ئەرشیف بەتاڵە'
                      : 'هیچ بڵاوکراوەیەکی چالاک نییە'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      await ref
          .read(listingRepositoryProvider)
          .setArchived(kind, listing.id, value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(value ? 'چووە ئەرشیف' : 'گەڕێندرایەوە')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('هەڵە: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Icon(
              kind == ListingKind.offer
                  ? Icons.home_work_outlined
                  : Icons.person_search,
              size: 20),
        ),
        title: Text(listing.ownerName),
        subtitle: Text(
            '${listing.propertyType.label} · ${listing.projectName} · ${listing.area} م²'),
        trailing: archived
            ? TextButton.icon(
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: const Text('گەڕاندنەوە'),
                onPressed: () => _setArchived(context, ref, false),
              )
            : FilledButton.tonalIcon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('تەواوکردن'),
                onPressed: () => _setArchived(context, ref, true),
              ),
      ),
    );
  }
}
