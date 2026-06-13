import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../dummy_data.dart';

/// Vertical list card for a recent property/offer.
class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.offer});

  final PropertyOffer offer;

  @override
  Widget build(BuildContext context) {
    final isRent = offer.type == ContractType.rent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            // Placeholder image.
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: offer.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.apartment, color: offer.accent, size: 34),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _typeChip(isRent),
                      const Spacer(),
                      Text(
                        offer.price,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isRent
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    offer.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 14, color: Colors.black45),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          offer.location,
                          style: const TextStyle(
                              fontSize: 12.5, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(offer.agentName,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const Spacer(),
                      Text(offer.timeAgo,
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

  Widget _typeChip(bool isRent) {
    final color = isRent ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isRent ? 'بۆ کرێ' : 'بۆ فرۆشتن',
        style: TextStyle(
            color: color, fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
