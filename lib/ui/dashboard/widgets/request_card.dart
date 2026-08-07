import 'package:flutter/material.dart';

import '../../../models/property_model.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get modernGreen => AppColors.current.success;
Color get inputFillColor => AppColors.current.inputFill;

/// Compact card for a real demand/request listing (the company's own demands).
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.listing, this.matched = false});

  final PropertyListing listing;

  /// True when a matching offer exists → highlighted green.
  final bool matched;

  @override
  Widget build(BuildContext context) {
    // ڕێکخستنی ڕەنگەکان بەپێی ئەوەی موڵکێکی گونجاوی بۆ هەیە یان نا
    final Color accentColor = matched ? modernGreen : AppColors.current.textStrong;
    final Color bgColor = matched ? modernGreen.withValues(alpha: 0.06) : Colors.white;
    final Color borderColor = matched ? modernGreen.withValues(alpha: 0.3) : AppColors.current.divider;

    return Container(
      width: 260,
      margin: const EdgeInsetsDirectional.only(end: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.current.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ڕیزی سەرەوە: ئایکۆن، ناوی موشتەری، و تاگی (گونجاوە)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_search_rounded, size: 20, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  listing.ownerName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.current.textStrong),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (matched) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: modernGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.handshake_rounded, size: 12, color: modernGreen),
                      const SizedBox(width: 4),
                      Text(
                        S.matchedBadge,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: modernGreen),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // زانیاری داواکارییەکە
          Text(
            S.lookingFor(listing.propertyType.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.current.textBody, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 12),

          // تاگە بچووکەکان بۆ گەڕەک و ڕووبەر
          Row(
            children: [
              Expanded(
                child: _miniChip(Icons.location_on_outlined, listing.projectName),
              ),
              const SizedBox(width: 8),
              _miniChip(Icons.square_foot_rounded, S.areaSqm(listing.area)),
            ],
          ),
        ],
      ),
    );
  }

  // دیزاینی مۆدێرن بۆ تاگە بچووکەکان
  Widget _miniChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: inputFillColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.current.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.current.textBody),
          ),
        ),
      ],
    ),
  );
}