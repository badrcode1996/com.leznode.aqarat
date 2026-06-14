import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/receipt_repository.dart';
import '../../models/enums.dart';
import '../../models/receipt_model.dart';
import '../../services/pdf/receipt_pdf_service.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _appBg = Color(0xFFF5F7FA);

/// Create an external receipt (پسولەی دەرەکی): money received or paid.
class CreateReceiptScreen extends ConsumerStatefulWidget {
  const CreateReceiptScreen({super.key, required this.type});

  /// externalReceive or externalPay.
  final ReceiptType type;

  @override
  ConsumerState<CreateReceiptScreen> createState() =>
      _CreateReceiptScreenState();
}

class _CreateReceiptScreenState extends ConsumerState<CreateReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  final _note = TextEditingController();

  Currency _currency = Currency.iqd;
  DateTime _date = DateTime.now();
  bool _busy = false;
  static final _df = DateFormat('yyyy/MM/dd');

  bool get _isPay => widget.type.isPayment;

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
    final draft = Receipt(
      id: '',
      companyId: user.companyId,
      agentId: user.agentId,
      agentName: user.displayName,
      branch: user.branch,
      type: widget.type,
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
    try {
      final saved = await ref.read(receiptRepositoryProvider).createReceipt(draft);
      final company = ref.read(currentCompanyProvider).value;
      if (mounted) {
        Navigator.pop(context);
        await ReceiptPdfService.printReceipt(saved, company: company);
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
        title: Text(_isPay ? 'پسولەی پارەدان' : 'پسولەی پارە وەرگرتن'),
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
                    : const Text('دروستکردن و پرینت'),
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
