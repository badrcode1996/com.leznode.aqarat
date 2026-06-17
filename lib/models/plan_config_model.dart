import 'enums.dart';

/// The feature set + limits for ONE plan tier. Edited by the Super Admin and
/// stored in Firestore (`config/plans`), read live by the app for gating.
///
/// `maxBranches` / `maxUsers` use 0 to mean "unlimited". Core features (tenants,
/// rent contracts, rent + external receipts) are always on and not listed here.
class PlanFeatures {
  const PlanFeatures({
    this.sale = true,
    this.overdue = false,
    this.market = false,
    this.offers = false,
    this.requests = false,
    this.lawyers = false,
    this.maxBranches = 0,
    this.maxUsers = 0,
    this.webOnly = false,
  });

  final bool sale; // گرێبەستی فرۆشتن
  final bool overdue; // ئاگاداری کرێی دواکەوتوو
  final bool market; // بازاڕی گشتی
  final bool offers; // خستنەڕووی موڵک
  final bool requests; // داواکاری موشتەری
  final bool lawyers; // پارێزەران
  final int maxBranches; // 0 = unlimited
  final int maxUsers; // 0 = unlimited
  final bool webOnly; // platform = web only

  bool get unlimitedBranches => maxBranches <= 0;
  bool get unlimitedUsers => maxUsers <= 0;

  factory PlanFeatures.fromJson(Map<String, dynamic> j) => PlanFeatures(
        sale: j['sale'] as bool? ?? true,
        overdue: j['overdue'] as bool? ?? false,
        market: j['market'] as bool? ?? false,
        offers: j['offers'] as bool? ?? false,
        requests: j['requests'] as bool? ?? false,
        lawyers: j['lawyers'] as bool? ?? false,
        maxBranches: (j['max_branches'] as num?)?.toInt() ?? 0,
        maxUsers: (j['max_users'] as num?)?.toInt() ?? 0,
        webOnly: j['web_only'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'sale': sale,
        'overdue': overdue,
        'market': market,
        'offers': offers,
        'requests': requests,
        'lawyers': lawyers,
        'max_branches': maxBranches,
        'max_users': maxUsers,
        'web_only': webOnly,
      };

  /// The feature keys a company can override on top of its plan (limits +
  /// webOnly are not per-feature overridable here).
  static const overridableKeys = [
    'sale',
    'overdue',
    'market',
    'offers',
    'requests',
    'lawyers',
  ];

  /// Returns these features with any per-company overrides applied. A key
  /// present in [overrides] forces that feature on/off; an absent key inherits
  /// the plan value.
  PlanFeatures applyOverrides(Map<String, bool> overrides) {
    if (overrides.isEmpty) return this;
    return copyWith(
      sale: overrides['sale'],
      overdue: overrides['overdue'],
      market: overrides['market'],
      offers: overrides['offers'],
      requests: overrides['requests'],
      lawyers: overrides['lawyers'],
    );
  }

  PlanFeatures copyWith({
    bool? sale,
    bool? overdue,
    bool? market,
    bool? offers,
    bool? requests,
    bool? lawyers,
    int? maxBranches,
    int? maxUsers,
    bool? webOnly,
  }) =>
      PlanFeatures(
        sale: sale ?? this.sale,
        overdue: overdue ?? this.overdue,
        market: market ?? this.market,
        offers: offers ?? this.offers,
        requests: requests ?? this.requests,
        lawyers: lawyers ?? this.lawyers,
        maxBranches: maxBranches ?? this.maxBranches,
        maxUsers: maxUsers ?? this.maxUsers,
        webOnly: webOnly ?? this.webOnly,
      );
}

/// The full Bronze/Silver/Gold configuration.
class PlanConfig {
  const PlanConfig({
    required this.bronze,
    required this.silver,
    required this.gold,
  });

  final PlanFeatures bronze;
  final PlanFeatures silver;
  final PlanFeatures gold;

  PlanFeatures forPlan(CompanyPlan plan) => switch (plan) {
        CompanyPlan.bronze => bronze,
        CompanyPlan.silver => silver,
        CompanyPlan.gold => gold,
      };

  PlanConfig withPlan(CompanyPlan plan, PlanFeatures features) => PlanConfig(
        bronze: plan == CompanyPlan.bronze ? features : bronze,
        silver: plan == CompanyPlan.silver ? features : silver,
        gold: plan == CompanyPlan.gold ? features : gold,
      );

  /// Built-in defaults — mirror the agreed matrix. Used until the Super Admin
  /// saves a custom config (or as a fallback if the doc is missing).
  static const defaults = PlanConfig(
    bronze: PlanFeatures(
      sale: true,
      overdue: false,
      market: false,
      offers: false,
      requests: false,
      lawyers: false,
      maxBranches: 1,
      maxUsers: 2,
      webOnly: true,
    ),
    silver: PlanFeatures(
      sale: true,
      overdue: true,
      market: true,
      offers: true,
      requests: true,
      lawyers: false,
      maxBranches: 3,
      maxUsers: 5,
      webOnly: false,
    ),
    gold: PlanFeatures(
      sale: true,
      overdue: true,
      market: true,
      offers: true,
      requests: true,
      lawyers: true,
      maxBranches: 0,
      maxUsers: 0,
      webOnly: false,
    ),
  );

  factory PlanConfig.fromJson(Map<String, dynamic> j) => PlanConfig(
        bronze: j['bronze'] is Map
            ? PlanFeatures.fromJson((j['bronze'] as Map).cast<String, dynamic>())
            : defaults.bronze,
        silver: j['silver'] is Map
            ? PlanFeatures.fromJson((j['silver'] as Map).cast<String, dynamic>())
            : defaults.silver,
        gold: j['gold'] is Map
            ? PlanFeatures.fromJson((j['gold'] as Map).cast<String, dynamic>())
            : defaults.gold,
      );

  Map<String, dynamic> toJson() => {
        'bronze': bronze.toJson(),
        'silver': silver.toJson(),
        'gold': gold.toJson(),
      };
}
