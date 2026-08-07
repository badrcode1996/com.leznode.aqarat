/// Centralized enums used across the data layer.
///
/// All enums serialize to/from their stable `wire` string so that the value
/// stored in Firestore never depends on the Dart enum index (which can shift
/// when reordering). Dropdown labels are kept separate from the wire value.
library;

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';

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

/// Subscription tier sold to a company. The per-plan feature set + limits live
/// in the Super-Admin-edited config (`config/plans`, see PlanConfig) — this enum
/// just identifies which tier a company is on.
/// The city a company operates in. The Global Market is scoped to a company's
/// city so listings from different cities don't mix.
enum CompanyCity {
  erbil('erbil', 'هەولێر'),
  sulaymaniyah('sulaymaniyah', 'سلێمانی'),
  kirkuk('kirkuk', 'کەرکوک'),
  duhok('duhok', 'دهۆک');

  const CompanyCity(this.wire, this.label);
  final String wire;

  /// Kurdish name, kept for documents and the Super Admin tooling.
  final String label;

  /// The name in the interface language.
  String get uiLabel => switch (this) {
        CompanyCity.erbil => S.cityErbil,
        CompanyCity.sulaymaniyah => S.citySulaymaniyah,
        CompanyCity.kirkuk => S.cityKirkuk,
        CompanyCity.duhok => S.cityDuhok,
      };

  static CompanyCity fromWire(String? value) => CompanyCity.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => CompanyCity.erbil,
      );
}

enum CompanyPlan {
  bronze('bronze', 'بڕۆنز'),
  silver('silver', 'سیلڤەر'),
  gold('gold', 'گۆڵد'),
  diamond('diamond', 'دایمۆند');

  const CompanyPlan(this.wire, this.label);
  final String wire;

  /// Kurdish name, kept for documents and the Super Admin tooling.
  final String label;

  /// The name in the interface language.
  String get uiLabel => switch (this) {
        CompanyPlan.bronze => S.planBronze,
        CompanyPlan.silver => S.planSilver,
        CompanyPlan.gold => S.planGold,
        CompanyPlan.diamond => S.planDiamond,
      };

  static CompanyPlan fromWire(String? value) => CompanyPlan.values.firstWhere(
        (p) => p.wire == value,
        orElse: () => CompanyPlan.bronze,
      );
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

  /// The title in the INTERFACE language. Distinct from [titleKu]/[titleAr]/
  /// [titleEn], which are the printed voucher's headings and are chosen by the
  /// document's language, not the app's.
  String get uiLabel => switch (this) {
        ReceiptType.externalReceive => S.receiptExternalReceive,
        ReceiptType.externalPay => S.receiptExternalPay,
        ReceiptType.rentReceive => S.receiptRentReceive,
        ReceiptType.rentPay => S.receiptRentPay,
      };

  static ReceiptType fromWire(String? value) => ReceiptType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => ReceiptType.externalReceive,
      );
}

/// Currency used on a contract.
enum Currency {
  iqd('IQD', 'دیناری عێراقی', 'د.ع'),
  usd('USD', 'دۆلاری ئەمریکی', '\$');

  const Currency(this.wire, this.label, this.symbol);
  final String wire;

  /// Kurdish name. Printed on contracts and written into the Excel export, so
  /// it must NOT follow the interface language — a document's wording is fixed
  /// by the document, not by whoever happens to be looking at the app.
  final String label;

  /// Short form for chips and cards, where the full label would wrap.
  final String symbol;

  /// The name in the interface language.
  String get uiLabel =>
      this == Currency.iqd ? S.currencyIqd : S.currencyUsd;

  /// [symbol], but spelled for the interface language — "د.ع" reads as noise
  /// in an English price.
  String get uiSymbol {
    if (this == Currency.usd) return r'$';
    return S.language == AppLanguage.en ? 'IQD' : 'د.ع';
  }

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

/// Splits both Offers and Demands into selling and renting. Orthogonal to
/// [ListingKind]: an offer can be a property for sale or for rent, and a demand
/// can be someone looking to buy or to rent.
///
/// Listings written before this field existed carry no `deal_kind` and fall
/// back to [sale] — the same default new forms open on.
enum DealKind {
  sale('sale', 'فرۆشتن', 'کڕین'),
  rent('rent', 'کرێ', 'کرێ');

  const DealKind(this.wire, this.label, this.demandLabel);
  final String wire;

  /// The offer-side wording — the company is selling/renting out.
  final String label;

  /// The demand-side wording. A demand for a `sale` listing is someone looking
  /// to BUY (کڕین), not to sell, so the same [wire] value must read differently
  /// on the Demands side of the app.
  final String demandLabel;

  /// [label] or [demandLabel], picked by which side of the app is showing it,
  /// in the interface language.
  String labelFor(ListingKind kind) {
    if (this == DealKind.rent) return S.dealRent;
    return kind == ListingKind.demand ? S.dealBuy : S.dealSale;
  }

  static DealKind fromWire(String? value) => DealKind.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => DealKind.sale,
      );
}

/// Dropdown-backed property type.
enum PropertyType {
  house('house', 'خانوو'),
  villa('villa', 'ڤێڵا'),
  shop('shop', 'دوکان'),
  land('land', 'زەوی'),
  office('office', 'ئۆفیس'),
  structure('structure', 'هەیکەل'),
  other('other', 'هیتر');

  const PropertyType(this.wire, this.kuLabel);
  final String wire;

  /// Kurdish name, kept for documents and the Super Admin tooling.
  final String kuLabel;

  /// The name in the interface language — what every card and form shows.
  String get label => switch (this) {
        PropertyType.house => S.typeHouse,
        PropertyType.villa => S.typeVilla,
        PropertyType.shop => S.typeShop,
        PropertyType.land => S.typeLand,
        PropertyType.office => S.typeOffice,
        PropertyType.structure => S.typeStructure,
        PropertyType.other => S.typeOther,
      };

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
