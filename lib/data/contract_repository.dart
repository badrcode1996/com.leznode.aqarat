import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// The same counters, mirrored per branch.
  ///
  /// The dashboard is the one screen that reads counters instead of running a
  /// scoped query, so it was the one screen where branch isolation did not
  /// hold: a branch admin with no contracts of their own was shown the whole
  /// company's total. Every write below moves the company doc and this mirror
  /// together, in the same transaction, so the two can never disagree.
  ///
  /// Keyed by the branch that owns the CONTRACT, never by the current user's:
  /// a company-wide admin editing another branch's contract has to move that
  /// branch's numbers, not their own.
  DocumentReference<Map<String, dynamic>> _branchStatsDoc(String branch) =>
      _statsDoc.collection('branches').doc(branchKey(branch));

  /// A document id for a branch name. Ids may not be empty or contain a slash,
  /// and branch names are typed by hand. The encoding only has to be stable —
  /// the same helper writes the doc and reads it back — so two names that
  /// differ only by a slash would share a document, which is a trade the
  /// alternative (a lookup table) does not pay for.
  static String branchKey(String branch) {
    final trimmed = branch.trim();
    if (trimmed.isEmpty) return '_none';
    return trimmed.replaceAll('/', '_');
  }

  /// Moves a set of counters on the company doc and on [branch]'s mirror.
  ///
  /// merge:true on both: neither document is created up front — a company that
  /// has never written a contract has no stats doc, and a branch gets its
  /// mirror the first time something happens in it.
  void _bumpStats(
      Transaction txn, String branch, Map<String, dynamic> updates) {
    txn.set(
      _statsDoc,
      {
        'company_id': _user.companyId,
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    txn.set(
      _branchStatsDoc(branch),
      {
        'company_id': _user.companyId,
        'branch': branch,
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Builds the base query honoring multi-tenant + branch isolation.
  ///
  /// IMPORTANT: the `company_id ==` and `branch ==` clauses must match the
  /// Firestore Security Rules of the same shape, otherwise isolation is only
  /// enforced client-side. Everyone except company-wide admins is scoped to
  /// their own branch (so they cannot reach another branch's contracts even via
  /// a direct API call).
  Query<Map<String, dynamic>> _scopedQuery() {
    var query = _contracts.where('company_id', isEqualTo: _user.companyId);
    if (!_user.isCompanyWide) {
      query = query.where('branch', isEqualTo: _user.branch);
    }
    return query.orderBy('created_at', descending: true);
  }

  /// Live stream of contracts for the current tenant/branch.
  ///
  /// UNBOUNDED — every contract the user may see, kept open. Only the repair
  /// path should want that; screens take a page (see [watchPage]) or a targeted
  /// query instead.
  Stream<List<Contract>> watchContracts() {
    return _scopedQuery().snapshots().map((snap) =>
        snap.docs.map((d) => Contract.fromJson(d.id, d.data())).toList());
  }

  /// One page of contracts, newest first.
  ///
  /// [after] is the last document of the previous page — Firestore pages by
  /// cursor, not by offset, so "page 5" costs the same as "page 1" and a
  /// contract created meanwhile cannot shift a row across the boundary.
  ///
  /// Returns the raw snapshots rather than models because the caller needs the
  /// last document to ask for the next page.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPage({
    ContractType? type,
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 20,
  }) {
    var query = _scopedQuery();
    if (type != null) {
      query = query.where('contract_type', isEqualTo: type.wire);
    }
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(limit).get();
  }

  /// A single contract, kept live.
  ///
  /// The installment grid and the notification cards used to watch EVERY
  /// contract and then search the list for the one they wanted — the most
  /// expensive possible way to read one document.
  Stream<Contract?> watchContract(String id) {
    return _contracts.doc(id).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return Contract.fromJson(snap.id, data);
    });
  }

  /// Rent contracts with at least one installment already past due.
  ///
  /// Reads only the contracts actually in arrears, thanks to the
  /// `earliest_pending_due` mirror — Firestore cannot filter on the
  /// installments array itself.
  ///
  /// [limit] is a safety valve rather than a page size: a company with more
  /// than this many contracts in arrears has a problem no list will solve, and
  /// the dashboard total would be misleading either way.
  Future<List<RentContract>> fetchOverdue({int limit = 200}) async {
    final snap = await _scopedQuery()
        .where('contract_type', isEqualTo: ContractType.rent.wire)
        .where('earliest_pending_due', isLessThan: Timestamp.now())
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => Contract.fromJson(d.id, d.data()))
        .whereType<RentContract>()
        .toList();
  }

  /// Rent contracts still holding a deposit.
  Future<List<RentContract>> fetchGuarantees({int limit = 200}) async {
    final snap = await _scopedQuery()
        .where('contract_type', isEqualTo: ContractType.rent.wire)
        .where('guarantee_returned', isEqualTo: false)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => Contract.fromJson(d.id, d.data()))
        .whereType<RentContract>()
        .where((c) => c.guaranteeAmount > 0)
        .toList();
  }

  /// Sale contracts created since [from] — the commission screen only ever
  /// shows the current month.
  Future<List<SaleContract>> fetchSalesSince(DateTime from,
      {int limit = 200}) async {
    final snap = await _scopedQuery()
        .where('contract_type', isEqualTo: ContractType.sale.wire)
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => Contract.fromJson(d.id, d.data()))
        .whereType<SaleContract>()
        .toList();
  }

  /// How many contracts the company created since [from].
  ///
  /// An aggregate query: the server counts and returns a number, billed as a
  /// handful of reads rather than one per contract.
  Future<int> countCreatedSince(DateTime from) async {
    final agg = await _scopedQuery()
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// One-shot fetch (cheaper than a stream for non-realtime screens).
  Future<List<Contract>> fetchContracts() async {
    final snap = await _scopedQuery().get();
    return snap.docs.map((d) => Contract.fromJson(d.id, d.data())).toList();
  }

  /// A single contract, or null if it's gone. Used right after a create to
  /// read back the fields the server assigned (contract_number, branch).
  Future<Contract?> fetchContract(String id) async {
    final snap = await _contracts.doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    return Contract.fromJson(snap.id, data);
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

      final data = contract.toJson()
        ..['contract_number'] = contractNumber
        ..['branch'] = _user.branch; // denormalize creator's branch
      txn.set(newRef, data);

      // The contract number above comes from the COMPANY counter, and stays
      // that way — numbering is per company, not per branch.
      _bumpStats(txn, _user.branch, {
        'contract_count': FieldValue.increment(1),
        ..._increments(_statsAmounts(contract, 1)),
        if (contract.type == ContractType.rent)
          'rent_contract_count': FieldValue.increment(1)
        else
          'sale_contract_count': FieldValue.increment(1),
      });
    });

    return newRef.id;
  }

  /// Expected pipeline value a contract contributes to `total_revenue`.
  static num _expectedValue(Contract c) => switch (c) {
        SaleContract s => s.totalPrice,
        RentContract r => r.rentAmount * 12,
      };

  /// Revenue already collected from a contract (only rent installments marked
  /// "received from tenant" count toward `collected_revenue`).
  static num _collectedValue(Contract c) => switch (c) {
        SaleContract _ => 0,
        RentContract r => r.installments
                .where((i) => i.status == PaymentStatus.receivedFromTenant)
                .length *
            r.rentAmount,
      };

  /// The deposit a contract still holds — zero once it has been returned.
  static num _guaranteeHeld(Contract c) => switch (c) {
        SaleContract _ => 0,
        RentContract r => r.guaranteeReturned ? 0 : r.guaranteeAmount,
      };

  /// The per-currency counter suffix for a contract, so one helper can build
  /// `collected_iqd` / `collected_usd` without the callers branching.
  static String _cur(Contract c) => switch (c) {
        SaleContract s => s.currency == Currency.iqd ? 'iqd' : 'usd',
        RentContract r => r.currency == Currency.iqd ? 'iqd' : 'usd',
      };

  /// What a contract contributes to each counter, as plain numbers. Pass -1 to
  /// [sign] to get the reversal.
  ///
  /// Kept in one place because create, edit and delete all have to move the
  /// same set of counters, and a counter updated on two of the three paths is
  /// exactly the drift `recalculateStats` exists to repair.
  @visibleForTesting
  static Map<String, num> statsAmounts(Contract c, int sign) =>
      _statsAmounts(c, sign);

  @visibleForTesting
  static Map<String, num> sumAmounts(Map<String, num> a, Map<String, num> b) =>
      _sumAmounts(a, b);

  static Map<String, num> _statsAmounts(Contract c, int sign) {
    final cur = _cur(c);
    return {
      'total_revenue': _expectedValue(c) * sign,
      'collected_revenue': _collectedValue(c) * sign,
      'collected_$cur': _collectedValue(c) * sign,
      'guarantee_$cur': _guaranteeHeld(c) * sign,
    };
  }

  /// Adds two amount maps. Their keys differ when an edit changed the currency
  /// — the old currency's counter goes down and the new one's goes up — so a
  /// plain difference would leave the old currency overstated forever.
  static Map<String, num> _sumAmounts(
      Map<String, num> a, Map<String, num> b) {
    final out = Map<String, num>.from(a);
    b.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    return out;
  }

  /// Turns amounts into Firestore increments, dropping the no-ops so an edit
  /// that touched nothing doesn't write.
  static Map<String, dynamic> _increments(Map<String, num> amounts) => {
        for (final e in amounts.entries)
          if (e.value != 0) e.key: FieldValue.increment(e.value),
      };

  /// Edits an existing contract and rebalances the company_stats counters in
  /// the SAME transaction: `total_revenue` shifts by the change in expected
  /// value, `collected_revenue` by the change in received rent. The contract's
  /// identity fields (number, type, branch, agent, creation date) are
  /// preserved by the caller and never altered here.
  Future<void> updateContract(Contract updated) async {
    final ref = _contracts.doc(updated.id);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) throw StateError('Contract ${updated.id} not found.');
      final data = snap.data()!;
      if (data['company_id'] != _user.companyId) {
        throw StateError('Cross-tenant write blocked.');
      }
      final old = Contract.fromJson(snap.id, data);

      // Persist the edited document. Keep the immutable identity fields from the
      // stored copy so a stale client object can't rewrite them. Installment
      // statuses are owned by updateInstallmentStatus — an edit must NEVER
      // rewrite them (a stale snapshot would clobber a payment and drift the
      // collected-revenue counter, leaving money "stuck" in the cashbox).
      final newData = updated.toJson()
        ..['contract_number'] = data['contract_number']
        ..['branch'] = data['branch']
        ..['agent_id'] = data['agent_id']
        ..['created_at'] = data['created_at'];
      if (data['installments'] != null) {
        newData['installments'] = data['installments'];
        // The queryable mirror belongs to the installments it describes, so it
        // is restored alongside them rather than taken from the edited copy.
        newData['earliest_pending_due'] = data['earliest_pending_due'];
      }
      txn.set(ref, newData);

      // Deltas come from what was actually stored (new amounts + the stored
      // installment statuses) so an edit can't drift the counters. Reversing
      // the old contract and applying the new one keeps every counter — the
      // per-currency ones included — correct even when the edit changed the
      // currency, which a plain difference would get wrong.
      final stored = Contract.fromJson(snap.id, newData);
      _bumpStats(
        txn,
        data['branch'] as String? ?? '',
        _increments(
            _sumAmounts(_statsAmounts(old, -1), _statsAmounts(stored, 1))),
      );
    });
  }

  /// Deletes a contract and reverses every company_stats counter its creation
  /// incremented (contract_count, per-type count, total_revenue) plus any rent
  /// already collected — all atomically.
  Future<void> deleteContract(Contract contract) async {
    final ref = _contracts.doc(contract.id);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return; // already gone — nothing to reverse.
      final data = snap.data()!;
      if (data['company_id'] != _user.companyId) {
        throw StateError('Cross-tenant write blocked.');
      }
      final stored = Contract.fromJson(snap.id, data);

      txn.delete(ref);
      _bumpStats(txn, data['branch'] as String? ?? '', {
        'contract_count': FieldValue.increment(-1),
        ..._increments(_statsAmounts(stored, -1)),
        if (stored.type == ContractType.rent)
          'rent_contract_count': FieldValue.increment(-1)
        else
          'sale_contract_count': FieldValue.increment(-1),
      });
    });
  }

  /// Recomputes the company_stats counters from scratch off the company's
  /// actual contracts. Use this to repair any drift in the running counters
  /// (e.g. money "stuck" in the cashbox after a bad edit).
  ///
  /// It also backfills `earliest_pending_due` on every rent contract, which is
  /// what brings contracts written before that field existed into the overdue
  /// query. This is the one place that legitimately reads the whole
  /// collection — it is an explicit admin repair action, not something a screen
  /// does on open.
  Future<void> recalculateStats() async {
    final snap =
        await _contracts.where('company_id', isEqualTo: _user.companyId).get();

    // Totals for the company, and the same again for each branch that owns a
    // contract. Rebuilding the mirrors here is also how a company that was
    // running before they existed gets them at all.
    final totals = _Tally();
    final perBranch = <String, _Tally>{};
    for (final doc in snap.docs) {
      final c = Contract.fromJson(doc.id, doc.data());
      final branch = doc.data()['branch'] as String? ?? '';
      for (final t in [totals, perBranch.putIfAbsent(branch, _Tally.new)]) {
        t.add(_statsAmounts(c, 1));
        t.count(c.type);
      }
    }

    await _statsDoc.set(totals.toJson(_user.companyId), SetOptions(merge: true));

    // A branch emptied since the last repair keeps a document full of numbers
    // that no contract backs any more, so every existing mirror is rewritten —
    // the ones with nothing left in them to zero.
    final existing = await _statsDoc.collection('branches').get();
    for (final doc in existing.docs) {
      final branch = doc.data()['branch'] as String? ?? '';
      if (!perBranch.containsKey(branch)) perBranch[branch] = _Tally();
    }
    for (final entry in perBranch.entries) {
      await _branchStatsDoc(entry.key).set(
        {...entry.value.toJson(_user.companyId), 'branch': entry.key},
        SetOptions(merge: true),
      );
    }

    // Backfill the fields the overdue and deposit queries filter on.
    //
    // A Firestore `where` never matches a document that LACKS the field — not
    // even for `== false`. So a rent contract written before these existed is
    // invisible to those queries until it is written once, which is what this
    // does.
    final stale = snap.docs.where((d) {
      final c = Contract.fromJson(d.id, d.data());
      if (c is! RentContract) return false;
      final data = d.data();
      final stored = (data['earliest_pending_due'] as Timestamp?)?.toDate();
      return stored != c.earliestPendingDue ||
          !data.containsKey('earliest_pending_due') ||
          !data.containsKey('guarantee_returned');
    }).toList();

    for (var i = 0; i < stale.length; i += 400) {
      final batch = _db.batch();
      for (final doc in stale.skip(i).take(400)) {
        final c = Contract.fromJson(doc.id, doc.data()) as RentContract;
        batch.update(doc.reference, {
          'earliest_pending_due': c.earliestPendingDue == null
              ? null
              : Timestamp.fromDate(c.earliestPendingDue!),
          'guarantee_returned': c.guaranteeReturned,
        });
      }
      await batch.commit();
    }
  }

  /// Marks a rent contract's guarantee as returned (or not) to the tenant, and
  /// moves the held-deposit counter by the same amount in one transaction —
  /// otherwise the dashboard total would keep counting a deposit already
  /// handed back.
  Future<void> setGuaranteeReturned(String contractId, bool returned) async {
    final ref = _contracts.doc(contractId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) throw StateError('Contract $contractId not found.');
      final data = snap.data()!;
      if (data['company_id'] != _user.companyId) {
        throw StateError('Cross-tenant write blocked.');
      }
      final c = Contract.fromJson(snap.id, data);
      if (c is! RentContract) {
        throw StateError('Only rent contracts hold a deposit.');
      }
      if (c.guaranteeReturned == returned) return; // no-op, avoid a write.

      txn.update(ref, {
        'guarantee_returned': returned,
        'guarantee_returned_at':
            returned ? FieldValue.serverTimestamp() : null,
      });

      // Returning it releases the amount; un-returning takes it back.
      final delta = returned ? -c.guaranteeAmount : c.guaranteeAmount;
      _bumpStats(txn, data['branch'] as String? ?? '', {
        'guarantee_${_cur(c)}': FieldValue.increment(delta),
      });
    });
  }

  /// Edits one commission item (by party [side]) on a sale contract — the
  /// actually-paid amount and/or its confirmed state.
  Future<void> updateCommissionItem(
    String contractId,
    int side, {
    num? paid,
    bool? confirmed,
  }) async {
    final ref = _contracts.doc(contractId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) throw StateError('Contract $contractId not found.');
      final data = snap.data()!;
      if (data['company_id'] != _user.companyId) {
        throw StateError('Cross-tenant write blocked.');
      }
      final items = (data['commission_items'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final item in items) {
        if (item['side'] == side) {
          if (paid != null) item['paid'] = paid;
          if (confirmed != null) item['confirmed'] = confirmed;
        }
      }
      txn.update(ref, {'commission_items': items});
    });
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

      // 3. WRITE the whole array back (Firestore can't patch one array item),
      //    together with the queryable due-date mirror it describes. Paying an
      //    installment is exactly when a contract stops being overdue, so the
      //    mirror has to move in the same write or the overdue list would keep
      //    showing it.
      final next = contract.copyWith(installments: updated);
      txn.update(contractRef, {
        'installments': updated.map((i) => i.toJson()).toList(),
        'earliest_pending_due': next.earliestPendingDue == null
            ? null
            : Timestamp.fromDate(next.earliestPendingDue!),
      });

      // 4. Adjust collected revenue accordingly, atomically.
      final wasReceived = oldStatus == PaymentStatus.receivedFromTenant;
      final nowReceived = newStatus == PaymentStatus.receivedFromTenant;
      num delta = 0;
      if (!wasReceived && nowReceived) delta = contract.rentAmount;
      if (wasReceived && !nowReceived) delta = -contract.rentAmount;

      if (delta != 0) {
        _bumpStats(txn, data['branch'] as String? ?? '', {
          'collected_revenue': FieldValue.increment(delta),
          'collected_${_cur(contract)}': FieldValue.increment(delta),
        });
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

/// Every contract the user may see, kept live.
///
/// DEPRECATED for screens. It opens an unbounded listener: a company with
/// 10,000 contracts downloads all of them, on every launch, on every device.
/// Use [pagedContractsProvider] for a list, [contractProvider] for one, or one
/// of the targeted providers below.
final contractsStreamProvider = StreamProvider<List<Contract>>((ref) {
  return ref.watch(contractRepositoryProvider).watchContracts();
});

/// One contract, kept live. Costs a single document read.
final contractProvider =
    StreamProvider.family<Contract?, String>((ref, id) {
  return ref.watch(contractRepositoryProvider).watchContract(id);
});

/// Rent contracts in arrears — only those, not the whole book.
final overdueContractsProvider =
    FutureProvider<List<RentContract>>((ref) {
  return ref.watch(contractRepositoryProvider).fetchOverdue();
});

/// Rent contracts still holding a deposit.
final guaranteeContractsProvider =
    FutureProvider<List<RentContract>>((ref) {
  return ref.watch(contractRepositoryProvider).fetchGuarantees();
});

/// Sale contracts created this calendar month — what the commission screen
/// shows, and nothing else.
final monthSalesProvider = FutureProvider<List<SaleContract>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(contractRepositoryProvider)
      .fetchSalesSince(DateTime(now.year, now.month));
});

