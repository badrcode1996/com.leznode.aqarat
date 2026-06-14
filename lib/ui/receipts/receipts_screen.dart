import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/receipt_repository.dart';
import '../../models/receipt_model.dart';
import '../../services/pdf/receipt_pdf_service.dart';
import 'create_receipt_screen.dart';
import 'receipt_preview_screen.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);
const Color _green = Color(0xFF10B981);

/// Receipts tab: two sub-tabs — rent receipts (کرێ) and external receipts
/// (دەرەکی). Creation lives in the central Quick Actions sheet.
class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _appBg,
        appBar: AppBar(
          title: const Text('پسولەکان',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: _primaryDarkBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: _accentYellow,
            indicatorWeight: 4,
            labelColor: _accentYellow,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: 'پسولەی کرێ'),
              Tab(text: 'پسولەی دەرەکی'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReceiptsList(rent: true),
            _ReceiptsList(rent: false),
          ],
        ),
      ),
    );
  }
}

/// One receipts sub-list, filtered to rent or external receipts.
class _ReceiptsList extends ConsumerWidget {
  const _ReceiptsList({required this.rent});
  final bool rent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptsStreamProvider);
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _primaryDarkBlue)),
      error: (e, _) => Center(child: Text('هەڵە: $e')),
      data: (all) {
        final list = all.where((r) => r.type.isRent == rent).toList();
        if (list.isEmpty) {
          return Center(
            child: Text(rent ? 'هیچ پسولەیەکی کرێ نییە' : 'هیچ پسولەیەکی دەرەکی نییە',
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.bold)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ReceiptCard(receipt: list[i]),
        );
      },
    );
  }
}

class _ReceiptCard extends ConsumerWidget {
  const _ReceiptCard({required this.receipt});
  final Receipt receipt;

  static final _df = DateFormat('yyyy/MM/dd');
  static final _money = NumberFormat.decimalPattern();

  Future<void> _edit(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateReceiptScreen(type: receipt.type, existing: receipt),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('سڕینەوەی پسولە',
            style: TextStyle(
                color: _primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: Text(
            'دڵنیایت لە سڕینەوەی پسولە #${receipt.receiptNumber}؟ ئەم کردارە ناگەڕێتەوە.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('پاشگەزبوونەوە',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(receiptRepositoryProvider).deleteReceipt(receipt);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('پسولە سڕایەوە'), backgroundColor: _green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('هەڵە: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPay = receipt.type.isPayment;
    final color = isPay ? Colors.red.shade700 : _green;
    final isAdmin = ref.watch(currentUserProvider).isAdmin;
    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          final company = ref.read(currentCompanyProvider).value;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ReceiptPreviewScreen(receipt: receipt, company: company),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(isPay ? Icons.north_east : Icons.south_west, color: color),
        ),
        title: Text('${receipt.type.titleKu}  ·  #${receipt.receiptNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _primaryDarkBlue, fontSize: 14)),
        subtitle: Text(
            '${receipt.personName} · ${_money.format(receipt.amount)} ${receipt.currency.label}\n${_df.format(receipt.date)}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'پرینت',
              icon: const Icon(Icons.print_outlined, color: _primaryDarkBlue),
              onPressed: () {
                final company = ref.read(currentCompanyProvider).value;
                ReceiptPdfService.printReceipt(receipt, company: company);
              },
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') {
                    _edit(context);
                  } else if (v == 'delete') {
                    _delete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            color: _primaryDarkBlue, size: 20),
                        SizedBox(width: 12),
                        Text('دەستکاری'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 12),
                        const Text('سڕینەوە'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
