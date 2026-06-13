import 'package:flutter/material.dart';

import '../dummy_data.dart';

/// Compact card for an active client demand/request (horizontal list).
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});

  final DemandRequest request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 250,
      margin: const EdgeInsetsDirectional.only(end: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.person_search,
                    size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.clientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _miniChip(Icons.place_outlined, request.location),
              _miniChip(Icons.payments_outlined, request.budget),
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
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}