/// How many contracts were created this calendar month. An aggregate query, so
/// it costs a few reads rather than one per contract.
final contractsThisMonthProvider = FutureProvider<int>((ref) {
  final now = DateTime.now();
  return ref
      .watch(contractRepositoryProvider)
      .countCreatedSince(DateTime(now.year, now.month));
});

/// ---------------------------------------------------------------------------
/// Paged list
/// ---------------------------------------------------------------------------

/// A page-at-a-time contract list with a `loadMore`.
///
/// Firestore pages by CURSOR, not by offset: each page starts after the last
/// document of the previous one. That keeps every page the same cost, and stops
/// a contract created mid-scroll from shifting a row across the boundary and
/// making it appear twice.
class PagedContracts {
  const PagedContracts({
    this.items = const [],
    this.hasMore = true,
    this.loading = false,
  });

  final List<Contract> items;
  final bool hasMore;
  final bool loading;

  PagedContracts copyWith({
    List<Contract>? items,
    bool? hasMore,
    bool? loading,
  }) =>
      PagedContracts(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
      );
}

class PagedContractsNotifier extends StateNotifier<PagedContracts> {
  PagedContractsNotifier(this._repo, this._type)
      : super(const PagedContracts()) {
    loadMore();
  }

  final ContractRepository _repo;
  final ContractType? _type;

