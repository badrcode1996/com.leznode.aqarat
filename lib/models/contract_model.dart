import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// ===========================================================================
/// CONTRACTS  (collection: `contracts`)
/// ===========================================================================
///
/// Sealed hierarchy: `Contract.fromJson` reads the `contract_type`
/// discriminator and hydrates the correct subtype. Every document carries
/// `company_id` (tenant isolation) and `agent_id`.
///
/// `listTitle` / `listSubtitle` give each subtype a uniform way to render in
/// the contracts list without the caller knowing the concrete type.
sealed class Contract {
  const Contract({
    required this.id,
    required this.companyId,
    required this.agentId,
    required this.type,
    required this.createdAt,
    this.contractNumber = 0,
    this.branch = '',
  });

  final String id;
  final String companyId;
  final String agentId;
  final ContractType type;
  final DateTime createdAt;

  /// Sequential per-company, per-type number (rent and sale have independent
  /// sequences). Assigned atomically by the repository at creation — 0 until then.
  final int contractNumber;

  /// Branch (لق) of the creating user — denormalized for branch-scoped admins.
  final String branch;

  factory Contract.fromJson(String id, Map<String, dynamic> json) {
    switch (ContractType.fromWire(json['contract_type'] as String?)) {
      case ContractType.rent:
        return RentContract.fromJson(id, json);
      case ContractType.sale:
        return SaleContract.fromJson(id, json);
    }
  }

  Map<String, dynamic> baseJson() => {
        'contract_type': type.wire,
        'company_id': companyId,
        'agent_id': agentId,
        'contract_number': contractNumber,
        'branch': branch,
        'created_at': Timestamp.fromDate(createdAt),
      };

  String get listTitle;
  String get listSubtitle;
  Map<String, dynamic> toJson();
}

/// ---------------------------------------------------------------------------
/// Rent contract — mirrors the paper rent form.
/// ---------------------------------------------------------------------------
class RentContract extends Contract {
  const RentContract({
    required super.id,
    required super.companyId,
    required super.agentId,
    required super.createdAt,
    super.contractNumber,
    super.branch,
    // Parties
    required this.party1Name,
    required this.party1Mobile,
    required this.party2Name,
    required this.party2Mobile,
    // Property
    required this.propertyType,
    required this.projectName,
    required this.propertyNumber,
    required this.area,
    // Financials / dates
    required this.rentAmount,
    required this.currency,
    required this.rentalPeriodMonths,
    required this.downPayment,
    required this.downPaymentMonths,
    required this.startDate,
    required this.handoverDate,
    required this.paymentFrequencyMonths,
    required this.guaranteeAmount,
    required this.gracePeriod,
    required this.rentalPurpose,
    required this.lateFeePerDay,
    required this.installments,
    this.notes = '',
    this.agentName = '',
    this.guaranteeReturned = false,
    this.guaranteeReturnedAt,
  }) : super(type: ContractType.rent);

  final String party1Name; // لایەنی یەکەم (خاوەن)
  final String party1Mobile;
  final String party2Name; // لایەنی دووەم (کرێچی)
  final String party2Mobile;

  final String propertyType; // جۆری موڵک
  final String projectName; // پڕۆژە/گەرەک
  final String propertyNumber; // ژمارەی عەقار
  final num area; // ڕووبەر (م²)

  final num rentAmount; // بری کرێ (per installment period)
  final Currency currency; // دینار یان دۆلار
  final int rentalPeriodMonths; // ماوەی بەکریگرتن (بە مانگ)
  final num downPayment; // بری پێشەکی
  final int downPaymentMonths; // بۆ ___ مانگ (first N installments prepaid)
  final DateTime startDate; // بەرواری بەکریگرتن
  final DateTime handoverDate; // بەرواری ڕادەستکردن
  final int paymentFrequencyMonths; // کرێدان چەند مانگ جارێک
  final num guaranteeAmount; // بری دڵنیایی
  final String gracePeriod; // ماوەی ڕێپێدان
  final String rentalPurpose; // هۆکاری بەکری گرتن
  final num lateFeePerDay; // بری دواکەوتن بۆ ڕۆژ

