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

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _appBg => AppColors.current.pageBg;
Color get _green => AppColors.current.success;
Color get _purple => AppColors.current.violet;

/// Itemised list of rent-contract guarantees (deposits). Each can be returned
/// to the tenant — which records a payment receipt and drops it from the
/// "still held" total on the dashboard.
class GuaranteesScreen extends ConsumerWidget {
  const GuaranteesScreen({super.key});

  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final async = ref.watch(contractsStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(S.guarantees,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e))),
        data: (all) {
          final items = all
              .whereType<RentContract>()
              .where((c) => c.guaranteeAmount > 0)
              .toList();
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined,
                      size: 72, color: AppColors.current.divider),
                  const SizedBox(height: 16),
                  Text(S.noGuarantees,
                      style: TextStyle(
                          color: AppColors.current.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _GuaranteeCard(contract: items[i]),
          );
        },
      ),
    );
  }
}

class _GuaranteeCard extends ConsumerWidget {
  const _GuaranteeCard({required this.contract});
  final RentContract contract;

  Future<void> _return(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.returnGuaranteeTitle,
            style:
                TextStyle(color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: Text(
            S.returnGuaranteeConfirm(contract.party2Name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.cancel,
                  style: TextStyle(color: AppColors.current.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.returnAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final user = ref.read(currentUserProvider);
    final draft = Receipt(
      id: '',
      companyId: user.companyId,
      agentId: user.agentId,
      agentName: user.displayName,
      branch: user.branch,
      type: ReceiptType.externalPay,
      receiptNumber: 0,
      date: DateTime.now(),
      personName: contract.party2Name,
      amount: contract.guaranteeAmount,
      currency: contract.currency,
      paymentPurpose: S.guaranteeOfProperty(contract.propertyNumber),
      note: '',
      contractId: contract.id,
      monthNumber: 0,
      createdAt: DateTime.now(),
    );

    try {
      final saved = await showProcessingWhile(context, () async {
        await ref
            .read(contractRepositoryProvider)
            .setGuaranteeReturned(contract.id, true);
        return ref.read(receiptRepositoryProvider).createReceipt(draft);
      });
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewScreen(receipt: saved),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final returned = contract.guaranteeReturned;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.current.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _purple.withValues(alpha: 0.12),
                child: Icon(Icons.shield_outlined, color: _purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.party2Name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.current.textStrong),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        S.contractAndProperty(contract.contractNumber, contract.propertyNumber),
                        style: TextStyle(
                            color: AppColors.current.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${GuaranteesScreen._money.format(contract.guaranteeAmount)} ${contract.currency.uiLabel}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.current.textStrong,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (returned ? _green : AppColors.current.textMuted)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(returned ? S.returnedLabel : S.atCompany,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: returned ? _green : AppColors.current.textBody)),
                  ),
                ],
              ),
            ],
          ),
          if (!returned) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: BorderSide(color: _green, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.assignment_return_outlined, size: 20),
                label: Text(S.returnGuaranteeTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _return(context, ref),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
