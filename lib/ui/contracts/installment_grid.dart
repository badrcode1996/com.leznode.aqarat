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

  /// Asks the user for an optional note/code before a rent receipt is created,
  /// and whether the receipt PDF should be printed. Returns `(note, print)`, or
  /// null if the user cancelled (abort the action). When `print` is false the
  /// receipt is still saved — it just isn't opened/printed (for tenants/owners
  /// who don't need a paper voucher).
  Future<({String note, bool print})?> _askNote(
      BuildContext context, bool isReceive) {
    final controller = TextEditingController();
    return showDialog<({String note, bool print})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReceive ? S.collectRent : S.payRentBack),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: S.noteOrCode,
            hintText: S.noteOrCodeHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.cancel),
          ),
          // بەبێ پرینتی پسولە — کردارەکە ئەنجام دەدرێت و پسولە تۆمار دەکرێت،
          // بەڵام PDF ـەکە ناکرێتەوە (بۆ کرێچی/خاوەن خانووی پسولەی ناوێت).
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(ctx, (note: controller.text.trim(), print: false)),
            child: Text(S.withoutReceipt),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, (note: controller.text.trim(), print: true)),
            child: Text(S.createReceipt),
          ),
        ],
      ),
    );
  }

  Future<void> _cycle(BuildContext context, WidgetRef ref, Installment inst) async {
    final newStatus = _next(inst.status);

    // Auto-generate the matching rent receipt on the forward transitions; ask
    // for an optional note/code first (cancel aborts the whole action).
    final makesReceipt = newStatus == PaymentStatus.receivedFromTenant ||
        newStatus == PaymentStatus.deliveredToOwner;
    final isReceive = newStatus == PaymentStatus.receivedFromTenant;
    String note = '';
    bool printReceipt = true;
    if (makesReceipt) {
      final entered = await _askNote(context, isReceive);
      if (entered == null) return; // cancelled
      note = entered.note;
      printReceipt = entered.print;
    }

    try {
      await ref.read(contractRepositoryProvider).updateInstallmentStatus(
        contractId: contract.id,
        monthNumber: inst.monthNumber,
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
          amount: contract.rentAmount,
          currency: contract.currency,
          paymentPurpose: Receipt.rentPurpose(inst.dueDate),
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
    // Watch the live contract from the stream so a status change shows
    // immediately — the passed-in `contract` is only the initial snapshot.
    var live = contract;
    // valueOrNull, not .value: .value rethrows on the stream's error state and
    // would crash this grid to a grey ErrorWidget; falling back to the passed-in
    // snapshot is fine.
    final contracts = ref.watch(contractsStreamProvider).valueOrNull;
    if (contracts != null) {
      for (final c in contracts) {
        if (c.id == contract.id && c is RentContract) {
          live = c;
          break;
        }
      }
    }
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
              onTap: () => _cycle(context, ref, inst),
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