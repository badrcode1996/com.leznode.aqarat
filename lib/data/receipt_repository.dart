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

  /// Edits an existing receipt's mutable fields. The receipt number, type,
  /// branch and creation metadata are immutable — only the user-entered fields
  /// (person, amount, currency, purpose, note, date) are updated.
  Future<void> updateReceipt(Receipt receipt) async {
    if (receipt.companyId != _user.companyId) {
      throw StateError('Cross-tenant write blocked.');
    }
    await _receipts.doc(receipt.id).update({
      'person_name': receipt.personName,
      'amount': receipt.amount,
      'dinar_dolar': receipt.currency.wire,
      'payment_purpose': receipt.paymentPurpose,
      'note': receipt.note,
      'date': Timestamp.fromDate(receipt.date),
    });
  }

  /// Deletes a receipt. The per-type numbering counter is left untouched on
  /// purpose: numbers are never reused, so a deleted receipt simply leaves a
  /// gap in the sequence.
  Future<void> deleteReceipt(Receipt receipt) async {
    if (receipt.companyId != _user.companyId) {
      throw StateError('Cross-tenant write blocked.');
    }
    await _receipts.doc(receipt.id).delete();
  }

  /// Company receipts, newest first. Everyone except company-wide admins is
  /// scoped to their own branch — enforced BOTH here (the `branch ==` clause)
  /// and by a matching Firestore Security Rule, so a member can never reach
  /// another branch's receipts even via a direct API call.
  Stream<List<Receipt>> watchReceipts({ReceiptType? type}) {
    var query = _receipts.where('company_id', isEqualTo: _user.companyId);
    if (!_user.isCompanyWide) {
      query = query.where('branch', isEqualTo: _user.branch);
    }
    return query.orderBy('created_at', descending: true).snapshots().map((s) {
      var list = s.docs.map((d) => Receipt.fromJson(d.id, d.data())).toList();
      if (type != null) list = list.where((r) => r.type == type).toList();
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