  static const _pageSize = 20;

  /// The last document of the newest page — the cursor for the next one.
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    try {
      final snap = await _repo.fetchPage(
        type: _type,
        after: _cursor,
        limit: _pageSize,
      );
      if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
      state = PagedContracts(
        items: [
          ...state.items,
          ...snap.docs.map((d) => Contract.fromJson(d.id, d.data())),
        ],
        // A short page means the end; a full one might still have more.
        hasMore: snap.docs.length == _pageSize,
        loading: false,
      );
    } catch (_) {
      // Leave what is already on screen and let the user retry by scrolling.
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  /// Drops everything and re-reads from the top — after a create or delete.
  Future<void> refresh() async {
    _cursor = null;
    state = const PagedContracts();
    await loadMore();
  }
}

/// Counters accumulated over a set of contracts, for [ContractRepository
/// .recalculateStats]. One of these stands for the company and one for each
/// branch, so the same arithmetic produces both and they cannot disagree.
class _Tally {
  final Map<String, num> _amounts = {};
  int _contracts = 0;
  int _rent = 0;
  int _sale = 0;

  void add(Map<String, num> amounts) {
    amounts.forEach((k, v) => _amounts[k] = (_amounts[k] ?? 0) + v);
  }

  void count(ContractType type) {
    _contracts++;
    if (type == ContractType.rent) {
      _rent++;
    } else {
      _sale++;
    }
  }

