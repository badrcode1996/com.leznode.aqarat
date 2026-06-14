import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/receipt_repository.dart';
import '../../models/enums.dart';
import '../../models/receipt_model.dart';
import '../../services/pdf/receipt_pdf_service.dart';
import 'create_receipt_screen.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);
const Color _green = Color(0xFF10B981);

/// Receipts tab: list all receipts + create external ones.
class ReceiptsScreen extends ConsumerWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptsStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: const Text('پسولەکان',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentYellow,
        foregroundColor: _primaryDarkBlue,
        icon: const Icon(Icons.add),
        label: const Text('پسولەی دەرەکی',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _chooseExternal(context),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _primaryDarkBlue)),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('هیچ پسولەیەک نییە'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ReceiptCard(receipt: list[i]),
          );
        },
      ),
    );
  }

  void _chooseExternal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0x1A10B981),
                  child: Icon(Icons.south_west, color: _green)),
              title: const Text('پسولەی پارە وەرگرتن'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateReceiptScreen(
                            type: ReceiptType.externalReceive)));
              },
            ),
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.north_east, color: Colors.red.shade700)),
              title: const Text('پسولەی پارەدان'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateReceiptScreen(
                            type: ReceiptType.externalPay)));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends ConsumerWidget {
  const _ReceiptCard({required this.receipt});
  final Receipt receipt;

  static final _df = DateFormat('yyyy/MM/dd');
  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPay = receipt.type.isPayment;
    final color = isPay ? Colors.red.shade700 : _green;
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
        trailing: IconButton(
          tooltip: 'پرینت',
          icon: const Icon(Icons.print_outlined, color: _primaryDarkBlue),
          onPressed: () {
            final company = ref.read(currentCompanyProvider).value;
            ReceiptPdfService.printReceipt(receipt, company: company);
          },
        ),
      ),
    );
  }
}
