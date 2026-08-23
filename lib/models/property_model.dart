import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import 'enums.dart';

/// How many photos one listing may carry. Enough for a full walk-through
/// without turning a card into a download.
const int kMaxListingImages = 10;

final NumberFormat _money = NumberFormat.decimalPattern();

/// The price as shown on cards and in the market — empty when unpriced, so
/// callers can simply skip the widget. Rent is labelled per month, since the
/// same field means a very different number on a sale.
String formatListingPrice(num price, Currency currency, DealKind deal) {
  if (price <= 0) return '';
  final base = '${_money.format(price)} ${currency.uiSymbol}';
  return deal == DealKind.rent ? S.perMonth(base) : base;
}

/// One picture in a listing's gallery: either one already stored (carrying its
/// download URL) or one just picked on the device (carrying its bytes).
///
/// The form works in this type end to end, so re-ordering, adding and removing
/// photos is plain list manipulation and the repository can diff the result
/// against what was stored to know what to upload and what to delete.
class ListingImage {
  const ListingImage.stored(this.url)
      : bytes = null,
        contentType = '';

  const ListingImage.picked(this.bytes, this.contentType) : url = '';

  /// Set for an already-uploaded photo; empty for a fresh pick.
  final String url;

  /// Set for a fresh pick; null for an already-uploaded photo.
  final Uint8List? bytes;
  final String contentType;

