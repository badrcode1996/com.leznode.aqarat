import 'enums.dart';

/// The feature set + limits for ONE plan tier. Edited by the Super Admin and
/// stored in Firestore (`config/plans`), read live by the app for gating.
///
/// `maxBranches` / `maxUsers` use 0 to mean "unlimited". Core features are
/// always on and not gated: tenants, BOTH rent and sale contracts, and the
/// rent + external receipts. `sale` is kept on the model for backward
/// compatibility with saved configs, but nothing reads it any more.
class PlanFeatures {
  const PlanFeatures({
    this.sale = true,
    this.overdue = false,
    this.market = false,
    this.offers = false,
    this.requests = false,
    this.lawyers = false,
    this.guarantees = false,
    this.commission = false,
    this.arabicContracts = false,
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
  final bool guarantees; // کۆی دڵنیایی (guarantee/deposit totals)
  final bool commission; // کۆی عمولە (sale-contract commission totals)
  final bool arabicContracts; // گرێبەستی عەرەبی (Arabic contract PDF)
  final int maxBranches; // 0 = unlimited
  final int maxUsers; // 0 = unlimited
  final bool webOnly; // platform = web only

  bool get unlimitedBranches => maxBranches <= 0;
  bool get unlimitedUsers => maxUsers <= 0;

  /// [fallback] is the shipped matrix for THIS tier, and is what an absent key
  /// resolves to.
  ///
  /// This matters every time a new feature ships: a config saved before the key
  /// existed has no opinion about it, and defaulting those to `false` silently
  /// switched the feature off for every tenant until a Super Admin re-saved the
  /// screen. Inheriting the tier's default instead means a new feature reaches
  /// the plans it was written for on deploy, while every value the Super Admin
  /// actually chose still wins.
  factory PlanFeatures.fromJson(Map<String, dynamic> j,
          [PlanFeatures fallback = const PlanFeatures()]) =>
      PlanFeatures(
        sale: j['sale'] as bool? ?? fallback.sale,
        overdue: j['overdue'] as bool? ?? fallback.overdue,
        market: j['market'] as bool? ?? fallback.market,
        offers: j['offers'] as bool? ?? fallback.offers,
        requests: j['requests'] as bool? ?? fallback.requests,
        lawyers: j['lawyers'] as bool? ?? fallback.lawyers,
        guarantees: j['guarantees'] as bool? ?? fallback.guarantees,
        commission: j['commission'] as bool? ?? fallback.commission,
        arabicContracts:
            j['arabic_contracts'] as bool? ?? fallback.arabicContracts,
        maxBranches: (j['max_branches'] as num?)?.toInt() ?? fallback.maxBranches,
        maxUsers: (j['max_users'] as num?)?.toInt() ?? fallback.maxUsers,
        webOnly: j['web_only'] as bool? ?? fallback.webOnly,
      );

  Map<String, dynamic> toJson() => {
        'sale': sale,
        'overdue': overdue,
        'market': market,
        'offers': offers,
        'requests': requests,
        'lawyers': lawyers,
        'guarantees': guarantees,
        'commission': commission,
        'arabic_contracts': arabicContracts,
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
    'guarantees',
    'commission',
    'arabic_contracts',
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
      guarantees: overrides['guarantees'],
      commission: overrides['commission'],
      arabicContracts: overrides['arabic_contracts'],
    );
  }

  PlanFeatures copyWith({
    bool? sale,
    bool? overdue,
    bool? market,
    bool? offers,
    bool? requests,
    bool? lawyers,
    bool? guarantees,
    bool? commission,
    bool? arabicContracts,
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
        guarantees: guarantees ?? this.guarantees,
        commission: commission ?? this.commission,
        arabicContracts: arabicContracts ?? this.arabicContracts,
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
    required this.diamond,
  });

  final PlanFeatures bronze;
  final PlanFeatures silver;
  final PlanFeatures gold;
  final PlanFeatures diamond;

  PlanFeatures forPlan(CompanyPlan plan) => switch (plan) {
        CompanyPlan.bronze => bronze,
        CompanyPlan.silver => silver,
        CompanyPlan.gold => gold,
        CompanyPlan.diamond => diamond,
      };

  PlanConfig withPlan(CompanyPlan plan, PlanFeatures features) => PlanConfig(
        bronze: plan == CompanyPlan.bronze ? features : bronze,
        silver: plan == CompanyPlan.silver ? features : silver,
        gold: plan == CompanyPlan.gold ? features : gold,
        diamond: plan == CompanyPlan.diamond ? features : diamond,
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
      // Every plan ships on web AND mobile. web_only survives as a per-company
      // switch the Super Admin can still flip, but no plan turns it on.
      webOnly: false,
    ),
    silver: PlanFeatures(
      sale: true,
      overdue: true,
      market: true,
      offers: true,
      requests: true,
      lawyers: false,
      // Arabic contracts are sold from Silver up — Bronze stays Kurdish-only.
      arabicContracts: true,
      // Multiple branches are a Gold-only feature; Bronze and Silver run as a
      // single branch.
      maxBranches: 1,
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
      guarantees: true,
      commission: true,
      arabicContracts: true,
      maxBranches: 0,
      maxUsers: 0,
      webOnly: false,
    ),
    // Diamond = the top/custom tier: everything on + unlimited by default; the
    // Super Admin tailors it per company via feature overrides.
    diamond: PlanFeatures(
      sale: true,
      overdue: true,
      market: true,
      offers: true,
      requests: true,
      lawyers: true,
      guarantees: true,
      commission: true,
      arabicContracts: true,
      maxBranches: 0,
      maxUsers: 0,
      webOnly: false,
    ),
  );

  // Each tier is parsed against its OWN shipped defaults, so a key the stored
  // document predates inherits what that tier was meant to have.
  factory PlanConfig.fromJson(Map<String, dynamic> j) => PlanConfig(
        bronze: j['bronze'] is Map
            ? PlanFeatures.fromJson(
                (j['bronze'] as Map).cast<String, dynamic>(), defaults.bronze)
            : defaults.bronze,
        silver: j['silver'] is Map
            ? PlanFeatures.fromJson(
                (j['silver'] as Map).cast<String, dynamic>(), defaults.silver)
            : defaults.silver,
        gold: j['gold'] is Map
            ? PlanFeatures.fromJson(
                (j['gold'] as Map).cast<String, dynamic>(), defaults.gold)
            : defaults.gold,
        diamond: j['diamond'] is Map
            ? PlanFeatures.fromJson(
                (j['diamond'] as Map).cast<String, dynamic>(), defaults.diamond)
            : defaults.diamond,
      );

  Map<String, dynamic> toJson() => {
        'bronze': bronze.toJson(),
        'silver': silver.toJson(),
        'gold': gold.toJson(),
        'diamond': diamond.toJson(),
      };
}
