import 'package:flutter_test/flutter_test.dart';

import 'package:aqarat/data/contract_repository.dart';
import 'package:aqarat/models/company_stats_model.dart';
import 'package:aqarat/models/contract_model.dart';
import 'package:aqarat/models/enums.dart';

/// The dashboard no longer adds up every contract on the device — it reads
/// running counters instead. That is only faster if the counters are RIGHT, and
/// a counter is wrong the moment one of create / edit / delete forgets to move
/// it. These tests pin the arithmetic.
///
/// They also cover `earliest_pending_due`, the field that lets the overdue list
/// be a query rather than a scan. If it drifts out of step with the installment
/// array, a paid tenant stays on the overdue list — or worse, a late one falls
/// off it.

RentContract _rent({
  Currency currency = Currency.iqd,
  num rentAmount = 100,
  num guarantee = 500,
  bool guaranteeReturned = false,
  List<Installment>? installments,
}) =>
    RentContract(
      id: 'c1',
      companyId: 'co',
      agentId: 'a',
      createdAt: DateTime(2026, 1, 1),
      party1Name: 'owner',
      party1Mobile: '',
      party2Name: 'tenant',
      party2Mobile: '',
      propertyType: 'house',
      projectName: 'p',
      propertyNumber: '1',
      area: 100,
      rentAmount: rentAmount,
      currency: currency,
      rentalPeriodMonths: 12,
      downPayment: 0,
      downPaymentMonths: 0,
      startDate: DateTime(2026, 1, 1),
      handoverDate: DateTime(2026, 1, 1),
      paymentFrequencyMonths: 1,
      guaranteeAmount: guarantee,
      gracePeriod: '',
      rentalPurpose: '',
      lateFeePerDay: 0,
      guaranteeReturned: guaranteeReturned,
      installments: installments ??
          RentContract.buildSchedule(DateTime(2026, 1, 1)),
    );

Installment _inst(int month, int year, PaymentStatus status) => Installment(
      monthNumber: month,
      dueDate: DateTime(year, month, 1),
      status: status,
    );

