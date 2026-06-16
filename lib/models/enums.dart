/// Centralized enums used across the data layer.
///
/// All enums serialize to/from their stable `wire` string so that the value
/// stored in Firestore never depends on the Dart enum index (which can shift
/// when reordering). Dropdown labels are kept separate from the wire value.
library;

/// Application roles. Drives both routing and query scoping.
enum UserRole {
  superAdmin('super_admin'), // Us — manages subscriptions across all tenants.
  companyAdmin('company_admin'), // Company-wide stats + all agents.
  agent('agent'); // Creates contracts, sees only their own stats.

  const UserRole(this.wire);
  final String wire;

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
        (r) => r.wire == value,
        orElse: () => UserRole.agent,
      );
}

/// Subscription tier sold to a company. Higher tiers unlock more features.
///
/// The feature getters below are the SINGLE SOURCE OF TRUTH for what each plan
/// can do — they are mirrored in `firestore.rules` (planAtLeast). Change both
/// together.
enum CompanyPlan {
  bronze('bronze', 'بڕۆنز'),
  silver('silver', 'سیلڤەر'),
  gold('gold', 'گۆڵد');

  const CompanyPlan(this.wire, this.label);
  final String wire;
  final String label;

  static CompanyPlan fromWire(String? value) => CompanyPlan.values.firstWhere(
        (p) => p.wire == value,
        orElse: () => CompanyPlan.bronze,
      );

  int get _rank => switch (this) {
        CompanyPlan.bronze => 0,
        CompanyPlan.silver => 1,
        CompanyPlan.gold => 2,
      };

  bool atLeast(CompanyPlan min) => _rank >= min._rank;

  // ----- Feature gates (mirror in firestore.rules) -----
  /// Sale contracts (گرێبەستی فرۆشتن).
  bool get canSaleContracts => atLeast(CompanyPlan.silver);

  /// Listings + requests + the Global Market (خستنەڕوو/داواکاری/بازاڕ).
  bool get canListings => atLeast(CompanyPlan.silver);

  /// Lawyers directory (پارێزەران).
  bool get canLawyers => atLeast(CompanyPlan.gold);

  /// Custom per-company contract template (تێمپلەیتی تایبەت).
  bool get canCustomTemplate => atLeast(CompanyPlan.gold);
}

/// The four receipt (وەصڵ) kinds. `isPayment` flips the person label to
/// "Paid To" (صرف); `isRent` ties the receipt to a rent contract installment.
enum ReceiptType {
  externalReceive('external_receive', 'پسولەی پارە وەرگرتن', 'وصل قبض',
      'RECEIPT VOUCHER'),
  externalPay('external_pay', 'پسولەی پارەدان', 'وصل صرف', 'PAYMENT VOUCHER'),
  rentReceive('rent_receive', 'پسولەی وەرگرتنی کرێ', 'وصل قبض الإيجار',
      'RENT RECEIPT'),
  rentPay('rent_pay', 'پسولەی دانەوەی کرێ', 'وصل صرف الإيجار', 'RENT PAYMENT');

  const ReceiptType(this.wire, this.titleKu, this.titleAr, this.titleEn);
  final String wire;
  final String titleKu;
  final String titleAr;
  final String titleEn;

  bool get isPayment => this == externalPay || this == rentPay;
  bool get isRent => this == rentReceive || this == rentPay;

  static ReceiptType fromWire(String? value) => ReceiptType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => ReceiptType.externalReceive,
      );
}

/// Currency used on a contract.
enum Currency {
  iqd('IQD', 'دیناری عێراقی'),
  usd('USD', 'دۆلاری ئەمریکی');

  const Currency(this.wire, this.label);
  final String wire;
  final String label;

  static Currency fromWire(String? value) => Currency.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => Currency.iqd,
      );
}

/// Contract type discriminator stored as `contract_type`.
enum ContractType {
  rent('rent'),
  sale('sale');

  const ContractType(this.wire);
  final String wire;

  static ContractType fromWire(String? value) => ContractType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => ContractType.rent,
      );
}

/// Lifecycle of a single rent installment.
/// 0 = pending, 1 = received from tenant, 2 = delivered to owner.
enum PaymentStatus {
  pending(0),
  receivedFromTenant(1),
  deliveredToOwner(2);

  const PaymentStatus(this.code);
  final int code;

  static PaymentStatus fromCode(int? code) => PaymentStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => PaymentStatus.pending,
      );
}

/// Whether a listing is an Offer (`properties`) or a Demand (`requests`).
enum ListingKind {
  offer('offer'),
  demand('demand');

  const ListingKind(this.wire);
  final String wire;

  static ListingKind fromWire(String? value) => ListingKind.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => ListingKind.offer,
      );
}

/// Dropdown-backed property type.
enum PropertyType {
  house('house', 'خانوو'),
  villa('villa', 'ڤێڵا'),
  shop('shop', 'دوکان'),
  land('land', 'زەوی'),
  office('office', 'ئۆفیس'),
  other('other', 'هیتر');

  const PropertyType(this.wire, this.label);
  final String wire;
  final String label;

  // Unknown or legacy wire values (e.g. the old 'apartment') fall back to هیتر.
  static PropertyType fromWire(String? value) => PropertyType.values.firstWhere(
        (p) => p.wire == value,
        orElse: () => PropertyType.other,
      );
}

/// Dropdown-backed location enum. Extend with your real city/district list.
enum PropertyLocation {
  erbil('erbil', 'Erbil'),
  sulaymaniyah('sulaymaniyah', 'Sulaymaniyah'),
  duhok('duhok', 'Duhok'),
  kirkuk('kirkuk', 'Kirkuk'),
  baghdad('baghdad', 'Baghdad'),
  basra('basra', 'Basra');

  const PropertyLocation(this.wire, this.label);
  final String wire;
  final String label;

  static PropertyLocation fromWire(String? value) =>
      PropertyLocation.values.firstWhere(
        (l) => l.wire == value,
        orElse: () => PropertyLocation.erbil,
      );
}
