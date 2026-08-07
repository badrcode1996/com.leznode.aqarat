/// ===========================================================================
/// NOTIFICATIONS  (collection: `notifications`)
/// ===========================================================================
///
/// Documents are written ONLY by the scheduled Cloud Function (Admin SDK), so
/// the app never creates one. They carry `company_id` + `branch` copied from
/// the contract they were raised for, which makes them visible to exactly the
/// people who can already see that contract — the rules reuse the same
/// inBranch() gate.
///
/// Read state is an array of uids rather than one document per user: a company
/// has a handful of members, and fanning one overdue installment out into N
/// documents would multiply both writes and the daily scan's cost for nothing.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// What a notification is about. The wire value is also part of the document id
/// (the dedupe key), so it must never change once shipped.
enum NotificationType {
  /// A rent installment is past its due date and still unpaid.
  rentOverdue('rent_overdue'),

  /// A rent installment falls due within the next few days.
  rentDueSoon('rent_due_soon'),

  /// A rent contract's term ends within the next month.
  contractExpiring('contract_expiring');

  const NotificationType(this.wire);
  final String wire;

  static NotificationType fromWire(String? value) =>
      NotificationType.values.firstWhere(
        (t) => t.wire == value,
        orElse: () => NotificationType.rentOverdue,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.companyId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.branch = '',
    this.contractId = '',
    this.dueDate,
    this.readBy = const [],
  });

  final String id;
  final String companyId;

  /// Branch of the contract this was raised for — scopes visibility exactly
  /// like the contract itself.
  final String branch;

  final NotificationType type;

  /// Both are rendered as stored. The Cloud Function writes them in Kurdish so
  /// the same strings can go straight into the push payload, where there is no
  /// app running to translate anything.
  final String title;
  final String body;

  /// The contract this concerns — used to open it from the list.
  final String contractId;

  /// The installment due date / lease end date this was raised for. Shown on
  /// the card so the row is actionable without opening the contract.
  final DateTime? dueDate;

  final DateTime createdAt;

  /// uids that have opened the notification centre since this arrived.
  final List<String> readBy;

  bool isReadBy(String uid) => readBy.contains(uid);

  factory AppNotification.fromJson(String id, Map<String, dynamic> json) =>
      AppNotification(
        id: id,
        companyId: json['company_id'] as String? ?? '',
        branch: json['branch'] as String? ?? '',
        type: NotificationType.fromWire(json['type'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        contractId: json['contract_id'] as String? ?? '',
        dueDate: (json['due_date'] as Timestamp?)?.toDate(),
        createdAt:
            (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        readBy: (json['read_by'] as List<dynamic>? ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'branch': branch,
        'type': type.wire,
        'title': title,
        'body': body,
        'contract_id': contractId,
        'due_date': dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'created_at': Timestamp.fromDate(createdAt),
        'read_by': readBy,
      };
}
