import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/receipt_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../models/receipt_model.dart';
import '../receipts/receipt_preview_screen.dart';
import '../widgets/processing_dialog.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

// ڕەنگە سەرەکییەکان
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;

/// Grid of the 12 rent installments. Tapping the status chip cycles
/// pending → received → delivered and persists via the transactional
/// [ContractRepository.updateInstallmentStatus] (which also updates stats).
///
/// A payment may cover several months at once — the dialog asks how many, and
/// that run of months is settled together on one voucher.
class InstallmentGrid extends ConsumerWidget {
  const InstallmentGrid({super.key, required this.contract});

  final RentContract contract;

  static final _date = DateFormat('yyyy/MM/dd');

  PaymentStatus _next(PaymentStatus s) => switch (s) {
    PaymentStatus.pending => PaymentStatus.receivedFromTenant,
    PaymentStatus.receivedFromTenant => PaymentStatus.deliveredToOwner,
    PaymentStatus.deliveredToOwner => PaymentStatus.pending,
  };

  // زیادکردنی ئایکۆن و گۆڕینی ڕەنگەکان بۆ شێوازی مۆدێرنتر
  (String, Color, IconData) _style(PaymentStatus s) => switch (s) {
    PaymentStatus.pending => (S.instPending, AppColors.current.textMuted, Icons.schedule_rounded),
    PaymentStatus.receivedFromTenant => (S.instReceived, AppColors.current.warning, Icons.inbox_rounded), // پرتەقاڵی/زەردێکی جوان
    PaymentStatus.deliveredToOwner => (S.instDelivered, AppColors.current.success, Icons.done_all_rounded), // سەوزێکی مۆدێرن
  };

