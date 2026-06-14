import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/enums.dart';
import '../models/receipt_model.dart';

/// Repository for the `receipts` collection. Receipt numbers are sequential
/// per company per type. Reads are scoped by company + role/branch.
class ReceiptRepository {
  ReceiptRepository(this._db, this._user);

  final FirebaseFirestore _db;
  final SessionUser _user;

  CollectionReference<Map<String, dynamic>> get _receipts =>
      _db.collection('receipts');

  /// Creates a receipt, assigning the next sequential number for its type, and
  /// returns the saved receipt (with number) so the caller can show the PDF.
  Future<Receipt> createReceipt(Receipt draft) async {
    final ref = _receipts.doc();
    final statsRef = _db.collection('company_stats').doc(draft.companyId);
    final counterKey = 'receipt_${draft.type.wire}_count';
    late Receipt saved;

    await _db.runTransaction((txn) async {
      final statsSnap = await txn.get(statsRef);
      final current = (statsSnap.data()?[counterKey] as int?) ?? 0;
      final number = current + 1;

      final data = draft.toJson()..['receipt_number'] = number;
      txn.set(ref, data);
      txn.set(
        statsRef,
        {
          'company_id': draft.companyId,
          counterKey: FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      saved = Receipt.fromJson(ref.id, data);
    });

    return saved;
  }

  /// Company receipts, newest first. Admins are scoped to their branch; plain
  /// users to their own. (Branch/agent filtering is client-side to avoid an
  /// extra composite index.)
  Stream<List<Receipt>> watchReceipts({ReceiptType? type}) {
    return _receipts
        .where('company_id', isEqualTo: _user.companyId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) {
      var list = s.docs.map((d) => Receipt.fromJson(d.id, d.data())).toList();
      if (type != null) list = list.where((r) => r.type == type).toList();
      if (_user.role == UserRole.agent) {
        list = list.where((r) => r.agentId == _user.agentId).toList();
      } else if (_user.isBranchAdmin) {
        list = list.where((r) => r.branch == _user.branch).toList();
      }
      return list;
    });
  }
}

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUserProvider),
  );
});

final receiptsStreamProvider = StreamProvider<List<Receipt>>((ref) {
  return ref.watch(receiptRepositoryProvider).watchReceipts();
});
