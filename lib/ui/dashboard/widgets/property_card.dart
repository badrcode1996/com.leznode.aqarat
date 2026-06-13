import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/property_model.dart';

/// Vertical list card for a real property listing (the company's own offers).
class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.listing, this.matched = false});

  final PropertyListing listing;

  /// True when a matching demand exists → highlighted green.
  final bool matched;

  static const _green = Color(0xFF2E7D32);
  static final _date = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context) {
    final accent = matched ? _green : Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: matched ? _green.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: matched
            ? Border.all(color: _green.withValues(alpha: 0.5))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.apartment, color: accent, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _chip(listing.isPublic),
                      const Spacer(),
                      Text('${listing.area} م²',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: accent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(listing.propertyType.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 14, color: Colors.black45),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(listing.projectName,
                            style: const TextStyle(
                                fontSize: 12.5, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(listing.agentName,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const Spacer(),
                      Text(_date.format(listing.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black38)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(bool isPublic) {
    final color = isPublic ? const Color(0xFF2E7D32) : const Color(0xFF6A6A6A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(isPublic ? 'گشتی' : 'ناوخۆیی',
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.bold)),
    );
  }
}
