import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/receipt_repository.dart';
import '../../models/enums.dart';
import '../../models/receipt_model.dart';
import '../widgets/processing_dialog.dart';
import 'receipt_preview_screen.dart';

const Color _appBg = Color(0xFFF5F7FA);

/// Create an external receipt (پسولەی دەرەکی) — or edit any existing receipt
/// when [existing] is supplied (admin only). In edit mode the type is fixed by
/// the receipt itself and the number/metadata are preserved.
class CreateReceiptScreen extends ConsumerStatefulWidget {
  const CreateReceiptScreen({super.key, required this.type, this.existing});

  /// externalReceive or externalPay (ignored when [existing] is set).
  final ReceiptType type;

  /// When non-null the screen edits this receipt instead of creating one.
  final Receipt? existing;

  @override
  ConsumerState<CreateReceiptScreen> createState() =>
      _CreateReceiptScreenState();
}

class _CreateReceiptScreenState extends ConsumerState<CreateReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _person = TextEditingController(text: _editing?.personName ?? '');
  late final _amount =
      TextEditingController(text: _editing?.amount.toString() ?? '');
  late final _purpose =
      TextEditingController(text: _editing?.paymentPurpose ?? '');
  late final _note = TextEditingController(text: _editing?.note ?? '');

  late Currency _currency = _editing?.currency ?? Currency.iqd;
  late DateTime _date = _editing?.date ?? DateTime.now();
  bool _busy = false;
  static final _df = DateFormat('yyyy/MM/dd');

  Receipt? get _editing => widget.existing;
  bool get _isEdit => _editing != null;
  ReceiptType get _type => _editing?.type ?? widget.type;
  bool get _isPay => _type.isPayment;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _purpose.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final user = ref.read(currentUserProvider);
    final repo = ref.read(receiptRepositoryProvider);
    try {
      if (_isEdit) {
        // Preserve immutable fields; overwrite only what the form edits.
        final updated = Receipt(
          id: _editing!.id,
          companyId: _editing!.companyId,
          agentId: _editing!.agentId,
          agentName: _editing!.agentName,
          branch: _editing!.branch,
          type: _editing!.type,
          receiptNumber: _editing!.receiptNumber,
          date: _date,
          personName: _person.text.trim(),
          amount: num.tryParse(_amount.text.trim()) ?? 0,
          currency: _currency,
          paymentPurpose: _purpose.text.trim(),
          note: _note.text.trim(),
          contractId: _editing!.contractId,
          monthNumber: _editing!.monthNumber,
          createdAt: _editing!.createdAt,
        );
        await repo.updateReceipt(updated);
        if (mounted) Navigator.pop(context);
      } else {
        final draft = Receipt(
          id: '',
          companyId: user.companyId,
          agentId: user.agentId,
          agentName: user.displayName,
          branch: user.branch,
          type: _type,
          receiptNumber: 0,
          date: _date,
          personName: _person.text.trim(),
          amount: num.tryParse(_amount.text.trim()) ?? 0,
          currency: _currency,
          paymentPurpose: _purpose.text.trim(),
          note: _note.text.trim(),
          contractId: '',
          monthNumber: 0,
          createdAt: DateTime.now(),
        );
        // Save behind a brief "please wait" spinner, then replace the form with
        // the receipt preview (view + print + share).
        final saved = await showProcessingWhile(
          context,
          () => repo.createReceipt(draft),
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReceiptPreviewScreen(receipt: saved),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(_isEdit
            ? 'دەستکاری پسولە #${_editing!.receiptNumber}'
            : (_isPay ? 'پسولەی پارەدان' : 'پسولەی پارە وەرگرتن')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _person,
                decoration: InputDecoration(
                    labelText: _isPay ? 'پێدرا بە بەڕێز' : 'وەرمگرت لە بەڕێز'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'بڕی پارە'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Currency>(
                isExpanded: true,
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'دراو'),
                items: Currency.values
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? Currency.iqd),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purpose,
                decoration: const InputDecoration(labelText: 'لە بڕی (مەبەست)'),
                validator: _req,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'تێبینی'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('بەروار: ${_df.format(_date)}')),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('بەروار'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'پاشەکەوتکردن' : 'دروستکردن و پرینت'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'پێویستە' : null;
}
