import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/lawyer_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../data/template_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../models/lawyer_model.dart';
import 'contract_preview_screen.dart';
import 'doc_lang_field.dart';
import 'widgets/contract_docs_field.dart';
import 'widgets/saving_dialog.dart';
import '../../theme/app_colors.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;
Color get inputFillColor => AppColors.current.inputFill;

// فەنکشن بۆ دیزاینی فۆڕمەکان
InputDecoration modernInputDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppColors.current.textMuted, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.current.textStrong, size: 22) : null,
    filled: true,
    fillColor: inputFillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.current.divider, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accentYellow, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.current.danger, width: 1),
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
  bool _savingDialogOpen = false;

  /// Language of the document produced for this contract — 'ku' or 'ar'. Only
  /// governs the PDF that opens after saving; the stored contract is language
  /// neutral, so the archive can still print either edition later.
  ///
  /// Null until the user picks one, so the default keeps tracking
  /// [defaultDocLang] — which needs the template stream, and that resolves a
  /// frame or two after this screen opens. Pinning it in initState would lock
  /// in "Kurdish" before we know whether Arabic is available.
  String? _pickedDocLang;

  String get _docLang =>
      _pickedDocLang ?? defaultDocLang(ref, isRent: false);

  /// Pops the progress dialog exactly once, so later navigation (preview, or
  /// popping this screen) doesn't tear down the wrong route.
  void _closeSavingDialog() {
    if (!_savingDialogOpen || !mounted) return;
    _savingDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

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
  final _commission = TextEditingController(text: '1'); // ڕێژەی عمولە %
  final _lawyer = TextEditingController();

  Currency _currency = Currency.iqd;
  DateTime _deliveryDate = DateTime.now();
  final _docs = ContractDocsController();

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
    _commission.text = _numText(e.commissionRate);
    _lawyer.text = e.lawyer;
    _currency = e.currency;
    _deliveryDate = e.deliveryDate;
    _docs.urls.addAll(e.attachmentUrls);
    _docs.printDocs = e.printAttachments;
  }

  /// Renders a num without a trailing ".0" so editing fields stay clean.
  static String _numText(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [
      _party1Name, _party1Mobile, _party2Name, _party2Mobile, _propertyType,
      _projectName, _propertyNumber, _area, _totalPrice, _downPayment,
      _paymentMethod, _lateFee, _withdrawal, _commission, _lawyer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;

  Future<void> _submit() async {
    if (!_financialsKey.currentState!.validate()) return;
    setState(() => _saving = true);
    // Blocking dialog for the whole save — uploads + transaction. Closed in
    // _closeSavingDialog on every exit path, success or failure.
    showSavingDialog(context, widget.existing == null
        ? 'چاوەڕێ بە، گرێبەستەکە دروست دەکرێت...'
        : 'چاوەڕێ بە، گرێبەستەکە نوێ دەکرێتەوە...');
    _savingDialogOpen = true;

    final user = ref.read(currentUserProvider);
    final existing = widget.existing;

    // Upload any newly captured document photos first, so the contract is
    // saved with its complete attachment list.
    final List<String> attachmentUrls;
    try {
      attachmentUrls = await _docs
          .uploadPending(existing?.companyId ?? user.companyId);
    } catch (e) {
      _closeSavingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('بارکردنی بەڵگەکان سەرکەوتوو نەبوو: $e'),
            backgroundColor: AppColors.current.danger));
        setState(() => _saving = false);
      }
      return;
    }

    // Commission: a percentage of the sale price taken from BOTH parties, so two
    // items (seller + buyer), each = price × rate%. Preserved on edit.
    final rate = _n(_commission);
    final perSide = _n(_totalPrice) * rate / 100;
    final items = (existing != null && existing.commissionItems.isNotEmpty)
        ? existing.commissionItems
        : [
            CommissionItem(side: 1, paid: perSide),
            CommissionItem(side: 2, paid: perSide),
          ];
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
      commissionRate: rate,
      commissionItems: items,
      lawyer: _lawyer.text.trim(),
      deliveryDate: _deliveryDate,
      notes: existing?.notes ?? '',
      agentName: existing?.agentName ?? user.displayName,
      attachmentUrls: attachmentUrls,
      printAttachments: _docs.printDocs,
    );

    try {
      final repo = ref.read(contractRepositoryProvider);
      if (existing != null) {
        await repo.updateContract(contract);
        _closeSavingDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('گرێبەستی فرۆشتن نوێکرایەوە'), backgroundColor: AppColors.current.success));
          Navigator.of(context).pop(existing.id);
        }
        return;
      }
      final id = await repo.createContract(contract);
      // Read the contract back so the preview shows the server-assigned
      // contract_number and branch rather than the placeholders sent up.
      final saved = await repo.fetchContract(id);
      _closeSavingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('گرێبەستی فرۆشتن دروستکرا ($id)'), backgroundColor: AppColors.current.success));
      // Replace the stepper with the new contract's preview, so going back
      // lands on the list instead of a filled-in form.
      if (saved != null) {
        await Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ContractPreviewScreen(
            contract: saved,
            company: ref.read(currentCompanyProvider).value,
            template: ref.read(contractTemplateProvider(saved.companyId)).value,
            initialLang: _docLang,
          ),
        ));
        return;
      }
      Navigator.of(context).pop(id);
    } catch (e) {
      _closeSavingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('سەرکەوتوو نەبوو: $e'), backgroundColor: AppColors.current.danger));
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

  /// Gold and up keep a lawyer directory; every other plan types the name in
  /// by hand. The field itself is always there — a sale contract needs a
  /// lawyer either way — only the pick-from-list shortcut is sold.
  bool get _hasLawyerDirectory =>
      ref.watch(currentPlanFeaturesProvider).lawyers;

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    // Keep the lawyer list warm so the picker is ready by step 3. Plans without
    // the directory must not run this query at all — it would only ever return
    // an empty list for them.
    if (_hasLawyerDirectory) ref.watch(lawyersStreamProvider);
    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? 'دەستکاری گرێبەستی فرۆشتن' : 'گرێبەستی فرۆشتنی نوێ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // ڕەنگی هەنگاوە چالاکەکان لە ڕووکاری ئەپەکەوە دێت — پێشتر ColorScheme.light
      // ـی زۆرەملێ بوو، کە لە دۆخی تاریکدا ساڵنامەیەکی سپی دەردەخست.
      body: Theme(
        data: Theme.of(context),
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
                        foregroundColor: AppColors.current.textStrong,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: primaryDarkBlue, width: 1.5),
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
                      // ڕێژەی عمولە (%) — هەر لایەک. لە هەردوو لا وەردەگیرێت.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: _commission,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: modernInputDecoration(label: 'ڕێژەی عمولە % (هەر لایەک)', icon: Icons.percent_rounded),
                        ),
                      ),
                      _lawyerField(),

                      _datePicker('ڕێکەوتی تەسلیم', _deliveryDate, (d) => setState(() => _deliveryDate = d)),

                      const SizedBox(height: 12),
                      ContractDocsField(controller: _docs),
                      const SizedBox(height: 12),
                      DocLangField(
                        isRent: false,
                        value: _docLang,
                        onChanged: (v) => setState(() => _pickedDocLang = v),
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

  // خانەی پارێزەر: هەمیشە بە دەستی دەنووسرێت. لە گۆڵد بەرەوسەرەوە دوگمەیەکی
  // لای کۆتایی هەیە کە لیستی پارێزەرانی کۆمپانیا دەکاتەوە بۆ هەڵبژاردن.
  Widget _lawyerField() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: _lawyer,
          decoration: modernInputDecoration(label: 'پارێزەر', icon: Icons.gavel_rounded)
              .copyWith(
            suffixIcon: _hasLawyerDirectory
                ? IconButton(
                    tooltip: 'هەڵبژاردن لە لیست',
                    icon: Icon(Icons.people_alt_outlined,
                        color: AppColors.current.textStrong),
                    onPressed: _pickLawyer,
                  )
                : null,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'پێویستە' : null,
        ),
      );

  Future<void> _pickLawyer() async {
    final lawyers = ref.read(lawyersStreamProvider).value ?? const <Lawyer>[];
    final picked = await showModalBottomSheet<Lawyer>(
      context: context,
      backgroundColor: AppColors.current.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: lawyers.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gavel_rounded, size: 48, color: AppColors.current.textMuted),
                    const SizedBox(height: 12),
                    Text('هیچ پارێزەرێک زیاد نەکراوە',
                        style: TextStyle(
                            color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('لە ڕێکخستن > پارێزەران دەیانخەیتە سەر',
                        style: TextStyle(color: AppColors.current.textMuted, fontSize: 12)),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('هەڵبژاردنی پارێزەر',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.current.textStrong)),
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
                                ? Icon(Icons.gavel_rounded,
                                    color: AppColors.current.textStrong, size: 20)
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
            );
            if (picked != null) onPick(picked);
          },
          child: InputDecorator(
            decoration: modernInputDecoration(label: label, icon: Icons.calendar_today_rounded),
            child: Text(_date.format(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.current.textBody)),
          ),
        ),
      );
}