  /// Exactly 12 installments (array of maps, no per-month columns).
  final List<Installment> installments;

  final String notes; // تێبینی (up to 5 lines)
  final String agentName; // name of the user who created the contract

  /// True once the guarantee/deposit has been returned to the tenant.
  final bool guaranteeReturned;
  final DateTime? guaranteeReturnedAt;

  @override
  String get listTitle => party2Name.isNotEmpty ? party2Name : party1Name;
  @override
  String get listSubtitle =>
      [projectName, propertyNumber].where((s) => s.isNotEmpty).join(' / ');

  factory RentContract.fromJson(String id, Map<String, dynamic> json) {
    final rawList = (json['installments'] as List<dynamic>? ?? const []);
    return RentContract(
      id: id,
      companyId: json['company_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      createdAt:
          (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contractNumber: json['contract_number'] as int? ?? 0,
      branch: json['branch'] as String? ?? '',
      party1Name: json['party1_name'] as String? ?? '',
      party1Mobile: json['party1_mobile'] as String? ?? '',
      party2Name: json['party2_name'] as String? ?? '',
      party2Mobile: json['party2_mobile'] as String? ?? '',
      propertyType: json['property_type'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      propertyNumber: json['property_number'] as String? ?? '',
      area: json['area'] as num? ?? 0,
      rentAmount: json['rent_amount'] as num? ?? 0,
      currency: Currency.fromWire(
          (json['dinar_dolar'] ?? json['currency']) as String?),
      rentalPeriodMonths: json['rental_period_months'] as int? ?? 0,
      downPayment: json['down_payment'] as num? ?? 0,
      downPaymentMonths: json['down_payment_months'] as int? ?? 0,
      startDate: (json['start_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      handoverDate: ((json['end_date'] ?? json['handover_date']) as Timestamp?)
              ?.toDate() ??
          DateTime.now(),
      paymentFrequencyMonths: json['payment_frequency_months'] as int? ?? 1,
      guaranteeAmount: json['guarantee_amount'] as num? ?? 0,
      gracePeriod: json['grace_period'] as String? ?? '',
      rentalPurpose: json['rental_purpose'] as String? ?? '',
      lateFeePerDay: json['late_fee_per_day'] as num? ?? 0,
      installments: rawList
          .map((e) => Installment.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? '',
      guaranteeReturned: json['guarantee_returned'] as bool? ?? false,
      guaranteeReturnedAt:
          (json['guarantee_returned_at'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'party1_name': party1Name,
        'party1_mobile': party1Mobile,
        'party2_name': party2Name,
        'party2_mobile': party2Mobile,
        'property_type': propertyType,
        'project_name': projectName,
        'property_number': propertyNumber,
        'area': area,
        'rent_amount': rentAmount,
        'dinar_dolar': currency.wire,
        'rental_period_months': rentalPeriodMonths,
        'down_payment': downPayment,
        'down_payment_months': downPaymentMonths,
        'start_date': Timestamp.fromDate(startDate),
        'end_date': Timestamp.fromDate(handoverDate),
        'payment_frequency_months': paymentFrequencyMonths,
        'guarantee_amount': guaranteeAmount,
        'grace_period': gracePeriod,
        'rental_purpose': rentalPurpose,
        'late_fee_per_day': lateFeePerDay,
        'installments': installments.map((i) => i.toJson()).toList(),
        'notes': notes,
        'agent_name': agentName,
        'guarantee_returned': guaranteeReturned,
        'guarantee_returned_at': guaranteeReturnedAt == null
            ? null
            : Timestamp.fromDate(guaranteeReturnedAt!),
      };

  /// Builds a 12-period schedule from [start], spaced by [everyMonths].
  /// The first [prepaidMonths] installments are marked delivered-to-owner,
  /// because the down payment already settled them.
  static List<Installment> buildSchedule(
    DateTime start, {
    int everyMonths = 1,
    int prepaidMonths = 0,
  }) =>
      List.generate(
        12,
        (i) => Installment(
          monthNumber: i + 1,
          dueDate:
              DateTime(start.year, start.month + i * everyMonths, start.day),
          status: i < prepaidMonths
              ? PaymentStatus.deliveredToOwner
              : PaymentStatus.pending,
        ),
      );

  int get deliveredCount => installments
      .where((i) => i.status == PaymentStatus.deliveredToOwner)
      .length;

  RentContract copyWith({List<Installment>? installments}) => RentContract(
        id: id,
        companyId: companyId,
        agentId: agentId,
        createdAt: createdAt,
        contractNumber: contractNumber,
        branch: branch,
        party1Name: party1Name,
        party1Mobile: party1Mobile,
        party2Name: party2Name,
        party2Mobile: party2Mobile,
        propertyType: propertyType,
        projectName: projectName,
        propertyNumber: propertyNumber,
        area: area,
        rentAmount: rentAmount,
        currency: currency,
        rentalPeriodMonths: rentalPeriodMonths,
        downPayment: downPayment,
        downPaymentMonths: downPaymentMonths,
        startDate: startDate,
        handoverDate: handoverDate,
        paymentFrequencyMonths: paymentFrequencyMonths,
        guaranteeAmount: guaranteeAmount,
        gracePeriod: gracePeriod,
        rentalPurpose: rentalPurpose,
        lateFeePerDay: lateFeePerDay,
        installments: installments ?? this.installments,
        notes: notes,
        agentName: agentName,
        guaranteeReturned: guaranteeReturned,
        guaranteeReturnedAt: guaranteeReturnedAt,
      );
}

/// A single entry inside the `installments` array.
class Installment {
  const Installment({
    required this.monthNumber,
    required this.dueDate,
    required this.status,
  });

  final int monthNumber; // 1..12
  final DateTime dueDate;
  final PaymentStatus status; // 0 pending / 1 received / 2 delivered

  factory Installment.fromJson(Map<String, dynamic> json) => Installment(
        monthNumber: json['month_number'] as int? ?? 0,
        dueDate: (json['due_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: PaymentStatus.fromCode(json['payment_status'] as int?),
      );

  Map<String, dynamic> toJson() => {
        'month_number': monthNumber,
        'due_date': Timestamp.fromDate(dueDate),
        'payment_status': status.code,
      };

  Installment copyWith({PaymentStatus? status}) => Installment(
        monthNumber: monthNumber,
        dueDate: dueDate,
        status: status ?? this.status,
      );
}

/// ---------------------------------------------------------------------------
/// Sale contract
/// ---------------------------------------------------------------------------
class SaleContract extends Contract {
  const SaleContract({
    required super.id,
    required super.companyId,
    required super.agentId,
    required super.createdAt,
    super.contractNumber,
    super.branch,
    // Parties
    required this.party1Name, // فرۆشیار (seller)
    required this.party1Mobile,
    required this.party2Name, // کڕیار (buyer)
    required this.party2Mobile,
    // Property
    required this.propertyType,
    required this.projectName,
    required this.propertyNumber,
    required this.area,
    // Financials
    required this.totalPrice, // نرخی فرۆشتن
    required this.downPayment, // پێشەکی
    required this.currency, // دینار یان دۆلار
    required this.paymentMethod, // شێوازی پارەدان
    required this.lateFeePerDay, // پێدانی بڕی دواکەوتن بۆ ڕۆژێک
    required this.withdrawalAmount, // بڕی پاشگەزبوونەوە
    required this.lawyer, // پارێزەر
    required this.deliveryDate, // ڕێکەوتی تەسلیم
    this.commissionRate = 1, // ڕێژەی عمولە (%)
    this.commissionItems = const [], // ٢ ئایتم: لایەنی یەکەم + دووەم
    this.notes = '',
    this.agentName = '',
  }) : super(type: ContractType.sale);

  final String party1Name;
  final String party1Mobile;
  final String party2Name;
  final String party2Mobile;

  final String propertyType;
  final String projectName;
  final String propertyNumber;
  final num area;

  final num totalPrice;
  final num downPayment;
  final Currency currency;
  final String paymentMethod;
  final num lateFeePerDay;
  final num withdrawalAmount;
  final String lawyer;
  final DateTime deliveryDate;
  final num commissionRate; // ڕێژەی عمولە (%) — هەر لایەک
  final List<CommissionItem> commissionItems; // عمولەی هەر لایەک

  final String notes;
  final String agentName; // name of the user who created the contract

  @override
  String get listTitle => party2Name.isNotEmpty ? party2Name : party1Name;
  @override
  String get listSubtitle =>
      [projectName, propertyNumber].where((s) => s.isNotEmpty).join(' / ');

  factory SaleContract.fromJson(String id, Map<String, dynamic> json) {
    return SaleContract(
      id: id,
      companyId: json['company_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      createdAt:
          (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contractNumber: json['contract_number'] as int? ?? 0,
      branch: json['branch'] as String? ?? '',
      party1Name: json['party1_name'] as String? ?? '',
      party1Mobile: json['party1_mobile'] as String? ?? '',
      party2Name: json['party2_name'] as String? ?? '',
      party2Mobile: json['party2_mobile'] as String? ?? '',
      propertyType: json['property_type'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      propertyNumber: json['property_number'] as String? ?? '',
      area: json['area'] as num? ?? 0,
      totalPrice: json['total_price'] as num? ?? 0,
      downPayment: json['down_payment'] as num? ?? 0,
      currency: Currency.fromWire(json['dinar_dolar'] as String?),
      paymentMethod: json['payment_method'] as String? ?? '',
      lateFeePerDay: json['late_fee_per_day'] as num? ?? 0,
      withdrawalAmount: json['withdrawal_amount'] as num? ?? 0,
      lawyer: json['lawyer'] as String? ?? '',
      deliveryDate:
          (json['delivery_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commissionRate: json['commission_rate'] as num? ?? 1,
      commissionItems: (json['commission_items'] as List<dynamic>? ?? const [])
          .map((e) => CommissionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'party1_name': party1Name,
        'party1_mobile': party1Mobile,
        'party2_name': party2Name,
        'party2_mobile': party2Mobile,
        'property_type': propertyType,
        'project_name': projectName,
        'property_number': propertyNumber,
        'area': area,
        'total_price': totalPrice,
        'down_payment': downPayment,
        'dinar_dolar': currency.wire,
        'payment_method': paymentMethod,
        'late_fee_per_day': lateFeePerDay,
        'withdrawal_amount': withdrawalAmount,
        'lawyer': lawyer,
        'delivery_date': Timestamp.fromDate(deliveryDate),
        'commission_rate': commissionRate,
        'commission_items': commissionItems.map((i) => i.toJson()).toList(),
        'notes': notes,
        'agent_name': agentName,
      };
}

/// One commission entry on a sale contract — one per party (seller + buyer).
/// [paid] is the actual amount (defaults to the calculated commission, but can
/// be edited down); [confirmed] marks it as collected.
class CommissionItem {
  const CommissionItem({
    required this.side,
    required this.paid,
    this.confirmed = false,
  });

  final int side; // 1 = party1 (seller), 2 = party2 (buyer)
  final num paid;
  final bool confirmed;

  factory CommissionItem.fromJson(Map<String, dynamic> j) => CommissionItem(
        side: j['side'] as int? ?? 1,
        paid: j['paid'] as num? ?? 0,
        confirmed: j['confirmed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'side': side, 'paid': paid, 'confirmed': confirmed};

  CommissionItem copyWith({num? paid, bool? confirmed}) => CommissionItem(
        side: side,
        paid: paid ?? this.paid,
        confirmed: confirmed ?? this.confirmed,
      );
}
