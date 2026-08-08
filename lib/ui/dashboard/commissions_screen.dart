import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _appBg => AppColors.current.pageBg;
Color get _green => AppColors.current.success;
Color get _blue => AppColors.current.info;

/// Lists every commission item across sale contracts (two per contract — seller
/// + buyer). Each shows the calculated amount and the actual paid amount, which
/// can be edited and confirmed. Only confirmed items count toward the total.
class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    // Commission resets monthly, so only this month's sale contracts are
    // needed — not every contract the company ever wrote.
    final async = ref.watch(monthSalesProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(S.commissions,
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
        data: (sales) {
          final pairs = <({SaleContract contract, CommissionItem item})>[];
          for (final c in sales) {
            for (final item in c.commissionItems) {
              pairs.add((contract: c, item: item));
            }
          }
          if (pairs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.percent_rounded,
                      size: 72, color: AppColors.current.divider),
                  const SizedBox(height: 16),
                  Text(S.noCommissions,
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
            itemCount: pairs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _CommissionCard(contract: pairs[i].contract, item: pairs[i].item),
          );
        },
      ),
    );
  }
}

class _CommissionCard extends ConsumerWidget {
  const _CommissionCard({required this.contract, required this.item});
  final SaleContract contract;
  final CommissionItem item;

  String get _partyName =>
      item.side == 1 ? contract.party1Name : contract.party2Name;
  String get _sideLabel => item.side == 1 ? S.seller : S.buyer;
  num get _calculated => contract.totalPrice * contract.commissionRate / 100;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: _numText(item.paid));
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.receivedAmount,
            style:
                TextStyle(color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                S.estimatedAmount('${CommissionsScreen._money.format(_calculated)} ${contract.currency.uiLabel}'),
                style: TextStyle(fontSize: 12, color: AppColors.current.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: S.actualAmount,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.cancel,
                  style: TextStyle(color: AppColors.current.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDarkBlue,
                foregroundColor: Colors.white),
            onPressed: () =>
                Navigator.pop(ctx, num.tryParse(controller.text.trim()) ?? 0),
            child: Text(S.saveShort),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await _run(context, ref, paid: result);
  }

  Future<void> _run(BuildContext context, WidgetRef ref,
      {num? paid, bool? confirmed}) async {
    try {
      await ref.read(contractRepositoryProvider).updateCommissionItem(
            contract.id,
            item.side,
            paid: paid,
            confirmed: confirmed,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.error(e)), backgroundColor: AppColors.current.danger));
      }
    }
  }

  static String _numText(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final confirmed = item.confirmed;
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
                backgroundColor: _blue.withValues(alpha: 0.12),
                child: Icon(Icons.percent_rounded, color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_partyName  ·  $_sideLabel',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.current.textStrong),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(S.contractNumber(contract.contractNumber),
                        style: TextStyle(
                            color: AppColors.current.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (confirmed ? _green : AppColors.current.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(confirmed ? S.confirmedLabel : S.pendingLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: confirmed ? _green : AppColors.current.warning)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _amountBox(S.estimated,
                    '${CommissionsScreen._money.format(_calculated)} ${contract.currency.uiLabel}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _amountBox(S.receivedLabel,
                    '${CommissionsScreen._money.format(item.paid)} ${contract.currency.uiLabel}',
                    highlight: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.current.textStrong,
                    side: BorderSide(color: AppColors.current.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(S.editShort),
                  onPressed: () => _edit(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmed ? AppColors.current.divider : _green,
                    foregroundColor:
                        confirmed ? AppColors.current.textBody : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                      confirmed ? Icons.undo_rounded : Icons.check_rounded,
                      size: 18),
                  label: Text(confirmed ? S.removeAction : S.confirmAction),
                  onPressed: () => _run(context, ref, confirmed: !confirmed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountBox(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? _blue.withValues(alpha: 0.08) : AppColors.current.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: AppColors.current.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: highlight ? _blue : AppColors.current.textStrong),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