void main() {
  group('earliest pending due', () {
    test('is the earliest unpaid installment', () {
      final c = _rent(installments: [
        _inst(1, 2026, PaymentStatus.deliveredToOwner),
        _inst(2, 2026, PaymentStatus.pending),
        _inst(3, 2026, PaymentStatus.pending),
      ]);
      expect(c.earliestPendingDue, DateTime(2026, 2, 1));
    });

    test('ignores order in the array', () {
      // Nothing guarantees the stored array is sorted.
      final c = _rent(installments: [
        _inst(5, 2026, PaymentStatus.pending),
        _inst(2, 2026, PaymentStatus.pending),
      ]);
      expect(c.earliestPendingDue, DateTime(2026, 2, 1));
    });

    test('is null once everything is settled', () {
      final c = _rent(installments: [
        _inst(1, 2026, PaymentStatus.receivedFromTenant),
        _inst(2, 2026, PaymentStatus.deliveredToOwner),
      ]);
      expect(c.earliestPendingDue, isNull);
    });

    test('a received installment does not count as pending', () {
      // Money collected from the tenant but not yet handed to the owner is
      // still settled as far as chasing the tenant goes.
      final c = _rent(installments: [
        _inst(1, 2026, PaymentStatus.receivedFromTenant),
        _inst(9, 2026, PaymentStatus.pending),
      ]);
      expect(c.earliestPendingDue, DateTime(2026, 9, 1));
    });

    test('round-trips through toJson', () {
      final c = _rent(installments: [
        _inst(1, 2026, PaymentStatus.deliveredToOwner),
        _inst(4, 2026, PaymentStatus.pending),
      ]);
      final back = RentContract.fromJson('c1', c.toJson());
      expect(back.earliestPendingDue, DateTime(2026, 4, 1));
    });
  });

  group('overdue as of a date', () {
    final c = _rent(rentAmount: 250, installments: [
      _inst(1, 2026, PaymentStatus.pending),
      _inst(2, 2026, PaymentStatus.pending),
      _inst(3, 2026, PaymentStatus.deliveredToOwner),
      _inst(4, 2026, PaymentStatus.pending),
    ]);

    test('counts only pending installments already past', () {
      final r = c.overdueAsOf(DateTime(2026, 3, 15));
      expect(r.count, 2);
      expect(r.amount, 500);
    });

    test('is empty before anything falls due', () {
      expect(c.overdueAsOf(DateTime(2025, 12, 1)).count, 0);
      expect(c.overdueAsOf(DateTime(2025, 12, 1)).amount, 0);
    });

    test('a settled installment never counts, however old', () {
      final r = c.overdueAsOf(DateTime(2027, 1, 1));
      expect(r.count, 3, reason: 'month 3 was delivered, so it is not overdue');
    });
  });

  group('stats counters', () {
    test('creating and deleting the same contract nets to zero', () {
      final c = _rent();
      final net = ContractRepository.sumAmounts(
        ContractRepository.statsAmounts(c, 1),
        ContractRepository.statsAmounts(c, -1),
      );
      for (final entry in net.entries) {
        expect(entry.value, 0, reason: '${entry.key} did not cancel out');
      }
    });

    test('a held deposit lands on its own currency', () {
      final iqd = ContractRepository.statsAmounts(
          _rent(currency: Currency.iqd, guarantee: 500), 1);
      expect(iqd['guarantee_iqd'], 500);
      expect(iqd.containsKey('guarantee_usd'), isFalse);

      final usd = ContractRepository.statsAmounts(
          _rent(currency: Currency.usd, guarantee: 500), 1);
      expect(usd['guarantee_usd'], 500);
    });

    test('a returned deposit stops counting', () {
      final held = ContractRepository.statsAmounts(_rent(guarantee: 500), 1);
      final returned = ContractRepository.statsAmounts(
          _rent(guarantee: 500, guaranteeReturned: true), 1);
      expect(held['guarantee_iqd'], 500);
      expect(returned['guarantee_iqd'], 0);
    });

    test('collected counts only what came in from the tenant', () {
      final c = _rent(rentAmount: 100, installments: [
        _inst(1, 2026, PaymentStatus.receivedFromTenant),
        _inst(2, 2026, PaymentStatus.receivedFromTenant),
        _inst(3, 2026, PaymentStatus.deliveredToOwner),
        _inst(4, 2026, PaymentStatus.pending),
      ]);
      expect(ContractRepository.statsAmounts(c, 1)['collected_iqd'], 200);
    });

    test('editing the currency moves BOTH counters', () {
      // The case a plain difference gets wrong: subtracting the new from the
      // old leaves the abandoned currency overstated for ever, because the two
      // sides do not even share a key.
      final before = _rent(currency: Currency.iqd, guarantee: 500);
      final after = _rent(currency: Currency.usd, guarantee: 500);

      final net = ContractRepository.sumAmounts(
        ContractRepository.statsAmounts(before, -1),
        ContractRepository.statsAmounts(after, 1),
      );

      expect(net['guarantee_iqd'], -500, reason: 'the dinar total must drop');
      expect(net['guarantee_usd'], 500, reason: 'the dollar total must rise');
    });
  });

  group('branch mirror', () {
    // The counters are mirrored per branch under a document named for the
    // branch. Firestore ids may not be empty or contain a slash, and branch
    // names are typed by hand — a key that changed between the write and the
    // read would leave a branch reading someone else's numbers, or none.
    test('a branch name becomes a usable document id', () {
      expect(ContractRepository.branchKey('هەولێر'), 'هەولێر');
      expect(ContractRepository.branchKey('  سلێمانی  '), 'سلێمانی');
    });

    test('the ids Firestore rejects are encoded', () {
      expect(ContractRepository.branchKey(''), '_none',
          reason: 'a company with no branches still needs one document');
      expect(ContractRepository.branchKey('   '), '_none');
      expect(ContractRepository.branchKey('a/b'), 'a_b',
          reason: 'a slash would start a subcollection path');
    });

    test('the key is stable, so a write and a read agree', () {
      for (final name in ['هەولێر', '', 'a/b', ' دهۆک ']) {
        expect(ContractRepository.branchKey(name),
            ContractRepository.branchKey(ContractRepository.branchKey(name)),
            reason: 're-encoding an already-encoded key must not move it');
      }
    });

    test('a branch with no contracts yet reads as zero, not as the company',
        () {
      final empty = CompanyStats.empty('acme');
      expect(empty.contractCount, 0);
      expect(empty.collectedIqd, 0);
      expect(empty.collectedUsd, 0);
      expect(empty.guaranteeIqd, 0);
      expect(empty.guaranteeUsd, 0);
      expect(empty.totalRevenue, 0);
    });
  });
}
