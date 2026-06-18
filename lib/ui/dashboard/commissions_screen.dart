import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _appBg = Color(0xFFF5F7FA);
const Color _green = Color(0xFF10B981);
const Color _blue = Color(0xFF0EA5E9);

/// Lists every commission item across sale contracts (two per contract — seller
/// + buyer). Each shows the calculated amount and the actual paid amount, which
/// can be edited and confirmed. Only confirmed items count toward the total.
class CommissionsScreen extends ConsumerWidget {
  const CommissionsScreen({super.key});

  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: const Text('عمولەکان',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _primaryDarkBlue)),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (all) {
          final pairs = <({SaleContract contract, CommissionItem item})>[];
          for (final c in all.whereType<SaleContract>()) {
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
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('هیچ عمولەیەک نییە',
                      style: TextStyle(
                          color: Colors.grey.shade600,
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
  String get _sideLabel => item.side == 1 ? 'فرۆشیار' : 'کڕیار';
  num get _calculated => contract.totalPrice * contract.commissionRate / 100;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: _numText(item.paid));
    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('بڕی وەرگیراو',
            style:
                TextStyle(color: _primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'خەمڵێنراو: ${CommissionsScreen._money.format(_calculated)} ${contract.currency.label}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'بڕی ڕاستەقینە',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('پاشگەزبوونەوە',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDarkBlue,
                foregroundColor: Colors.white),
            onPressed: () =>
                Navigator.pop(ctx, num.tryParse(controller.text.trim()) ?? 0),
            child: const Text('پاشەکەوت'),
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
            content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  static String _numText(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmed = item.confirmed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                child: const Icon(Icons.percent_rounded, color: _blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_partyName  ·  $_sideLabel',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _primaryDarkBlue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('گرێبەست #${contract.contractNumber}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (confirmed ? _green : Colors.orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(confirmed ? 'کۆنفێرمکراو' : 'چاوەڕوان',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: confirmed ? _green : Colors.orange.shade800)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _amountBox('خەمڵێنراو',
                    '${CommissionsScreen._money.format(_calculated)} ${contract.currency.label}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _amountBox('وەرگیراو',
                    '${CommissionsScreen._money.format(item.paid)} ${contract.currency.label}',
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
                    foregroundColor: _primaryDarkBlue,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('ئیدیت'),
                  onPressed: () => _edit(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmed ? Colors.grey.shade200 : _green,
                    foregroundColor:
                        confirmed ? Colors.grey.shade800 : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                      confirmed ? Icons.undo_rounded : Icons.check_rounded,
                      size: 18),
                  label: Text(confirmed ? 'لابردن' : 'کۆنفێرم'),
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
        color: highlight ? _blue.withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: highlight ? _blue : _primaryDarkBlue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
