import 'package:flutter/material.dart';

import '../../../models/property_model.dart';

/// Compact card for a real demand/request listing (the company's own demands).
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.listing, this.matched = false});

  final PropertyListing listing;

  /// True when a matching offer exists → highlighted green.
  final bool matched;

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = matched ? _green : scheme.primary;
    return Container(
      width: 250,
      margin: const EdgeInsetsDirectional.only(end: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: matched ? _green.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: matched
              ? _green.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(Icons.person_search, size: 18, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(listing.ownerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              if (matched)
                const Icon(Icons.handshake, size: 16, color: _green),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${listing.propertyType.label} لە ${listing.projectName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                  child: _miniChip(Icons.place_outlined, listing.projectName)),
              const SizedBox(width: 6),
              _miniChip(Icons.straighten, '${listing.area} م²'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.black54),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
}
