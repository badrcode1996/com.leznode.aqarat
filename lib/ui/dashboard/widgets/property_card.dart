import 'package:flutter/material.dart';
// intl exports its own TextDirection, which would shadow the Flutter one used
// to keep the room/photo counts reading left-to-right inside the RTL layout.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../models/property_model.dart';
import '../../widgets/deal_filter_bar.dart';
import '../../widgets/house_cover_image.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get modernGreen => AppColors.current.success;

/// Vertical list card for a real property listing (the company's own offers).
class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.listing, this.matched = false});

  final PropertyListing listing;

  /// True when a matching demand exists → highlighted green.
  final bool matched;

  static final _date = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    // گۆڕینی ڕەنگەکان بەپێی ئەوەی داواکارییەکەی گونجاوە یان نا
    final Color accentColor = matched ? modernGreen : AppColors.current.textStrong;
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
            color: AppColors.current.shadow,
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
                  // ڕیزی سەرەوە: تاگی (فرۆشتن/کرێ) و ڕووبەر
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DealBadge(deal: listing.deal, kind: listing.kind),
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
                            Icon(Icons.square_foot_rounded, size: 14, color: AppColors.current.textBody),
                            const SizedBox(width: 4),
                            Text(
                              S.areaSqm(listing.area),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.current.textBody,
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
                      color: AppColors.current.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // نرخ — گرنگترین زانیاری کارتەکە، بۆیە لە سەرەوە و
                  // بەرچاوترە. بەتاڵ دەبێت ئەگەر نرخ دیاری نەکرابێت.
                  if (listing.priceLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      listing.priceLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.current.success,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),

                  // قات، ژوور و حەمام — تەنها ئەوانەی دیاریکراون
                  if (listing.floors > 0 ||
                      listing.rooms > 0 ||
                      listing.bathrooms > 0) ...[
                    Wrap(
                      spacing: 12,
                      children: [
                        if (listing.floors > 0)
                          _feature(Icons.layers_outlined, '${listing.floors}'),
                        if (listing.rooms > 0)
                          _feature(Icons.bed_outlined, '${listing.rooms}'),
                        if (listing.bathrooms > 0)
                          _feature(
                              Icons.bathtub_outlined, '${listing.bathrooms}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // ناونیشان / گەڕەک
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppColors.current.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.projectName,
                          style: TextStyle(fontSize: 13, color: AppColors.current.textMuted),
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
                        child: Icon(Icons.person, size: 12, color: AppColors.current.textStrong),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          listing.agentName,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.current.textBody),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: AppColors.current.textFaint),
                      const SizedBox(width: 4),
                      Text(
                        _date.format(listing.createdAt),
                        style: TextStyle(fontSize: 11, color: AppColors.current.textMuted),
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

  /// Small icon + number, for the room and bathroom counts.
  Widget _feature(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.current.textMuted),
          const SizedBox(width: 3),
          Text(value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.current.textBody)),
        ],
      );

  /// 84×84 thumbnail: the cover photo when present, else an icon placeholder.
  /// A badge shows the total when the listing carries more than one photo, so
  /// the compact card still advertises the gallery behind it.
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
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          HouseThumb(
              url: listing.coverUrl, size: 84, placeholder: placeholder),
          if (listing.imageUrls.length > 1)
            PositionedDirectional(
              end: 4,
              bottom: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('${listing.imageUrls.length}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ڕەنگی فۆڕمەکان کە لە شاشەکانی تریش بەکارمان هێنا
Color get inputFillColor => AppColors.current.inputFill;