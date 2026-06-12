import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// ===========================================================================
/// CONTRACTS  (collection: `contracts`)
/// ===========================================================================
///
/// Modeled as a sealed hierarchy: a single `Contract.fromJson` factory reads
/// the `contract_type` discriminator and hydrates the correct subtype. This
/// keeps the "rent only has installments / sale only has financials" rule
/// enforced by the type system instead of scattered null checks.
///
/// Every document carries `company_id` (tenant isolation) and `agent_id`.
sealed class Contract {
  const Contract({
    required this.id,
    required this.companyId,
    required this.agentId,
    required this.type,
    required this.clientName,
    required this.clientMobile,
    required this.propertyTitle,
    required this.createdAt,
  });

  /// Firestore document id (not persisted inside the doc body).
  final String id;
  final String companyId;
  final String agentId;
  final ContractType type;

  // Shared "Step 1: Parties" + "Step 2: Property" fields.
  final String clientName;
  final String clientMobile;
  final String propertyTitle;

  final DateTime createdAt;

  /// Dispatch on the `contract_type` discriminator.
  factory Contract.fromJson(String id, Map<String, dynamic> json) {
    switch (ContractType.fromWire(json['contract_type'] as String?)) {
      case ContractType.rent:
        return RentContract.fromJson(id, json);
      case ContractType.sale:
        return SaleContract.fromJson(id, json);
    }
  }

  /// Fields common to both subtypes. Subclasses spread this into their map.
  Map<String, dynamic> baseJson() => {
        'contract_type': type.wire,
        'company_id': companyId,
        'agent_id': agentId,
        'client_name': clientName,
        'client_mobile': clientMobile,
        'property_title': propertyTitle,
        'created_at': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toJson();
}

/// ---------------------------------------------------------------------------
/// Rent contract
/// ---------------------------------------------------------------------------
class RentContract extends Contract {
  const RentContract({
    required super.id,
    required super.companyId,
    required super.agentId,
    required super.clientName,
    required super.clientMobile,
    required super.propertyTitle,
    required super.createdAt,
    required this.monthlyAmount,
    required this.installments,
  }) : super(type: ContractType.rent);

  /// Amount of a single monthly installment. Used by stats transactions to
  /// know how much to add when an installment is received/delivered.
  final num monthlyAmount;

  /// Exactly 12 installments. Stored as an array of maps (no per-month columns).
  final List<Installment> installments;

  factory RentContract.fromJson(String id, Map<String, dynamic> json) {
    final rawList = (json['installments'] as List<dynamic>? ?? const []);
    return RentContract(
      id: id,
      companyId: json['company_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      clientMobile: json['client_mobile'] as String? ?? '',
      propertyTitle: json['property_title'] as String? ?? '',
      createdAt:
          (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      monthlyAmount: json['monthly_amount'] as num? ?? 0,
      installments: rawList
          .map((e) => Installment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'monthly_amount': monthlyAmount,
        'installments': installments.map((i) => i.toJson()).toList(),
      };

  /// Builds a fresh 12-month schedule starting from [start] (one per month).
  static List<Installment> buildSchedule(DateTime start) => List.generate(
        12,
        (i) => Installment(
          monthNumber: i + 1,
          dueDate: DateTime(start.year, start.month + i, start.day),
          status: PaymentStatus.pending,
        ),
      );

  /// Count of installments already delivered to the owner.
  int get deliveredCount =>
      installments.where((i) => i.status == PaymentStatus.deliveredToOwner).length;

  RentContract copyWith({List<Installment>? installments}) => RentContract(
        id: id,
        companyId: companyId,
        agentId: agentId,
        clientName: clientName,
        clientMobile: clientMobile,
        propertyTitle: propertyTitle,
        createdAt: createdAt,
        monthlyAmount: monthlyAmount,
        installments: installments ?? this.installments,
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
    required super.clientName,
    required super.clientMobile,
    required super.propertyTitle,
    required super.createdAt,
    required this.totalPrice,
    required this.downPayment,
    required this.remainingAmount,
    required this.remainingDueDate,
    required this.commissionSeller,
    required this.commissionBuyer,
  }) : super(type: ContractType.sale);

  final num totalPrice;
  final num downPayment;
  final num remainingAmount;
  final DateTime? remainingDueDate;

  /// Commission charged to seller / buyer. Editable; seller defaults to 1%.
  final num commissionSeller;
  final num commissionBuyer;

  /// Default commission rate (1%).
  static const double defaultCommissionRate = 0.01;

  factory SaleContract.fromJson(String id, Map<String, dynamic> json) {
    return SaleContract(
      id: id,
      companyId: json['company_id'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      clientMobile: json['client_mobile'] as String? ?? '',
      propertyTitle: json['property_title'] as String? ?? '',
      createdAt:
          (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalPrice: json['total_price'] as num? ?? 0,
      downPayment: json['down_payment'] as num? ?? 0,
      remainingAmount: json['remaining_amount'] as num? ?? 0,
      remainingDueDate: (json['remaining_due_date'] as Timestamp?)?.toDate(),
      commissionSeller: json['commission_seller'] as num? ?? 0,
      commissionBuyer: json['commission_buyer'] as num? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson(),
        'total_price': totalPrice,
        'down_payment': downPayment,
        'remaining_amount': remainingAmount,
        'remaining_due_date': remainingDueDate == null
            ? null
            : Timestamp.fromDate(remainingDueDate!),
        'commission_seller': commissionSeller,
        'commission_buyer': commissionBuyer,
      };
}
