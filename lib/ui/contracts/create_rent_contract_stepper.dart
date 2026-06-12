import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';

/// 3-step Stepper for creating a RENT contract — mirrors the paper form.
/// Step 1: Parties · Step 2: Property · Step 3: Financials/Dates
class CreateRentContractStepper extends ConsumerStatefulWidget {
  const CreateRentContractStepper({super.key});

  @override
  ConsumerState<CreateRentContractStepper> createState() =>
      _CreateRentContractStepperState();
}

class _CreateRentContractStepperState
    extends ConsumerState<CreateRentContractStepper> {
  int _step = 0;
  bool _saving = false;

  final _partiesKey = GlobalKey<FormState>();
  final _propertyKey = GlobalKey<FormState>();
  final _financialsKey = GlobalKey<FormState>();

  // Step 1 — parties
  final _party1Name = TextEditingController();
  final _party1Mobile = TextEditingController();
  final _party2Name = TextEditingController();
  final _party2Mobile = TextEditingController();
  // Step 2 — property
  final _propertyType = TextEditingController();
  final _projectName = TextEditingController();
  final _propertyNumber = TextEditingController();
  final _area = TextEditingController();
  // Step 3 — financials / dates
  final _voucherNumber = TextEditingController();
  final _rentAmount = TextEditingController();
  final _rentalPeriod = TextEditingController();
  final _downPayment = TextEditingController();
  final _downPaymentMonths = TextEditingController();
  final _paymentFrequency = TextEditingController(text: '1');
  final _guarantee = TextEditingController();
  final _gracePeriod = TextEditingController();
  final _rentalPurpose = TextEditingController();
  final _lateFee = TextEditingController();

  Currency _currency = Currency.iqd;
  DateTime _startDate = DateTime.now();
  DateTime _handoverDate = DateTime.now().add(const Duration(days: 365));

  static final _date = DateFormat('yyyy/MM/dd');

  @override
  void dispose() {
    for (final c in [
      _party1Name,
      _party1Mobile,
      _party2Name,
      _party2Mobile,
      _propertyType,
      _projectName,
      _propertyNumber,
      _area,
      _voucherNumber,
      _rentAmount,
      _rentalPeriod,
      _downPayment,
      _downPaymentMonths,
      _paymentFrequency,
      _guarantee,
      _gracePeriod,
      _rentalPurpose,
      _lateFee,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;
  int _i(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (!_financialsKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider);
    final freq = _i(_paymentFrequency) < 1 ? 1 : _i(_paymentFrequency);
    final contract = RentContract(
      id: '',
      companyId: user.companyId,
      agentId: user.agentId,
      createdAt: DateTime.now(),
      voucherNumber: _voucherNumber.text.trim(),
      party1Name: _party1Name.text.trim(),
      party1Mobile: _party1Mobile.text.trim(),
      party2Name: _party2Name.text.trim(),
      party2Mobile: _party2Mobile.text.trim(),
      propertyType: _propertyType.text.trim(),
      projectName: _projectName.text.trim(),
      propertyNumber: _propertyNumber.text.trim(),
      area: _n(_area),
      rentAmount: _n(_rentAmount),
      currency: _currency,
      rentalPeriod: _rentalPeriod.text.trim(),
      downPayment: _n(_downPayment),
      downPaymentMonths: _i(_downPaymentMonths),
      startDate: _startDate,
      handoverDate: _handoverDate,
      paymentFrequencyMonths: freq,
      guaranteeAmount: _n(_guarantee),
      gracePeriod: _gracePeriod.text.trim(),
      rentalPurpose: _rentalPurpose.text.trim(),
      lateFeePerDay: _n(_lateFee),
      installments: RentContract.buildSchedule(_startDate, everyMonths: freq),
    );

    try {
      final id =
          await ref.read(contractRepositoryProvider).createContract(contract);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('گرێبەستی کرێ دروستکرا ($id)')));
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('سەرکەوتوو نەبوو: $e')));
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
      appBar: AppBar(title: const Text('گرێبەستی کرێی نوێ')),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _saving ? null : _onContinue,
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        onStepTapped: (i) => setState(() => _step = i),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                onPressed: details.onStepContinue,
                child: Text(_step == 2
                    ? (_saving ? 'پاشەکەوتکردن…' : 'دروستکردن')
                    : 'دواتر'),
              ),
              const SizedBox(width: 8),
              if (_step > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('گەڕانەوە'),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('لایەنەکان'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _partiesKey,
              child: Column(
                children: [
                  _text(_party1Name, 'لایەنی یەکەم'),
                  _text(_party1Mobile, 'ژمارەی مۆبایل',
                      keyboard: TextInputType.phone),
                  _text(_party2Name, 'لایەنی دووەم'),
                  _text(_party2Mobile, 'ژمارەی مۆبایل',
                      keyboard: TextInputType.phone),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('موڵک'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _propertyKey,
              child: Column(
                children: [
                  _text(_propertyType, 'جۆری موڵک'),
                  _text(_projectName, 'پڕۆژە/گەرەک'),
                  _text(_propertyNumber, 'ژمارەی عەقار'),
                  _text(_area, 'ڕووبەر (م²)',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('دارایی و بەروار'),
            isActive: _step >= 2,
            content: Form(
              key: _financialsKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _text(_voucherNumber, 'ژمارەی پسووله'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _text(_rentAmount, 'بری کرێ',
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DropdownButtonFormField<Currency>(
                            initialValue: _currency,
                            decoration:
                                const InputDecoration(labelText: 'دراو'),
                            items: Currency.values
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c.label)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _currency = v ?? Currency.iqd),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _text(_rentalPeriod, 'ماوەی بەکریگرتن'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _text(_downPayment, 'بری پێشەکی',
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _text(_downPaymentMonths, 'بۆ چەند مانگ',
                            keyboard: TextInputType.number),
                      ),
                    ],
                  ),
                  _datePicker('بەرواری بەکریگرتن', _startDate,
                      (d) => setState(() => _startDate = d)),
                  _datePicker('بەرواری ڕادەستکردن', _handoverDate,
                      (d) => setState(() => _handoverDate = d)),
                  _text(_paymentFrequency, 'کرێدان چەند مانگ جارێک',
                      keyboard: TextInputType.number),
                  _text(_guarantee, 'بری دڵنیایی',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                  _text(_gracePeriod, 'ماوەی ڕێپێدان'),
                  _text(_rentalPurpose, 'هۆکاری بەکری گرتن'),
                  _text(_lateFee, 'بری دواکەوتن بۆ ڕۆژ',
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('١٢ قیست بەشێوەی خۆکار دروست دەکرێن.',
                        style:
                            TextStyle(color: Colors.black54, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(TextEditingController c, String label,
          {TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
        ),
      );

  Widget _datePicker(String label, DateTime value, ValueChanged<DateTime> onPick) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text('$label: ${_date.format(value)}')),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('بەروار'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) onPick(picked);
              },
            ),
          ],
        ),
      );
}