  /// Asks how many months the payment covers, for an optional note/code, and
  /// whether the receipt PDF should be printed. Returns `(note, months,
  /// print)`, or null if the user cancelled (abort the action). When `print`
  /// is false the receipt is still saved — it just isn't opened/printed (for
  /// tenants/owners who don't need a paper voucher).
  ///
  /// [maxMonths] is how many installments are left from the tapped one, so a
  /// run can never be asked for that runs off the end of the contract.
  Future<({String note, int months, bool print})?> _askNote(
      BuildContext context, bool isReceive, int maxMonths) {
    final controller = TextEditingController();
    var months = 1;
    return showDialog<({String note, int months, bool print})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(isReceive ? S.collectRent : S.payRentBack),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A tenant often pays two or three months together, and wants
              // one voucher for them. The months run on from the one tapped.
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: months,
                decoration: InputDecoration(labelText: S.monthsToSettle),
                items: [
                  for (var m = 1; m <= maxMonths; m++)
                    DropdownMenuItem(value: m, child: Text('$m')),
                ],
                onChanged: (v) => setDialog(() => months = v ?? 1),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: S.noteOrCode,
                  hintText: S.noteOrCodeHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.cancel),
            ),
            // بەبێ پرینتی پسولە — کردارەکە ئەنجام دەدرێت و پسولە تۆمار دەکرێت،
            // بەڵام PDF ـەکە ناکرێتەوە (بۆ کرێچی/خاوەن خانووی پسولەی ناوێت).
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx,
                  (note: controller.text.trim(), months: months, print: false)),
              child: Text(S.withoutReceipt),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx,
                  (note: controller.text.trim(), months: months, print: true)),
              child: Text(S.createReceipt),
            ),
          ],
        ),
      ),
    );
  }

  /// Tells the user nothing was recorded because one month of the run had
  /// already been dealt with. A dialog rather than a snackbar: the action they
  /// asked for did not happen, and that should not scroll away.
  Future<void> _sayConflict(BuildContext context, int month) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(S.attention),
          content: Text(S.monthAlreadySettled(month)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.ok),
            ),
          ],
        ),
      );

  Future<void> _cycle(BuildContext context, WidgetRef ref, RentContract live,
      Installment inst) async {
    final newStatus = _next(inst.status);

    // Auto-generate the matching rent receipt on the forward transitions; ask
    // for an optional note/code first (cancel aborts the whole action).
    final makesReceipt = newStatus == PaymentStatus.receivedFromTenant ||
        newStatus == PaymentStatus.deliveredToOwner;
    final isReceive = newStatus == PaymentStatus.receivedFromTenant;
    String note = '';
    bool printReceipt = true;
    // Only a payment settles months in a run; stepping an installment back to
    // pending is a correction of that one month.
    var months = 1;
    if (makesReceipt) {
      final left = live.installments
          .where((i) => i.monthNumber >= inst.monthNumber)
          .length;
      final entered = await _askNote(context, isReceive, left);
      if (entered == null) return; // cancelled
      note = entered.note;
      printReceipt = entered.print;
      months = entered.months;
    }
    final monthNumbers = [
      for (var m = 0; m < months; m++) inst.monthNumber + m,
    ];
    // The last month settled decides the period the voucher covers.
    final lastDue = live.installments
        .firstWhere((i) => i.monthNumber == monthNumbers.last)
        .dueDate;

    try {
      await ref.read(contractRepositoryProvider).updateInstallmentStatus(
        contractId: contract.id,
        monthNumbers: monthNumbers,
        newStatus: newStatus,
      );

      if (makesReceipt) {
        if (!context.mounted) return;
        final user = ref.read(currentUserProvider);
        final draft = Receipt(
          id: '',
          companyId: user.companyId,
          agentId: user.agentId,
          agentName: user.displayName,
          branch: user.branch,
          type: isReceive ? ReceiptType.rentReceive : ReceiptType.rentPay,
          receiptNumber: 0,
          date: DateTime.now(),
          personName: isReceive ? contract.party2Name : contract.party1Name,
          // One voucher for the whole run: the months' rent added up, over a
          // period that ends with the last month it covers.
          amount: live.rentAmount * months,
          currency: contract.currency,
          paymentPurpose:
              Receipt.rentPurpose(inst.dueDate, lastDueDate: lastDue),
          note: note,
          contractId: contract.id,
          monthNumber: inst.monthNumber,
          createdAt: DateTime.now(),
        );
        // Save the receipt behind a brief "please wait" spinner.
        final saved = await showProcessingWhile(
          context,
          () => ref.read(receiptRepositoryProvider).createReceipt(draft),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.receiptCreated(
                  isReceive ? S.receiptRentReceive : S.receiptRentPay,
                  saved.receiptNumber)),
              backgroundColor: AppColors.current.success,
            ),
          );
        }
        // Open the receipt preview (view + print + share) right away — unless
        // the user chose "بەبێ پسولە".
        if (printReceipt && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReceiptPreviewScreen(receipt: saved),
            ),
          );
        }
      }
    } on InstallmentConflict catch (e) {
      // Another device got to one of these months first. Nothing was written.
      if (context.mounted) await _sayConflict(context, e.month);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.error(e)),
            backgroundColor: AppColors.current.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    // Watch THIS contract so a status change shows immediately — the passed-in
    // `contract` is only the initial snapshot. One document read; this used to
    // watch every contract in the company and then search the list for it.
    //
    // valueOrNull, not .value: .value rethrows on the stream's error state and
    // would crash this grid to a grey ErrorWidget; falling back to the
    // passed-in snapshot is fine.
    final live = switch (ref.watch(contractProvider(contract.id)).valueOrNull) {
      final RentContract c => c,
      _ => contract,
    };
    return GridView.builder(
      padding: const EdgeInsets.all(16), // تۆزێک بۆشایی زیاتر لە دەوریدا
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: live.installments.length,
      // زیادکردنی بەرزییەکە بۆ 120 بۆ ئەوەی دیزاینە نوێیەکەی بەجوانی تێدا جێببێتەوە
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 120,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) {
        final inst = live.installments[i];
        final (label, color, icon) = _style(inst.status);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.current.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _cycle(context, ref, live, inst),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // مانگ و ئایکۆنی دۆخەکە
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.monthNumber(inst.monthNumber),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.current.textStrong),
                        ),
                        Icon(icon, size: 20, color: color),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // بەروار بە ئایکۆنێکی بچووکەوە
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.current.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _date.format(inst.dueDate),
                          style: TextStyle(fontSize: 12, color: AppColors.current.textMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // تاگی دۆخەکە بە پانتایی کارتەکە
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}