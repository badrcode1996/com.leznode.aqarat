import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/property_model.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color modernGreen = Color(0xFF10B981);

/// Vertical list card for a real property listing (the company's own offers).
class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.listing, this.matched = false});

  final PropertyListing listing;

  /// True when a matching demand exists → highlighted green.
  final bool matched;

  static final _date = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context) {
    // گۆڕینی ڕەنگەکان بەپێی ئەوەی داواکارییەکەی گونجاوە یان نا
    final Color accentColor = matched ? modernGreen : primaryDarkBlue;
    final Color bgColor = matched ? modernGreen.withValues(alpha: 0.05) : Colors.white;
    final Color borderColor = matched ? modernGreen.withValues(alpha: 0.3) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: matched ? 1.5 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // وێنەی خانوو (ئەگەر هەبێت) یان ئایکۆن
            _thumb(accentColor),
            const SizedBox(width: 12),

            // زانیارییەکانی موڵک
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ڕیزی سەرەوە: تاگی (گشتی/ناوخۆیی) و ڕووبەر
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _chip(listing.isPublic),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              '${listing.area} م²',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // جۆری موڵک
                  Text(
                    listing.propertyType.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryDarkBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // ناونیشان / گەڕەک
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.projectName,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),

                  // ڕیزی خوارەوە: ناوی بریکار و بەروار
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: primaryDarkBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, size: 12, color: primaryDarkBlue),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          listing.agentName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _date.format(listing.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
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

  /// 84×84 thumbnail: the house photo when present, else an icon placeholder.
  Widget _thumb(Color accentColor) {
    final placeholder = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.maps_home_work_outlined, color: accentColor, size: 34),
    );
    if (listing.imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        listing.imageUrl,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (ctx, child, prog) => prog == null ? child : placeholder,
      ),
    );
  }

  // دیزاینی مۆدێرن بۆ تاگی (گشتی / ناوخۆیی)
  Widget _chip(bool isPublic) {
    final color = isPublic ? modernGreen : Colors.grey.shade600;
    final bgColor = isPublic ? modernGreen.withValues(alpha: 0.1) : Colors.grey.shade100;
    final icon = isPublic ? Icons.public : Icons.public_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'گشتی' : 'ناوخۆیی',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ڕەنگی فۆڕمەکان کە لە شاشەکانی تریش بەکارمان هێنا
const Color inputFillColor = Color(0xFFF3F4F6);