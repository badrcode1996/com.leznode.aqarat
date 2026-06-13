import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';

/// 3-step Stepper for creating a SALE contract.
///
/// Step 1: Parties        (client name + mobile)
/// Step 2: Property        (title / description)
/// Step 3: Financials      (price → auto 1% commission, editable)
class CreateSaleContractStepper extends ConsumerStatefulWidget {
  const CreateSaleContractStepper({super.key});

  @override
  ConsumerState<CreateSaleContractStepper> createState() =>
      _CreateSaleContractStepperState();
}

class _CreateSaleContractStepperState
    extends ConsumerState<CreateSaleContractStepper> {
  int _currentStep = 0;
  bool _saving = false;

  // One form key per step so we validate only the active step.
  final _partiesKey = GlobalKey<FormState>();
  final _propertyKey = GlobalKey<FormState>();
  final _financialsKey = GlobalKey<FormState>();

  // Step 1
  final _clientName = TextEditingController();
  final _clientMobile = TextEditingController();
  // Step 2
  final _propertyTitle = TextEditingController();
  // Step 3
  final _totalPrice = TextEditingController();
  final _downPayment = TextEditingController();
  final _commissionSeller = TextEditingController();
  final _commissionBuyer = TextEditingController();

  /// True once the user manually edits the seller commission — after that we
  /// stop overwriting their value when the price changes.
  bool _sellerCommissionTouched = false;

  Currency _currency = Currency.iqd;
  DateTime? _remainingDueDate;

  @override
  void initState() {
    super.initState();
    // Recompute the suggested commission as the price is typed.
    _totalPrice.addListener(_recalcCommission);
  }

  @override
  void dispose() {
    for (final c in [
      _clientName,
      _clientMobile,
      _propertyTitle,
      _totalPrice,
      _downPayment,
      _commissionSeller,
      _commissionBuyer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num get _price => num.tryParse(_totalPrice.text.trim()) ?? 0;
  num get _down => num.tryParse(_downPayment.text.trim()) ?? 0;
  num get _remaining => (_price - _down).clamp(0, double.infinity);

  /// Auto-fills seller commission at the 1% default — but only while the user
  /// hasn't overridden it. Buyer commission is left fully manual.
  void _recalcCommission() {
    if (_sellerCommissionTouched) {
      setState(() {}); // refresh the read-only "remaining" line.
      return;
    }
    final suggested = _price * SaleContract.defaultCommissionRate;
    _commissionSeller.text =
        suggested == 0 ? '' : suggested.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_financialsKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider);
    final contract = SaleContract(
      id: '', // assigned by Firestore
      companyId: user.companyId,
      agentId: user.agentId,
      clientName: _clientName.text.trim(),
      clientMobile: _clientMobile.text.trim(),
      propertyTitle: _propertyTitle.text.trim(),
      createdAt: DateTime.now(),
      currency: _currency,
      totalPrice: _price,
      downPayment: _down,
      remainingAmount: _remaining,
      remainingDueDate: _remainingDueDate,
      commissionSeller: num.tryParse(_commissionSeller.text.trim()) ?? 0,
      commissionBuyer: num.tryParse(_commissionBuyer.text.trim()) ?? 0,
    );

    try {
      final id =
          await ref.read(contractRepositoryProvider).createContract(contract);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale contract created ($id)')),
        );
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onStepContinue() {
    final keys = [_partiesKey, _propertyKey, _financialsKey];
    if (!keys[_currentStep].currentState!.validate()) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale Contract')),
      body: Stepper(
        currentStep: _currentStep,
        type: StepperType.vertical,
        onStepContinue: _saving ? null : _onStepContinue,
        onStepCancel: _currentStep == 0
            ? null
            : () => setState(() => _currentStep--),
        onStepTapped: (i) => setState(() => _currentStep = i),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                onPressed: details.onStepContinue,
                child: Text(_currentStep == 2
                    ? (_saving ? 'Saving…' : 'Create Contract')
                    : 'Next'),
              ),
              const SizedBox(width: 8),
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
        steps: [
          _partiesStep(),
          _propertyStep(),
          _financialsStep(),
        ],
      ),
    );
  }

  // --------------------------- Step 1: Parties ---------------------------
  Step _partiesStep() => Step(
        title: const Text('Parties'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _partiesKey,
          child: Column(
            children: [
              TextFormField(
                controller: _clientName,
                decoration: const InputDecoration(labelText: 'Client name'),
                validator: _required,
              ),
              TextFormField(
                controller: _clientMobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Client mobile'),
                validator: _required,
              ),
            ],
          ),
        ),
      );

  // --------------------------- Step 2: Property ---------------------------
  Step _propertyStep() => Step(
        title: const Text('Property details'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _propertyKey,
          child: TextFormField(
            controller: _propertyTitle,
            decoration: const InputDecoration(
              labelText: 'Property title / description',
            ),
            validator: _required,
          ),
        ),
      );

  // ------------------------- Step 3: Financials -------------------------
  Step _financialsStep() => Step(
        title: const Text('Financials & Dates'),
        isActive: _currentStep >= 2,
        content: Form(
          key: _financialsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _totalPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total price',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _positiveNumber,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Currency>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'دراو (دینار/دۆلار)',
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                items: Currency.values
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _currency = v ?? Currency.iqd),
              ),
              TextFormField(
                controller: _downPayment,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Down payment'),
                onChanged: (_) => setState(() {}),
                validator: _positiveNumber,
              ),
              const SizedBox(height: 8),
              // Read-only computed remaining amount.
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Remaining amount (auto)',
                  border: OutlineInputBorder(),
                ),
                child: Text(_remaining.toStringAsFixed(2)),
              ),
              const SizedBox(height: 12),

              // ---- Auto-calculated, but EDITABLE seller commission (1%) ----
              TextFormField(
                controller: _commissionSeller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Seller commission',
                  helperText: _sellerCommissionTouched
                      ? 'Manual override'
                      : 'Auto: 1% of total price — tap to edit',
                  suffixIcon: _sellerCommissionTouched
                      ? IconButton(
                          tooltip: 'Reset to 1%',
                          icon: const Icon(Icons.restart_alt),
                          onPressed: () {
                            _sellerCommissionTouched = false;
                            _recalcCommission();
                          },
                        )
                      : null,
                ),
                // First manual edit "locks" the auto-fill so we stop overwriting.
                onChanged: (_) {
                  if (!_sellerCommissionTouched) {
                    setState(() => _sellerCommissionTouched = true);
                  }
                },
                validator: _positiveNumber,
              ),

              TextFormField(
                controller: _commissionBuyer,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Buyer commission',
                ),
                validator: _positiveNumber,
              ),
              const SizedBox(height: 12),

              // Remaining due date picker.
              Row(
                children: [
                  Expanded(
                    child: Text(_remainingDueDate == null
                        ? 'No remaining due date set'
                        : 'Due: ${_remainingDueDate!.toString().split(' ').first}'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Pick date'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now,
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked != null) {
                        setState(() => _remainingDueDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  // ------------------------------ validators ------------------------------
  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _positiveNumber(String? v) {
    final n = num.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }
}
