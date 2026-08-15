import 'package:cloud_firestore/cloud_firestore.dart';

/// ===========================================================================
/// COMPANY STATS  (collection: `company_stats`, doc id == company_id)
/// ===========================================================================
///
/// A single pre-aggregated document per tenant. Instead of reading every
/// contract to compute dashboards (expensive — one read per contract), we keep
/// running counters here and mutate them inside transactions whenever a
/// contract changes. The Company Admin dashboard then costs exactly ONE read.
///
/// The same shape is mirrored per branch under `company_stats/{id}/branches`,
/// which is what a branch-scoped user's dashboard reads instead — see
/// ContractRepository.
class CompanyStats {
  const CompanyStats({
    required this.companyId,
    required this.contractCount,
    required this.rentContractCount,
    required this.saleContractCount,
    required this.totalRevenue,
    required this.collectedRevenue,
    required this.updatedAt,
    this.collectedIqd = 0,
    this.collectedUsd = 0,
    this.guaranteeIqd = 0,
    this.guaranteeUsd = 0,
  });

  final String companyId;
  final int contractCount;
  final int rentContractCount;
  final int saleContractCount;

  /// Total contracted value (e.g. sum of sale totals + expected rent).
  final num totalRevenue;

  /// Money actually collected/handled so far (installments received).
  final num collectedRevenue;

  /// The same money, split by currency — dinars and dollars cannot be added
  /// together, and the dashboard shows them on separate lines. Splitting them
  /// here is what lets the cashbox and deposit cards cost one read instead of
  /// downloading every contract to sum them on the device.
  final num collectedIqd;
  final num collectedUsd;

  /// Deposits the company is still holding, by currency. Excludes any already
  /// returned to the tenant.
  final num guaranteeIqd;
  final num guaranteeUsd;

  final DateTime updatedAt;

  /// All zeros. Stands for a branch that has not had a contract written in it
  /// yet, so its dashboard reads empty instead of falling back to figures from
  /// the rest of the company.
  factory CompanyStats.empty(String companyId) => CompanyStats(
        companyId: companyId,
        contractCount: 0,
        rentContractCount: 0,
        saleContractCount: 0,
        totalRevenue: 0,
        collectedRevenue: 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory CompanyStats.fromJson(String id, Map<String, dynamic> json) =>
      CompanyStats(
        companyId: id,
        contractCount: json['contract_count'] as int? ?? 0,
        rentContractCount: json['rent_contract_count'] as int? ?? 0,
        saleContractCount: json['sale_contract_count'] as int? ?? 0,
        totalRevenue: json['total_revenue'] as num? ?? 0,
        collectedRevenue: json['collected_revenue'] as num? ?? 0,
        collectedIqd: json['collected_iqd'] as num? ?? 0,
        collectedUsd: json['collected_usd'] as num? ?? 0,
        guaranteeIqd: json['guarantee_iqd'] as num? ?? 0,
        guaranteeUsd: json['guarantee_usd'] as num? ?? 0,
        updatedAt:
            (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'contract_count': contractCount,
        'rent_contract_count': rentContractCount,
        'sale_contract_count': saleContractCount,
        'total_revenue': totalRevenue,
        'collected_revenue': collectedRevenue,
        'collected_iqd': collectedIqd,
        'collected_usd': collectedUsd,
        'guarantee_iqd': guaranteeIqd,
        'guarantee_usd': guaranteeUsd,
        'updated_at': Timestamp.fromDate(updatedAt),
      };
}
