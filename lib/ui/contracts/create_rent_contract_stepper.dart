import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../widgets/house_image_picker.dart';

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

/// 3-step Stepper for creating a RENT contract — or editing one when
/// [existing] is supplied (admin only).
class CreateRentContractStepper extends ConsumerStatefulWidget {
  const CreateRentContractStepper({super.key, this.existing});

  /// When non-null the stepper edits this contract instead of creating one.
  final RentContract? existing;

  @override
  ConsumerState<CreateRentContractStepper> createState() =>
      _CreateRentContractStepperState();
}

class _CreateRentContractStepperState extends ConsumerState<CreateRentContractStepper> {
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
  String _notes = '';
  DateTime _startDate = DateTime.now();
  DateTime _handoverDate = DateTime.now().add(const Duration(days: 365));

  Uint8List? _imageBytes;
  String _imageContentType = 'image/jpeg';

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
    _rentAmount.text = _numText(e.rentAmount);
    _rentalPeriod.text = e.rentalPeriodMonths.toString();
    _downPayment.text = _numText(e.downPayment);
    _downPaymentMonths.text = e.downPaymentMonths.toString();
    _paymentFrequency.text = e.paymentFrequencyMonths.toString();
    _guarantee.text = _numText(e.guaranteeAmount);
    _gracePeriod.text = e.gracePeriod;
    _rentalPurpose.text = e.rentalPurpose;
    _lateFee.text = _numText(e.lateFeePerDay);
    _currency = e.currency;
    _notes = e.notes;
    _startDate = e.startDate;
    _handoverDate = e.handoverDate;
  }

  /// Renders a num without a trailing ".0" so editing fields stay clean.
  static String _numText(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [
      _party1Name, _party1Mobile, _party2Name, _party2Mobile, _propertyType,
      _projectName, _propertyNumber, _area, _rentAmount, _rentalPeriod,
      _downPayment, _downPaymentMonths, _paymentFrequency, _guarantee,
      _gracePeriod, _rentalPurpose, _lateFee,
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
    final existing = widget.existing;
    final freq = _i(_paymentFrequency) < 1 ? 1 : _i(_paymentFrequency);
    final prepaid = _i(_downPaymentMonths).clamp(0, 12);

    // Rebuild the schedule from the (possibly edited) dates/frequency, then
    // carry over any payment statuses the admin had already recorded so an
    // edit never wipes out collected-rent tracking.
    final schedule =
        RentContract.buildSchedule(_startDate, everyMonths: freq, prepaidMonths: prepaid);
    final installments = existing == null
        ? schedule
        : schedule.map((inst) {
            for (final old in existing.installments) {
              if (old.monthNumber == inst.monthNumber) {
                return inst.copyWith(status: old.status);
              }
            }
            return inst;
          }).toList();

    final contract = RentContract(
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
      rentAmount: _n(_rentAmount),
      currency: _currency,
      rentalPeriodMonths: _i(_rentalPeriod),
      downPayment: _n(_downPayment),
      downPaymentMonths: prepaid,
      startDate: _startDate,
      handoverDate: _handoverDate,
      paymentFrequencyMonths: freq,
      guaranteeAmount: _n(_guarantee),
      gracePeriod: _gracePeriod.text.trim(),
      rentalPurpose: _rentalPurpose.text.trim(),
      lateFeePerDay: _n(_lateFee),
      installments: installments,
      notes: _notes.trim(),
      agentName: existing?.agentName ?? user.displayName,
      imageUrl: existing?.imageUrl ?? '',
    );

    try {
      final repo = ref.read(contractRepositoryProvider);
      if (existing != null) {
        await repo.updateContract(
          contract,
          imageBytes: _imageBytes,
          imageContentType: _imageContentType,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('گرێبەستی کرێ نوێکرایەوە'), backgroundColor: Colors.green));
          Navigator.of(context).pop(existing.id);
        }
        return;
      }
      final id = await repo.createContract(
        contract,
        imageBytes: _imageBytes,
        imageContentType: _imageContentType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('گرێبەستی کرێ دروستکرا ($id)'), backgroundColor: Colors.green));
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

  Future<void> _editNotes() async {
    final controller = TextEditingController(text: _notes);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تێبینی', style: TextStyle(color: primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 5,
          maxLength: 500,
          decoration: modernInputDecoration(label: 'تا ٥ لاین تێبینی بنووسە...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryDarkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('پاشەکەوت', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _notes = result);
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
        title: Text(_isEdit ? 'دەستکاری گرێبەستی کرێ' : 'گرێبەستی کرێی نوێ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                      _text(_party1Name, 'لایەنی یەکەم', icon: Icons.person_outline),
                      _text(_party1Mobile, 'ژمارەی مۆبایل (لایەنی یەکەم)', keyboard: TextInputType.phone, icon: Icons.phone_iphone),
                      const Divider(height: 32),
                      _text(_party2Name, 'لایەنی دووەم', icon: Icons.person_outline),
                      _text(_party2Mobile, 'ژمارەی مۆبایل (لایەنی دووەم)', keyboard: TextInputType.phone, icon: Icons.phone_iphone),
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
                      // وێنەی خانوو (ئارەزوومەندانە) — کامێرا یان گەلەری
                      HouseImagePicker(
                        initialImageUrl: widget.existing?.imageUrl ?? '',
                        onChanged: (bytes, contentType) {
                          _imageBytes = bytes;
                          _imageContentType = contentType;
                        },
                      ),
                      const SizedBox(height: 20),
                      _text(_propertyType, 'جۆری موڵک (بۆ نموونە: خانوو)', icon: Icons.home_work_outlined),
                      _text(_projectName, 'پڕۆژە / گەرەک', icon: Icons.location_city_outlined),
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
                      _text(_rentAmount, 'بڕی کرێ', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.payments_outlined),

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

                      _text(_rentalPeriod, 'ماوەی بەکرێگرتن (بە مانگ)', keyboard: TextInputType.number, icon: Icons.calendar_month_outlined),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _text(_downPayment, 'بڕی پێشەکی', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.monetization_on_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _text(_downPaymentMonths, 'بۆ چەند مانگ', keyboard: TextInputType.number),
                          ),
                        ],
                      ),

                      _datePicker('بەرواری بەکرێگرتن', _startDate, (d) => setState(() => _startDate = d)),
                      _datePicker('بەرواری ڕادەستکردن', _handoverDate, (d) => setState(() => _handoverDate = d)),

                      _text(_paymentFrequency, 'کرێدان چەند مانگ جارێکە؟', keyboard: TextInputType.number, icon: Icons.update),
                      _text(_guarantee, 'بڕی دڵنیایی (الضمان)', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.security),
                      _text(_gracePeriod, 'ماوەی ڕێپێدان (السماح)', icon: Icons.timer_outlined),
                      _text(_rentalPurpose, 'هۆکاری بەکرێگرتن', icon: Icons.info_outline),
                      _text(_lateFee, 'بڕی غەرامەی دواکەوتن بە ڕۆژ', keyboard: const TextInputType.numberWithOptions(decimal: true), icon: Icons.warning_amber_rounded),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.note_alt_outlined, color: primaryDarkBlue),
                                const SizedBox(width: 8),
                                Text('تێبینییەکان', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                                const Spacer(),
                                TextButton(
                                  onPressed: _editNotes,
                                  style: TextButton.styleFrom(foregroundColor: primaryDarkBlue),
                                  child: Text(_notes.isEmpty ? 'زیادکردن' : 'دەستکاری'),
                                ),
                              ],
                            ),
                            if (_notes.isNotEmpty) ...[
                              const Divider(),
                              Text(_notes, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ]
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            Icon(Icons.info, size: 16, color: accentYellow),
                            SizedBox(width: 8),
                            Text('١٢ قیست بە شێوەی خۆکار دروست دەکرێن.', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
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