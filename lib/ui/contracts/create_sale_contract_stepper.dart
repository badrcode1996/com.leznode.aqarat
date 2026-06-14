import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);
const Color inputFillColor = Color(0xFFF3F4F6);

// فەنکشن بۆ دیزاینی فۆڕمەکان
InputDecoration modernInputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: primaryDarkBlue, size: 22) : null,
    filled: true,
    fillColor: inputFillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: accentYellow, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.red.shade300, width: 1),
    ),
  );
}

// فەنکشن بۆ دیزاینی دوگمە سەرەکییەکان
ButtonStyle modernButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: primaryDarkBlue,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 2,
  );
}

/// 3-step Stepper for creating a SALE contract (فرۆشتن/کڕین).
class CreateSaleContractStepper extends ConsumerStatefulWidget {
  const CreateSaleContractStepper({super.key});

  @override
  ConsumerState<CreateSaleContractStepper> createState() =>
      _CreateSaleContractStepperState();
}

class _CreateSaleContractStepperState extends ConsumerState<CreateSaleContractStepper> {
  int _step = 0;
  bool _saving = false;

  final _partiesKey = GlobalKey<FormState>();
  final _propertyKey = GlobalKey<FormState>();
  final _financialsKey = GlobalKey<FormState>();

  // Step 1 — parties
  final _party1Name = TextEditingController(); // فرۆشیار
  final _party1Mobile = TextEditingController();
  final _party2Name = TextEditingController(); // کڕیار
  final _party2Mobile = TextEditingController();
  // Step 2 — property
  final _propertyType = TextEditingController();
  final _projectName = TextEditingController();
  final _propertyNumber = TextEditingController();
  final _area = TextEditingController();
  // Step 3 — financials
  final _totalPrice = TextEditingController();
  final _downPayment = TextEditingController();
  final _paymentMethod = TextEditingController();
  final _lateFee = TextEditingController();
  final _withdrawal = TextEditingController();
  final _lawyer = TextEditingController();

  Currency _currency = Currency.iqd;
  DateTime _deliveryDate = DateTime.now();

  static final _date = DateFormat('yyyy/MM/dd');

