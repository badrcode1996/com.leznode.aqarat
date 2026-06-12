import 'package:cloud_firestore/cloud_firestore.dart';

/// ===========================================================================
/// COMPANY STATS  (collection: `company_stats`, doc id == company_id)
/// ===========================================================================
///
/// A single pre-aggregated document per tenant. Instead of reading every
/// contract to compute dashboards (expensive — one read per contract), we keep
/// running counters here and mutate them inside transactions whenever a
/// contract changes. The Company Admin dashboard then costs exactly ONE read.
class CompanyStats {
  const CompanyStats({
    required this.companyId,
    required this.contractCount,
    required this.rentContractCount,
    required this.saleContractCount,
    required this.totalRevenue,
    required this.collectedRevenue,
    required this.updatedAt,
  });

  final String companyId;
  final int contractCount;
  final int rentContractCount;
  final int saleContractCount;

  /// Total contracted value (e.g. sum of sale totals + expected rent).
  final num totalRevenue;

  /// Money actually collected/handled so far (installments received).
  final num collectedRevenue;

  final DateTime updatedAt;

  factory CompanyStats.fromJson(String id, Map<String, dynamic> json) =>
      CompanyStats(
        companyId: id,
        contractCount: json['contract_count'] as int? ?? 0,
        rentContractCount: json['rent_contract_count'] as int? ?? 0,
        saleContractCount: json['sale_contract_count'] as int? ?? 0,
        totalRevenue: json['total_revenue'] as num? ?? 0,
        collectedRevenue: json['collected_revenue'] as num? ?? 0,
        updatedAt:
            (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'contract_count': contractCount,
        'rent_contract_count': rentContractCount,
        'sale_contract_count': saleContractCount,
        'total_revenue': totalRevenue,
        'collected_revenue': collectedRevenue,
        'updated_at': Timestamp.fromDate(updatedAt),
      };
}
