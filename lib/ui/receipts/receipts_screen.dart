import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/receipt_repository.dart';
import '../../models/receipt_model.dart';
import '../../services/pdf/receipt_pdf_remote.dart';
import 'create_receipt_screen.dart';
import 'receipt_preview_screen.dart';
import '../../theme/app_colors.dart';

Color get _accentYellow => AppColors.current.accent;
Color get _green => AppColors.current.success;

/// Reusable receipts body: two sub-tabs — rent receipts (کرێ) and external
/// receipts (دەرەکی). Rendered inside the Archive screen's "پسولەکان" tab — no
/// Scaffold/AppBar of its own so it can nest under the Archive's top tabs.
class ReceiptsArchiveBody extends StatelessWidget {
  const ReceiptsArchiveBody({super.key});

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.current.card,
            elevation: 1,
            child: TabBar(
              indicatorColor: _accentYellow,
              indicatorWeight: 3,
              labelColor: AppColors.current.textStrong,
              unselectedLabelColor: AppColors.current.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [
                Tab(text: 'پسولەی کرێ'),
                Tab(text: 'پسولەی دەرەکی'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ReceiptsList(rent: true),
                _ReceiptsList(rent: false),
              ],
            ),
          ),
        ],
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
    watchPalette(context);
    final async = ref.watch(receiptsStreamProvider);
    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
      error: (e, _) => Center(child: Text('هەڵە: $e')),
      data: (all) {
        final list = all.where((r) => r.type.isRent == rent).toList();
        if (list.isEmpty) {
          return Center(
            child: Text(rent ? 'هیچ پسولەیەکی کرێ نییە' : 'هیچ پسولەیەکی دەرەکی نییە',
                style: TextStyle(
                    color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
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
        title: Text('سڕینەوەی پسولە',
            style: TextStyle(
                color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: Text(
            'دڵنیایت لە سڕینەوەی پسولە #${receipt.receiptNumber}؟ ئەم کردارە ناگەڕێتەوە.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('پاشگەزبوونەوە',
                style: TextStyle(color: AppColors.current.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.current.danger,
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
          SnackBar(
              content: const Text('پسولە سڕایەوە'), backgroundColor: _green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('هەڵە: $e'),
              backgroundColor: AppColors.current.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final isPay = receipt.type.isPayment;
    final color = isPay ? AppColors.current.danger : _green;
    final isAdmin = ref.watch(currentUserProvider).isAdmin;
    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReceiptPreviewScreen(receipt: receipt),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(isPay ? Icons.north_east : Icons.south_west, color: color),
        ),
        title: Text('${receipt.type.titleKu}  ·  #${receipt.receiptNumber}',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.current.textStrong, fontSize: 14)),
        subtitle: Text(
            '${receipt.personName} · ${_money.format(receipt.amount)} ${receipt.currency.label}\n${_df.format(receipt.date)}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'پرینت',
              icon: Icon(Icons.print_outlined, color: AppColors.current.textStrong),
              onPressed: () => ReceiptPdfRemote.printReceipt(receipt.id),
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.current.textMuted),
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
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            color: AppColors.current.textStrong, size: 20),
                        const SizedBox(width: 12),
                        const Text('دەستکاری'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: AppColors.current.danger, size: 20),
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
