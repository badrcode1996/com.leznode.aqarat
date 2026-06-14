import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// A receipt/voucher (وەصڵ). (collection: `receipts`)
///
/// Four kinds via [type]. Rent receipts are generated from a rent contract
/// installment; external receipts are filled manually. `branch` (لق) is copied
/// from the creating user so admins can be scoped to their branch.
class Receipt {
  const Receipt({
    required this.id,
    required this.companyId,
    required this.agentId,
    required this.agentName,
    required this.branch,
    required this.type,
    required this.receiptNumber,
    required this.date,
    required this.personName, // وەرمگرت لە / پێدرا بە
    required this.amount,
    required this.currency,
    required this.paymentPurpose, // لە بڕی
    required this.note,
    required this.contractId, // '' for external receipts
    required this.monthNumber, // 0 for external receipts
    required this.createdAt,
  });

  final String id;
  final String companyId;
  final String agentId;
  final String agentName; // accountant / کارمەندی بەرپرس
  final String branch; // لق

  final ReceiptType type;
  final int receiptNumber; // ژمارەی وەصڵ (auto, per company per type)
  final DateTime date; // بەروار

  final String personName;
  final num amount;
  final Currency currency;
  final String paymentPurpose;
  final String note;

  final String contractId;
  final int monthNumber;

  final DateTime createdAt;

  factory Receipt.fromJson(String id, Map<String, dynamic> json) => Receipt(
        id: id,
        companyId: json['company_id'] as String? ?? '',
        agentId: json['agent_id'] as String? ?? '',
        agentName: json['agent_name'] as String? ?? '',
        branch: json['branch'] as String? ?? '',
        type: ReceiptType.fromWire(json['type'] as String?),
        receiptNumber: json['receipt_number'] as int? ?? 0,
        date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        personName: json['person_name'] as String? ?? '',
        amount: json['amount'] as num? ?? 0,
        currency: Currency.fromWire(json['dinar_dolar'] as String?),
        paymentPurpose: json['payment_purpose'] as String? ?? '',
        note: json['note'] as String? ?? '',
        contractId: json['contract_id'] as String? ?? '',
        monthNumber: json['month_number'] as int? ?? 0,
        createdAt:
            (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  /// Rent purpose text: "لە بڕی کرێی {start} تاکو {start + 1 month - 1 day}".
  static String rentPurpose(DateTime start) {
    final end = DateTime(start.year, start.month + 1, start.day)
        .subtract(const Duration(days: 1));
    String f(DateTime d) => '${d.day}-${d.month}-${d.year}';
    return 'لە بڕی کرێی ${f(start)} تاکو ${f(end)}';
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'agent_id': agentId,
        'agent_name': agentName,
        'branch': branch,
        'type': type.wire,
        'receipt_number': receiptNumber,
        'date': Timestamp.fromDate(date),
        'person_name': personName,
        'amount': amount,
        'dinar_dolar': currency.wire,
        'payment_purpose': paymentPurpose,
        'note': note,
        'contract_id': contractId,
        'month_number': monthNumber,
        'created_at': Timestamp.fromDate(createdAt),
      };
}