  /// Every key is written even when it tallied to nothing: a repair that left
  /// absent keys alone would leave a counter that had drifted upward exactly
  /// where it was.
  Map<String, dynamic> toJson(String companyId) => {
        'company_id': companyId,
        'contract_count': _contracts,
        'rent_contract_count': _rent,
        'sale_contract_count': _sale,
        'total_revenue': _amounts['total_revenue'] ?? 0,
        'collected_revenue': _amounts['collected_revenue'] ?? 0,
        'collected_iqd': _amounts['collected_iqd'] ?? 0,
        'collected_usd': _amounts['collected_usd'] ?? 0,
        'guarantee_iqd': _amounts['guarantee_iqd'] ?? 0,
        'guarantee_usd': _amounts['guarantee_usd'] ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      };
}

final pagedContractsProvider = StateNotifierProvider.family<
    PagedContractsNotifier, PagedContracts, ContractType?>((ref, type) {
  return PagedContractsNotifier(ref.watch(contractRepositoryProvider), type);
});

/// The pre-aggregated stats the dashboard reads (one document, kept live).
///
/// Company-wide for an admin who sees the whole company, and the branch mirror
/// for everyone else — every other query behind the app is already scoped that
/// way, and these counters were the last thing still showing a branch admin
/// figures from branches they cannot open.
final companyStatsProvider = StreamProvider<CompanyStats?>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  if (user.companyId.isEmpty) return Stream.value(null);
  final company = db.collection('company_stats').doc(user.companyId);
  final doc = user.isCompanyWide
      ? company
      : company
          .collection('branches')
          .doc(ContractRepository.branchKey(user.branch));
  // A branch with no mirror yet reads as zero rather than null, so a dashboard
  // shows a branch that has done nothing as empty instead of falling back to
  // the company's numbers.
  return doc.snapshots().map((s) => s.exists
      ? CompanyStats.fromJson(user.companyId, s.data()!)
      : (user.isCompanyWide ? null : CompanyStats.empty(user.companyId)));
});