  bool get isNew => bytes != null;
}

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
    required this.deal,
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
    this.imageUrls = const [],
    this.city = CompanyCity.erbil,
    this.price = 0,
    this.currency = Currency.usd,
    this.rooms = 0,
    this.bathrooms = 0,
    this.floors = 0,
    this.lat,
    this.lng,
  });

  final String id;
  final String companyId;
  final String agentId;
  final ListingKind kind;

  /// Selling or renting — see [DealKind]. Splits each of the two sections.
  final DealKind deal;

  // ----- PRIVATE: never expose in the Global Market -----
  final String ownerName; // ناوی خاوەن
  final String ownerMobile; // مۆبایلی خاوەن

  final String projectName; // پڕۆژە / گەڕەک
  final PropertyType propertyType; // جۆری موڵک
  final num area; // ڕووبەر (م²)
  final bool isPublic;

  /// Asking price (sale) or monthly rent — 0 when the owner hasn't named one.
  /// Kept as a bare number plus [currency] rather than a formatted string, so
  /// it stays sortable and filterable.
  final num price;
  final Currency currency;

  /// Rooms (ژوور), bathrooms (حەمام) and storeys (قات). 0 means "not stated"
  /// and the cards leave the chip out — land legitimately has none of them.
  final int rooms;
  final int bathrooms;
  final int floors;

  // ----- PRIVATE: never expose in the Global Market -----
  /// Where the property actually stands. Null when nobody has pinned it —
  /// most listings are typed up at a desk, and a wrong pin is worse than none.
  ///
  /// Deliberately absent from [publicView], alongside the owner's name and
  /// phone. The market hides those so another company cannot go round the
  /// agent to the owner; an exact position on a map hands back the same thing
  /// by another route, since the owner is findable at the address.
  final double? lat;
  final double? lng;

  /// True once both halves of the pin are present. Either alone is a
  /// half-written document, and would put the property in the Gulf of Guinea.
  bool get hasLocation => lat != null && lng != null;

  /// True once the listing is completed → moved to the archive section.
  final bool isArchived;

  /// Branch (لق) of the creating user — for branch-scoped admins.
  final String branch;

  // ----- DENORMALIZED public contact info (safe to expose) -----
  final String agentName;
  final String agentPhone; // the creating user's own phone

  /// Photo gallery, cover first (Storage download URLs). Capped at
  /// [kMaxListingImages] by the form.
  final List<String> imageUrls;

  /// The card thumbnail — the first photo, or empty when there are none.
  String get coverUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  /// Denormalized from the creating company so the Global Market can be scoped
  /// to a city without an extra read per listing.
  final CompanyCity city;

  final DateTime createdAt;

  /// Normalized key used to match a demand against an offer.
  String get matchKey =>
      '${propertyType.wire}|${projectName.trim().toLowerCase()}';

  /// Formatted price for the cards, or empty when unpriced.
  String get priceLabel => formatListingPrice(price, currency, deal);

  /// Reads the gallery, falling back to the single `image_url` that listings
  /// written before the gallery existed carry. Doing it here means no screen
  /// has to know two shapes.
  static List<String> imagesFrom(Map<String, dynamic> json) {
    final list = json['image_urls'] as List<dynamic>?;
    if (list != null) return list.cast<String>();
    final single = json['image_url'] as String? ?? '';
    return single.isEmpty ? const [] : [single];
  }

  factory PropertyListing.fromJson(String id, Map<String, dynamic> json) {
    return PropertyListing(
      id: id,
      companyId: json['company_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      kind: ListingKind.fromWire(json['listing_kind'] as String?),
      deal: DealKind.fromWire(json['deal_kind'] as String?),
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
      imageUrls: imagesFrom(json),
      city: CompanyCity.fromWire(json['city'] as String?),
      price: json['price'] as num? ?? 0,
      currency: Currency.fromWire(json['currency'] as String?),
      rooms: (json['rooms'] as num?)?.toInt() ?? 0,
      bathrooms: (json['bathrooms'] as num?)?.toInt() ?? 0,
      floors: (json['floors'] as num?)?.toInt() ?? 0,
      // Read as a pair: a document carrying only one half is treated as
      // unpinned rather than as a point on the equator.
      lat: _coord(json['lat'], json['lng'], 90),
      lng: _coord(json['lng'], json['lat'], 180),
      createdAt:
          (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// One half of a stored pin, or null unless [other] is a usable number too.
  /// [max] is the half's own range — 90 for a latitude, 180 for a longitude —
  /// so a bad write cannot leave a point the map cannot show.
  static double? _coord(Object? value, Object? other, num max) {
    if (value is! num || other is! num) return null;
    final d = value.toDouble();
    if (d.isNaN || d.abs() > max) return null;
    return d;
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'agent_id': agentId,
        'listing_kind': kind.wire,
        'deal_kind': deal.wire,
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
        'image_urls': imageUrls,
        // The cover is written to the old single-image field as well: a client
        // still running the previous build reads only this one, and would show
        // a listing with photos as having none.
        'image_url': coverUrl,
        'city': city.wire,
        'price': price,
        'currency': currency.wire,
        'rooms': rooms,
        'bathrooms': bathrooms,
        'floors': floors,
        // Written as a pair or not at all, which is what fromJson reads back.
        'lat': hasLocation ? lat : null,
        'lng': hasLocation ? lng : null,
        'created_at': Timestamp.fromDate(createdAt),
      };

  /// Sanitized projection for the Global B2B Market. Owner identity is dropped;
  /// contact routes through the creating user's name + their own phone.
  PublicListingView get publicView => PublicListingView(
        id: id,
        kind: kind,
        deal: deal,
        propertyType: propertyType,
        projectName: projectName,
        area: area,
        agentName: agentName,
        agentPhone: agentPhone,
        imageUrls: imageUrls,
        price: price,
        currency: currency,
        rooms: rooms,
        bathrooms: bathrooms,
        floors: floors,
      );
}

/// Read-only, owner-free view rendered in the Global Market tab.
/// There is intentionally no `ownerName` / `ownerMobile` field here — the
/// privacy rule is enforced by the type, not by remembering to hide widgets.
class PublicListingView {
  const PublicListingView({
    required this.id,
    required this.kind,
    required this.deal,
    required this.propertyType,
    required this.projectName,
    required this.area,
    required this.agentName,
    required this.agentPhone,
    this.imageUrls = const [],
    this.price = 0,
    this.currency = Currency.usd,
    this.rooms = 0,
    this.bathrooms = 0,
    this.floors = 0,
  });

  /// Builds the view from a `market` document (the public, owner-free
  /// projection stored separately so private owner data is never readable
  /// cross-company).
  factory PublicListingView.fromMarket(String id, Map<String, dynamic> j) =>
      PublicListingView(
        id: id,
        kind: ListingKind.fromWire(j['listing_kind'] as String?),
        deal: DealKind.fromWire(j['deal_kind'] as String?),
        propertyType: PropertyType.fromWire(j['property_type'] as String?),
        projectName: j['project_name'] as String? ?? '',
        area: j['area'] as num? ?? 0,
        agentName: j['agent_name'] as String? ?? '',
        agentPhone: j['agent_phone'] as String? ?? '',
        imageUrls: PropertyListing.imagesFrom(j),
        price: j['price'] as num? ?? 0,
        currency: Currency.fromWire(j['currency'] as String?),
        rooms: (j['rooms'] as num?)?.toInt() ?? 0,
        bathrooms: (j['bathrooms'] as num?)?.toInt() ?? 0,
        floors: (j['floors'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final ListingKind kind;
  final DealKind deal;
  final PropertyType propertyType;
  final String projectName;
  final num area;
  final String agentName;
  final String agentPhone;
  final List<String> imageUrls;
  final num price;
  final Currency currency;
  final int rooms;
  final int bathrooms;
  final int floors;

  String get coverUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  String get priceLabel => formatListingPrice(price, currency, deal);
}