  @override
  void dispose() {
    for (final c in [
      _party1Name, _party1Mobile, _party2Name, _party2Mobile, _propertyType,
      _projectName, _propertyNumber, _area, _totalPrice, _downPayment,
      _paymentMethod, _lateFee, _withdrawal, _lawyer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (!_financialsKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider);
    final contract = SaleContract(
      id: '',
      companyId: user.companyId,
      agentId: user.agentId,
      createdAt: DateTime.now(),
      party1Name: _party1Name.text.trim(),
      party1Mobile: _party1Mobile.text.trim(),
      party2Name: _party2Name.text.trim(),
      party2Mobile: _party2Mobile.text.trim(),
      propertyType: _propertyType.text.trim(),
      projectName: _projectName.text.trim(),
      propertyNumber: _propertyNumber.text.trim(),
      area: _n(_area),
      totalPrice: _n(_totalPrice),
      downPayment: _n(_downPayment),
      currency: _currency,
      paymentMethod: _paymentMethod.text.trim(),
      lateFeePerDay: _n(_lateFee),
      withdrawalAmount: _n(_withdrawal),
      lawyer: _lawyer.text.trim(),
      deliveryDate: _deliveryDate,
      agentName: user.displayName,
    );

    try {
      final id = await ref.read(contractRepositoryProvider).createContract(contract);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('گرێبەستی فرۆشتن دروستکرا ($id)'), backgroundColor: Colors.green));
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('سەرکەوتوو نەبوو: $e'), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onContinue() {
    final keys = [_partiesKey, _propertyKey, _financialsKey];
    if (!keys[_step].currentState!.validate()) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: const Text('گرێبەستی فرۆشتنی نوێ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Theme(
        // ڕێکخستنی ڕەنگی Stepper
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: primaryDarkBlue, // ڕەنگی هەنگاوە چالاکەکان
          ),
        ),
        child: Stepper(
          currentStep: _step,
          type: StepperType.vertical,
          physics: const BouncingScrollPhysics(),
          onStepContinue: _saving ? null : _onContinue,
          onStepCancel: _step == 0 ? null : () => setState(() => _step--),
          onStepTapped: (i) => setState(() => _step = i),
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: modernButtonStyle(),
                    onPressed: details.onStepContinue,
                    child: _step == 2
                        ? (_saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('دروستکردن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
                        : const Text('دواتر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryDarkBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: primaryDarkBlue, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: details.onStepCancel,
                      child: const Text('گەڕانەوە', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          steps: [
            Step(
              title: const Text('لایەنەکان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              isActive: _step >= 0,
              state: _step > 0 ? StepState.complete : StepState.indexed,
              content: Form(
                key: _partiesKey,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      _text(_party1Name, 'لایەنی یەکەم (فرۆشیار)', icon: Icons.person_outline),
                      _text(_party1Mobile, 'ژمارەی مۆبایل (فرۆشیار)', keyboard: TextInputType.phone, icon: Icons.phone_iphone),
                      const Divider(height: 32),
                      _text(_party2Name, 'لایەنی دووەم (کڕیار)', icon: Icons.person_outline),
                      _text(_party2Mobile, 'ژمارەی مۆبایل (کڕیار)', keyboard: TextInputType.phone, icon: Icons.phone_iphone),
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('موڵک', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              isActive: _step >= 1,
              state: _step > 1 ? StepState.complete : StepState.indexed,
              content: Form(
                key: _propertyKey,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      _text(_propertyType, 'جۆری موڵک (بۆ نموونە: خانوو)', icon: Icons.home_work_outlined),
                      _text(_projectName, 'پڕۆژە / گەڕەک', icon: Icons.location_city_outlined),
                      _text(_propertyNumber, 'ژمارەی عەقار', icon: Icons.numbers),
                      _text(_area, 'ڕووبەر (م²)', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.square_foot),
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('دارایی و بەروار', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              isActive: _step >= 2,
              content: Form(
                key: _financialsKey,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _text(_totalPrice, 'نرخی فرۆشتن', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.payments_outlined),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<Currency>(
                          isExpanded: true,
                          initialValue: _currency,
                          decoration: modernInputDecoration(label: 'جۆری دراو', icon: Icons.money),
                          items: Currency.values
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.label, style: const TextStyle(fontWeight: FontWeight.bold))))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v ?? Currency.iqd),
                        ),
                      ),

                      _text(_downPayment, 'پێشەکی (عربون)', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.monetization_on_outlined),
                      _text(_paymentMethod, 'شێوازی پارەدان', icon: Icons.account_balance_wallet_outlined),
                      _text(_lateFee, 'پێدانی بڕی دواکەوتن بۆ ڕۆژێک', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.warning_amber_rounded),
                      _text(_withdrawal, 'بڕی پاشگەزبوونەوە', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.money_off_outlined),
                      _text(_lawyer, 'پارێزەر', icon: Icons.gavel_rounded),

                      _datePicker('ڕێکەوتی تەسلیم', _deliveryDate, (d) => setState(() => _deliveryDate = d)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // فەنکشن بۆ دروستکردنی بۆشاییەکان
  Widget _text(TextEditingController c, String label, {TextInputType? keyboard, IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          keyboardType: keyboard,
          decoration: modernInputDecoration(label: label, icon: icon),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
        ),
      );

  // فەنکشن بۆ هەڵبژاردنی بەروار بە دیزاینێکی مۆدێرن
  Widget _datePicker(String label, DateTime value, ValueChanged<DateTime> onPick) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: primaryDarkBlue, // ڕەنگی سەرەوەی ساڵنامەکە
                      onPrimary: Colors.white,
                      onSurface: primaryDarkBlue,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onPick(picked);
          },
          child: InputDecorator(
            decoration: modernInputDecoration(label: label, icon: Icons.calendar_today_rounded),
            child: Text(_date.format(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ),
      );
}