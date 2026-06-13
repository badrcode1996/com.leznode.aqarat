import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/company_stats_model.dart';
import '../models/contract_model.dart';
import '../models/enums.dart';

/// Repository for the `contracts` collection. Every read is scoped by
/// `company_id`; agents are additionally scoped to their own `agent_id`.
class ContractRepository {
  ContractRepository(this._db, this._user);

  final FirebaseFirestore _db;
  final SessionUser _user;

  CollectionReference<Map<String, dynamic>> get _contracts =>
      _db.collection('contracts');

  DocumentReference<Map<String, dynamic>> get _statsDoc =>
      _db.collection('company_stats').doc(_user.companyId);

  /// Builds the base query honoring multi-tenant isolation + role.
  ///
  /// IMPORTANT: the `company_id ==` clause must match a Firestore Security Rule
  /// of the same shape, otherwise isolation is only enforced client-side.
  Query<Map<String, dynamic>> _scopedQuery() {
    var query = _contracts.where('company_id', isEqualTo: _user.companyId);

    // Company/Super Admin see all agents; a plain Agent sees only their own.
    if (!_user.isCompanyWide) {
      query = query.where('agent_id', isEqualTo: _user.agentId);
    }
    return query.orderBy('created_at', descending: true);
  }

  /// Live stream of contracts for the current tenant/role.
  Stream<List<Contract>> watchContracts() {
    return _scopedQuery().snapshots().map(
          (snap) => snap.docs
              .map((d) => Contract.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  /// One-shot fetch (cheaper than a stream for non-realtime screens).
  Future<List<Contract>> fetchContracts() async {
    final snap = await _scopedQuery().get();
    return snap.docs.map((d) => Contract.fromJson(d.id, d.data())).toList();
  }

  /// Creates a contract AND increments the company_stats counters in ONE
  /// atomic transaction. Either both succeed or neither does.
  Future<String> createContract(Contract contract) async {
    final newRef = _contracts.doc();

    await _db.runTransaction((txn) async {
      final statsSnap = await txn.get(_statsDoc);
      final stats = statsSnap.data();

      // Sequential, per-company, per-type contract number (starts at 1).
      final counterKey = contract.type == ContractType.rent
          ? 'rent_contract_count'
          : 'sale_contract_count';
      final currentCount = (stats?[counterKey] as int?) ?? 0;
      final contractNumber = currentCount + 1;

      final data = contract.toJson()..['contract_number'] = contractNumber;
      txn.set(newRef, data);

      // Expected value added to the pipeline by this contract.
      final num expectedValue = switch (contract) {
        SaleContract s => s.totalPrice,
        RentContract r => r.rentAmount * 12,
      };

      final updates = <String, dynamic>{
        'company_id': _user.companyId,
        'contract_count': FieldValue.increment(1),
        'total_revenue': FieldValue.increment(expectedValue),
        'updated_at': FieldValue.serverTimestamp(),
        if (contract.type == ContractType.rent)
          'rent_contract_count': FieldValue.increment(1)
        else
          'sale_contract_count': FieldValue.increment(1),
      };

      // doc may not exist yet for a brand-new company → set with merge.
      if (statsSnap.exists) {
        txn.update(_statsDoc, updates);
      } else {
        txn.set(_statsDoc, updates, SetOptions(merge: true));
      }
    });

    return newRef.id;
  }

  /// Updates a single rent installment's `payment_status` and adjusts the
  /// company stats in the SAME transaction.
  ///
  /// Transactions matter here because two devices could touch the same
  /// installment concurrently; the read-modify-write below is replayed by
  /// Firestore on contention so the counter never double-counts.
  ///
  /// Revenue accounting rule used in this demo:
  ///   - moving TO status 1 (received from tenant) → +monthlyAmount collected
  ///   - moving AWAY from status 1 (e.g. correction) → −monthlyAmount collected
  Future<void> updateInstallmentStatus({
    required String contractId,
    required int monthNumber,
    required PaymentStatus newStatus,
  }) async {
    final contractRef = _contracts.doc(contractId);

    await _db.runTransaction((txn) async {
      // 1. READ inside the transaction.
      final snap = await txn.get(contractRef);
      if (!snap.exists) {
        throw StateError('Contract $contractId not found.');
      }
      final data = snap.data()!;

      // Defense in depth: never let a transaction cross tenant boundaries.
      if (data['company_id'] != _user.companyId) {
        throw StateError('Cross-tenant write blocked.');
      }

      final contract = Contract.fromJson(snap.id, data);
      if (contract is! RentContract) {
        throw StateError('Installments only exist on rent contracts.');
      }

      final index =
          contract.installments.indexWhere((i) => i.monthNumber == monthNumber);
      if (index == -1) {
        throw StateError('Installment month $monthNumber not found.');
      }

      final oldStatus = contract.installments[index].status;
      if (oldStatus == newStatus) return; // no-op, avoid useless write.

      // 2. MODIFY the array in memory.
      final updated = [...contract.installments];
      updated[index] = updated[index].copyWith(status: newStatus);

      // 3. WRITE the whole array back (Firestore can't patch one array item).
      txn.update(contractRef, {
        'installments': updated.map((i) => i.toJson()).toList(),
      });

      // 4. Adjust collected revenue accordingly, atomically.
      final wasReceived = oldStatus == PaymentStatus.receivedFromTenant;
      final nowReceived = newStatus == PaymentStatus.receivedFromTenant;
      num delta = 0;
      if (!wasReceived && nowReceived) delta = contract.rentAmount;
      if (wasReceived && !nowReceived) delta = -contract.rentAmount;

      if (delta != 0) {
        txn.set(
          _statsDoc,
          {
            'company_id': _user.companyId,
            'collected_revenue': FieldValue.increment(delta),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    });
  }
}

/// ---------------------------------------------------------------------------
/// Riverpod wiring
/// ---------------------------------------------------------------------------

/// Rebuilds (and disposes the old instance) whenever the session changes —
/// the mechanism that prevents tenant data bleed-through.
final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  return ContractRepository(db, user);
});

/// Realtime contracts for the dashboard / list screens.
final contractsStreamProvider = StreamProvider<List<Contract>>((ref) {
  return ref.watch(contractRepositoryProvider).watchContracts();
});

/// The current company's pre-aggregated stats doc (one read, kept live).
final companyStatsProvider = StreamProvider<CompanyStats?>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  if (user.companyId.isEmpty) return Stream.value(null);
  return db
      .collection('company_stats')
      .doc(user.companyId)
      .snapshots()
      .map((s) => s.exists ? CompanyStats.fromJson(s.id, s.data()!) : null);
});
