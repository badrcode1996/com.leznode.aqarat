import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/lawyer_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../models/lawyer_model.dart';

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

/// 3-step Stepper for creating a SALE contract (فرۆشتن/کڕین) — or editing one
/// when [existing] is supplied (admin only).
class CreateSaleContractStepper extends ConsumerStatefulWidget {
  const CreateSaleContractStepper({super.key, this.existing});

  /// When non-null the stepper edits this contract instead of creating one.
  final SaleContract? existing;

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

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _party1Name.text = e.party1Name;
    _party1Mobile.text = e.party1Mobile;
    _party2Name.text = e.party2Name;
    _party2Mobile.text = e.party2Mobile;
    _propertyType.text = e.propertyType;
    _projectName.text = e.projectName;
    _propertyNumber.text = e.propertyNumber;
    _area.text = _numText(e.area);
    _totalPrice.text = _numText(e.totalPrice);
    _downPayment.text = _numText(e.downPayment);
    _paymentMethod.text = e.paymentMethod;
    _lateFee.text = _numText(e.lateFeePerDay);
    _withdrawal.text = _numText(e.withdrawalAmount);
    _lawyer.text = e.lawyer;
    _currency = e.currency;
    _deliveryDate = e.deliveryDate;
  }

  /// Renders a num without a trailing ".0" so editing fields stay clean.
  static String _numText(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

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
    final existing = widget.existing;
    final contract = SaleContract(
      id: existing?.id ?? '',
      companyId: existing?.companyId ?? user.companyId,
      agentId: existing?.agentId ?? user.agentId,
      createdAt: existing?.createdAt ?? DateTime.now(),
      contractNumber: existing?.contractNumber ?? 0,
      branch: existing?.branch ?? '',
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
      agentName: existing?.agentName ?? user.displayName,
    );

    try {
      final repo = ref.read(contractRepositoryProvider);
      if (existing != null) {
        await repo.updateContract(contract);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('گرێبەستی فرۆشتن نوێکرایەوە'), backgroundColor: Colors.green));
          Navigator.of(context).pop(existing.id);
        }
        return;
      }
      final id = await repo.createContract(contract);
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
    // Keep the lawyer list warm so the picker is ready by step 3.
    ref.watch(lawyersStreamProvider);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? 'دەستکاری گرێبەستی فرۆشتن' : 'گرێبەستی فرۆشتنی نوێ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        : Text(_isEdit ? 'پاشەکەوتکردن' : 'دروستکردن', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
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
                      _lawyerField(),

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

  // خانەی پارێزەر: دەتوانرێت ناوێک لە لیستی کۆمپانیا هەڵبژێردرێت یان بە دەستی
  // بنووسرێت. دوگمەی لای کۆتایی لیستی پارێزەران دەکاتەوە.
  Widget _lawyerField() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: _lawyer,
          decoration: modernInputDecoration(label: 'پارێزەر', icon: Icons.gavel_rounded)
              .copyWith(
            suffixIcon: IconButton(
              tooltip: 'هەڵبژاردن لە لیست',
              icon: const Icon(Icons.people_alt_outlined, color: primaryDarkBlue),
              onPressed: _pickLawyer,
            ),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
        ),
      );

  Future<void> _pickLawyer() async {
    final lawyers = ref.read(lawyersStreamProvider).value ?? const <Lawyer>[];
    final picked = await showModalBottomSheet<Lawyer>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: lawyers.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gavel_rounded, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('هیچ پارێزەرێک زیاد نەکراوە',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('لە ڕێکخستن > پارێزەران دەیانخەیتە سەر',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('هەڵبژاردنی پارێزەر',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryDarkBlue)),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: lawyers.length,
                      itemBuilder: (_, i) {
                        final l = lawyers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                primaryDarkBlue.withValues(alpha: 0.1),
                            backgroundImage: l.photoUrl.isNotEmpty
                                ? NetworkImage(l.photoUrl)
                                : null,
                            child: l.photoUrl.isEmpty
                                ? const Icon(Icons.gavel_rounded,
                                    color: primaryDarkBlue, size: 20)
                                : null,
                          ),
                          title: Text(l.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: l.phone.isEmpty ? null : Text(l.phone),
                          onTap: () => Navigator.pop(context, l),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
    if (picked != null) _lawyer.text = picked.name;
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