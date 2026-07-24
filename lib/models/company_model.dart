import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A tenant. (collection: `companies`, doc id == company_id == slug of English name)
///
/// The company name is multilingual (Kurdish / Arabic / English). The English
/// name is slugified and used as the document id so the data is human-readable
/// in the console (e.g. `companies/al_azud` instead of a random id).
///
/// `phone1`, `phone2`, `address`, and `logoUrl` are company identity used on
/// the printed contract (PDF header) — not the Global Market.
class Company {
  const Company({
    required this.id,
    required this.nameKu,
    required this.nameAr,
    required this.nameEn,
    required this.phone1,
    required this.phone2,
    required this.address,
    required this.logoUrl,
    required this.ownerUid,
    required this.createdAt,
    this.branches = const [],
    this.plan = CompanyPlan.bronze,
    this.webOnly = false,
    this.featureOverrides = const {},
    this.city = CompanyCity.erbil,
    this.demo = false,
    this.demoExpiresAt,
  });

  /// How long a demo profile stays usable once the Super Admin switches it on.
  static const demoDuration = Duration(days: 7);

  final String id;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final String phone1;
  final String phone2;
  final String address;
  final String logoUrl; // Firebase Storage download URL
  final String ownerUid; // the Company Admin who created it
  final DateTime createdAt;
  final List<String> branches; // لقەکان — branch names defined by Super Admin
  final CompanyPlan plan; // subscription tier (gates features)
  final bool webOnly; // when true, the mobile app blocks login (web only)

  /// Per-company feature overrides on top of the plan. key = feature name,
  /// value = forced on/off. Absent key → inherit the plan value.
  final Map<String, bool> featureOverrides;

  /// The city the company operates in — scopes the Global Market.
  final CompanyCity city;

  /// Trial account: usable only until [demoExpiresAt], after which every screen
  /// is blocked and the security rules stop serving the company's data.
  final bool demo;

  /// When the trial runs out. Set to now + [demoDuration] the moment [demo] is
  /// switched on, so re-enabling restarts the week. Null while [demo] is false.
  final DateTime? demoExpiresAt;

  /// True once a demo company's week is up. A demo with no expiry stored is
  /// treated as expired rather than unlimited — the safe direction to fail.
  bool get demoExpired =>
      demo && !DateTime.now().isBefore(demoExpiresAt ?? DateTime(0));

  /// Whole days left on the trial, floored at zero. Null when not a demo.
  int? get demoDaysLeft {
    if (!demo) return null;
    final left = (demoExpiresAt ?? DateTime(0)).difference(DateTime.now());
    return left.isNegative ? 0 : left.inDays;
  }

  /// Preferred label for the UI: Kurdish first, then Arabic, then English.
  String get displayName =>
      nameKu.isNotEmpty ? nameKu : (nameAr.isNotEmpty ? nameAr : nameEn);

  factory Company.fromJson(String id, Map<String, dynamic> json) => Company(
        id: id,
        nameKu: json['name_ku'] as String? ?? json['name'] as String? ?? '',
        nameAr: json['name_ar'] as String? ?? '',
        nameEn: json['name_en'] as String? ?? '',
        phone1: json['phone1'] as String? ?? json['phone'] as String? ?? '',
        phone2: json['phone2'] as String? ?? '',
        address: json['address'] as String? ?? '',
        logoUrl: json['logo_url'] as String? ?? '',
        ownerUid: json['owner_uid'] as String? ?? '',
        createdAt:
            (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        branches: (json['branches'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        plan: CompanyPlan.fromWire(json['plan'] as String?),
        webOnly: json['web_only'] as bool? ?? false,
        featureOverrides: (json['feature_overrides'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v as bool),
            ) ??
            const {},
        city: CompanyCity.fromWire(json['city'] as String?),
        demo: json['demo'] as bool? ?? false,
        demoExpiresAt: (json['demo_expires_at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toJson() => {
        'name_ku': nameKu,
        'name_ar': nameAr,
        'name_en': nameEn,
        'phone1': phone1,
        'phone2': phone2,
        'address': address,
        'logo_url': logoUrl,
        'owner_uid': ownerUid,
        'created_at': Timestamp.fromDate(createdAt),
        'branches': branches,
        'plan': plan.wire,
        'web_only': webOnly,
        'feature_overrides': featureOverrides,
        'city': city.wire,
        'demo': demo,
        'demo_expires_at':
            demoExpiresAt == null ? null : Timestamp.fromDate(demoExpiresAt!),
      };

  /// Turns an English company name into a safe, readable Firestore document id.
  /// e.g. "Al Azud Real Estate" -> "al_azud_real_estate".
  /// Returns '' if nothing usable remains (caller should reject).
  static String slugify(String englishName) {
    final lower = englishName.trim().toLowerCase();
    final underscored = lower.replaceAll(RegExp(r'\s+'), '_');
    final cleaned = underscored.replaceAll(RegExp(r'[^a-z0-9_-]'), '');
    return cleaned
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
  }
}
