import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';

/// 3-step Stepper for creating a RENT contract.
///
/// Step 1: Parties · Step 2: Property · Step 3: Financials/Dates
/// The 12-month installment schedule is generated automatically from the
/// chosen start date (no per-month columns).
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

  final _clientName = TextEditingController();
  final _clientMobile = TextEditingController();
  final _propertyTitle = TextEditingController();
  final _monthlyAmount = TextEditingController();

  DateTime _startDate = DateTime.now();
  static final _date = DateFormat('yyyy/MM/dd');

  @override
  void dispose() {
    for (final c in [
      _clientName,
      _clientMobile,
      _propertyTitle,
      _monthlyAmount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_financialsKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider);
    final contract = RentContract(
      id: '',
      companyId: user.companyId,
      agentId: user.agentId,
      clientName: _clientName.text.trim(),
      clientMobile: _clientMobile.text.trim(),
      propertyTitle: _propertyTitle.text.trim(),
      createdAt: DateTime.now(),
      monthlyAmount: num.tryParse(_monthlyAmount.text.trim()) ?? 0,
      installments: RentContract.buildSchedule(_startDate), // 12 months
    );

    try {
      final id =
          await ref.read(contractRepositoryProvider).createContract(contract);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('گرێبەستی کرێ دروستکرا ($id)')));
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
                  TextFormField(
                    controller: _clientName,
                    decoration:
                        const InputDecoration(labelText: 'ناوی کرێچی'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _clientMobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'مۆبایل'),
                    validator: _required,
                  ),
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
              child: TextFormField(
                controller: _propertyTitle,
                decoration:
                    const InputDecoration(labelText: 'ناونیشانی موڵک'),
                validator: _required,
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
                  TextFormField(
                    controller: _monthlyAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'کرێی مانگانە'),
                    validator: (v) {
                      final n = num.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'بڕێکی دروست بنووسە';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Text(
                              'دەستپێکی قیستەکان: ${_date.format(_startDate)}')),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('بەروار'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '١٢ قیست بەشێوەی خۆکار دروست دەکرێن.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'پێویستە' : null;
}
