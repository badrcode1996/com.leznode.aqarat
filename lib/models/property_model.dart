import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// ===========================================================================
/// LISTINGS  (collections: `properties` = Offers, `requests` = Demands)
/// ===========================================================================
///
/// Both collections share the same shape, distinguished by [kind].
///
/// PRIVACY MODEL:
///   `ownerName` / `ownerMobile` are the tenant's private data and must NEVER
///   be shown in the Global Market. To avoid an extra read per card, the
///   creating user's name and their OWN phone are DENORMALIZED onto the
///   document (`agent_name`, `agent_phone`). The public view reads those
///   instead. See [PropertyListing.publicView].
class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.companyId,
    required this.agentId,
    required this.kind,
    required this.ownerName,
    required this.ownerMobile,
    required this.projectName,
    required this.propertyType,
    required this.area,
    required this.isPublic,
    required this.agentName,
    required this.agentPhone,
    required this.createdAt,
    this.isArchived = false,
    this.branch = '',
    this.imageUrl = '',
  });

  final String id;
  final String companyId;
  final String agentId;
  final ListingKind kind;

  // ----- PRIVATE: never expose in the Global Market -----
  final String ownerName; // ناوی خاوەن
  final String ownerMobile; // مۆبایلی خاوەن

  final String projectName; // پڕۆژە / گەرەک
  final PropertyType propertyType; // جۆری موڵک
  final num area; // ڕووبەر (م²)
  final bool isPublic;

  /// True once the listing is completed → moved to the archive section.
  final bool isArchived;

  /// Branch (لق) of the creating user — for branch-scoped admins.
  final String branch;

  // ----- DENORMALIZED public contact info (safe to expose) -----
  final String agentName;
  final String agentPhone; // the creating user's own phone

  final String imageUrl; // وێنەی خانوو (Storage download URL, optional)

  final DateTime createdAt;

  /// Normalized key used to match a demand against an offer.
  String get matchKey =>
      '${propertyType.wire}|${projectName.trim().toLowerCase()}';

  factory PropertyListing.fromJson(String id, Map<String, dynamic> json) {
    return PropertyListing(
      id: id,
      companyId: json['company_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      kind: ListingKind.fromWire(json['listing_kind'] as String?),
      ownerName: json['owner_name'] as String? ?? '',
      ownerMobile: json['owner_mobile'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      propertyType: PropertyType.fromWire(json['property_type'] as String?),
      area: json['area'] as num? ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      branch: json['branch'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? '',
      agentPhone: json['agent_phone'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      createdAt:
          (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'agent_id': agentId,
        'listing_kind': kind.wire,
        'owner_name': ownerName,
        'owner_mobile': ownerMobile,
        'project_name': projectName,
        'property_type': propertyType.wire,
        'area': area,
        'is_public': isPublic,
        'is_archived': isArchived,
        'branch': branch,
        'agent_name': agentName,
        'agent_phone': agentPhone,
        'image_url': imageUrl,
        'created_at': Timestamp.fromDate(createdAt),
      };

  /// Sanitized projection for the Global B2B Market. Owner identity is dropped;
  /// contact routes through the creating user's name + their own phone.
  PublicListingView get publicView => PublicListingView(
        id: id,
        kind: kind,
        propertyType: propertyType,
        projectName: projectName,
        area: area,
        agentName: agentName,
        agentPhone: agentPhone,
        imageUrl: imageUrl,
      );
}

/// Read-only, owner-free view rendered in the Global Market tab.
/// There is intentionally no `ownerName` / `ownerMobile` field here — the
/// privacy rule is enforced by the type, not by remembering to hide widgets.
class PublicListingView {
  const PublicListingView({
    required this.id,
    required this.kind,
    required this.propertyType,
    required this.projectName,
    required this.area,
    required this.agentName,
    required this.agentPhone,
    this.imageUrl = '',
  });

  final String id;
  final ListingKind kind;
  final PropertyType propertyType;
  final String projectName;
  final num area;
  final String agentName;
  final String agentPhone;
  final String imageUrl;
}
