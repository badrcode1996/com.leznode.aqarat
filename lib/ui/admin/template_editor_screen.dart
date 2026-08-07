import '../../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/template_repository.dart';
import '../../models/company_model.dart';
import '../../models/contract_template_model.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _accentYellow => AppColors.current.accent;
Color get _appBg => AppColors.current.pageBg;

/// Super-admin editor for a company's contract template: clauses (rent/sale)
/// plus a few design knobs (primary color, titles, clause font size). Saving
/// writes `templates/{companyId}`; reset deletes it (back to the built-in
/// default).
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, required this.company});
  final Company company;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final _rentTitle = TextEditingController();
  final _saleTitle = TextEditingController();
  final _rentTitleAr = TextEditingController();
  final _saleTitleAr = TextEditingController();
  final _color = TextEditingController();
  final _receiptColor = TextEditingController();
  final _rent = <TextEditingController>[];
  final _sale = <TextEditingController>[];
  final _rentAr = <TextEditingController>[];
  final _saleAr = <TextEditingController>[];
  double _fontSize = 11;
  double _receiptFontSize = 10;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tpl =
        await ref.read(templateRepositoryProvider).fetch(widget.company.id);
    _apply(tpl);
    if (mounted) setState(() => _loading = false);
  }

  void _apply(ContractTemplate tpl) {
    _rentTitle.text = tpl.rentTitle;
    _saleTitle.text = tpl.saleTitle;
    _rentTitleAr.text = tpl.rentTitleAr;
    _saleTitleAr.text = tpl.saleTitleAr;
    _color.text = tpl.primaryColorHex;
    _receiptColor.text = tpl.receiptColorHex;
    _fontSize = tpl.clauseFontSize;
    _receiptFontSize = tpl.receiptFontSize;
    _disposeLists();
    _rent
      ..clear()
      ..addAll(tpl.rentClauses.map((c) => TextEditingController(text: c)));
    _sale
      ..clear()
      ..addAll(tpl.saleClauses.map((c) => TextEditingController(text: c)));
    _rentAr
      ..clear()
      ..addAll(tpl.rentClausesAr.map((c) => TextEditingController(text: c)));
    _saleAr
      ..clear()
      ..addAll(tpl.saleClausesAr.map((c) => TextEditingController(text: c)));
  }

  void _disposeLists() {
    for (final l in [_rent, _sale, _rentAr, _saleAr]) {
      for (final c in l) {
        c.dispose();
      }
    }
  }

  @override
  void dispose() {
    _rentTitle.dispose();
    _saleTitle.dispose();
    _rentTitleAr.dispose();
    _saleTitleAr.dispose();
    _color.dispose();
    _receiptColor.dispose();
    _disposeLists();
    super.dispose();
  }

  ContractTemplate _collect() {
    List<String> clean(List<TextEditingController> l) => l
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final hex = _color.text.trim().replaceAll('#', '');
    final rHex = _receiptColor.text.trim().replaceAll('#', '');
    return ContractTemplate(
      rentClauses: clean(_rent),
      saleClauses: clean(_sale),
      rentTitle: _rentTitle.text.trim(),
      saleTitle: _saleTitle.text.trim(),
      primaryColorHex: hex.length == 6 ? hex : '0F2C59',
      clauseFontSize: _fontSize,
      receiptColorHex: rHex.length == 6 ? rHex : '1E4D8B',
      receiptFontSize: _receiptFontSize,
      rentClausesAr: clean(_rentAr),
      saleClausesAr: clean(_saleAr),
      rentTitleAr: _rentTitleAr.text.trim(),
      saleTitleAr: _saleTitleAr.text.trim(),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(templateRepositoryProvider)
          .save(widget.company.id, _collect());
      ref.invalidate(contractTemplateProvider(widget.company.id));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('تێمپلەیت پاشەکەوتکرا'),
            backgroundColor: AppColors.current.success));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('هەڵە: $e'), backgroundColor: AppColors.current.danger));
      }
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('گەڕاندنەوە بۆ بنەڕەت',
            style: TextStyle(
                color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: const Text(
            'هەموو دەستکارییەکان دەسڕێنەوە و تێمپلەیتی بنەڕەتی (default) دەگەڕێتەوە. دڵنیایت؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('نەخێر', style: TextStyle(color: AppColors.current.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.current.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('گەڕاندنەوە'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(templateRepositoryProvider).resetToDefault(widget.company.id);
    ref.invalidate(contractTemplateProvider(widget.company.id));
    setState(() => _apply(ContractTemplate.defaults()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('گەڕایەوە بۆ بنەڕەت'),
          backgroundColor: _primaryDarkBlue));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text('تێمپلەیت — ${widget.company.displayName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_loading)
            IconButton(
              tooltip: 'گەڕاندنەوە بۆ بنەڕەت',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _reset,
            ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _accentYellow,
              foregroundColor: AppColors.current.textStrong,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.current.textStrong))
                  : const Icon(Icons.save_rounded),
              label: const Text('پاشەکەوتکردن',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _saving ? null : _save,
            ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.current.textStrong))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                _designSection(),
                const SizedBox(height: 16),
                _receiptSection(),
                const SizedBox(height: 16),
                _tokenLegend(),
                const SizedBox(height: 16),
                _clauseSection('بەندەکانی گرێبەستی کرێ', _rent),
                const SizedBox(height: 16),
                _clauseSection('بەندەکانی گرێبەستی فرۆشتن', _sale),
                const SizedBox(height: 24),
                _arabicNotice(),
                const SizedBox(height: 16),
                _arabicTitles(),
                const SizedBox(height: 16),
                _clauseSection('بەندەکانی گرێبەستی کرێ — عەرەبی', _rentAr,
                    arabic: true),
                const SizedBox(height: 16),
                _clauseSection('بەندەکانی گرێبەستی فرۆشتن — عەرەبی', _saleAr,
                    arabic: true),
              ],
            ),
    );
  }

  // --------------------------- design ---------------------------
  Widget _designSection() => _panel('دیزاین', [
        TextField(
          controller: _rentTitle,
          decoration: const InputDecoration(labelText: 'ناونیشانی گرێبەستی کرێ'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _saleTitle,
          decoration:
              const InputDecoration(labelText: 'ناونیشانی گرێبەستی فرۆشتن'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _color,
                decoration: const InputDecoration(
                    labelText: 'ڕەنگی سەرەکی (RRGGBB)',
                    prefixText: '#',
                    hintText: '0F2C59'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _swatchColor(_color.text),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.current.divider),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('قەبارەی فۆنتی بەندەکان:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Expanded(
              child: Slider(
                value: _fontSize,
                min: 8,
                max: 16,
                divisions: 16,
                label: _fontSize.toStringAsFixed(1),
                activeColor: AppColors.current.textStrong,
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ),
            Text(_fontSize.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ]);

  Color _swatchColor(String hex) {
    final h = hex.trim().replaceAll('#', '');
    final v = int.tryParse(h, radix: 16);
    if (h.length != 6 || v == null) return AppColors.current.divider;
    return Color(0xFF000000 | v);
  }

  // --------------------------- receipt design ---------------------------
  Widget _receiptSection() => _panel('دیزاینی پسولە', [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _receiptColor,
                decoration: const InputDecoration(
                    labelText: 'ڕەنگی پسولە (RRGGBB)',
                    prefixText: '#',
                    hintText: '1E4D8B'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _swatchColor(_receiptColor.text),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.current.divider),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('قەبارەی فۆنتی خانەکان:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Expanded(
              child: Slider(
                value: _receiptFontSize,
                min: 8,
                max: 14,
                divisions: 12,
                label: _receiptFontSize.toStringAsFixed(1),
                activeColor: AppColors.current.textStrong,
                onChanged: (v) => setState(() => _receiptFontSize = v),
              ),
            ),
            Text(_receiptFontSize.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ]);

  // --------------------------- token legend ---------------------------
  Widget _tokenLegend() => Container(
        decoration: BoxDecoration(
            color: AppColors.current.card, borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          shape: const Border(),
          leading: Icon(Icons.help_outline, color: AppColors.current.textStrong),
          title: const Text('کۆدەکانی جێگرەوە (tokens)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                  'لەناو بەندەکاندا ئەم کۆدانە بەکاربهێنە؛ خۆکارانە بە داتای گرێبەست پڕدەبنەوە.',
                  style: TextStyle(fontSize: 12, color: AppColors.current.textMuted)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ContractTemplate.tokenHelp.entries
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _appBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.current.divider),
                        ),
                        child: Text('${e.key} = ${e.value}',
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
        ),
      );

  // --------------------------- clauses ---------------------------
  Widget _clauseSection(String title, List<TextEditingController> list,
      {bool arabic = false}) {
    return _panel(title, [
      if (arabic && list.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'هێشتا هیچ بەندێکی عەرەبی نەنووسراوە — گرێبەستی عەرەبی بۆ ئەم کۆمپانیایە بەردەست نابێت.',
            style: TextStyle(fontSize: 12, color: AppColors.current.textMuted),
          ),
        ),
      for (var i = 0; i < list.length; i++) _clauseRow(list, i),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: Icon(Icons.add, color: AppColors.current.textStrong),
          label: Text('بەندی نوێ',
              style: TextStyle(
                  color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
          onPressed: () =>
              setState(() => list.add(TextEditingController())),
        ),
      ),
    ]);
  }

  /// Arabic clauses are legal text with no safe default, so the editor says so
  /// rather than shipping a machine translation the company would never read.
  Widget _arabicNotice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _accentYellow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentYellow.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('گرێبەستی عەرەبی',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.current.textStrong)),
            const SizedBox(height: 6),
            const Text(
              'ئەم بەندانە بە عەرەبی بنووسە تاوەکو کۆمپانیاکە بتوانێت گرێبەستەکە بە عەرەبی چاپ بکات. '
              'هەمان تۆکنەکانی سەرەوە ({party1}، {total_price}، …) لێرەش کار دەکەن. '
              'هیچ وەرگێڕانێکی خۆکار نییە — دەقێکی یاسایییە و دەبێت پارێزەر پێداچوونەوەی بۆ بکات.',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
          ],
        ),
      );

  Widget _arabicTitles() => _panel('ناونیشانەکانی عەرەبی', [
        TextField(
          controller: _rentTitleAr,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
              labelText: 'ناونیشانی گرێبەستی کرێ (عەرەبی)',
              hintText: 'عقد إيجار'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _saleTitleAr,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
              labelText: 'ناونیشانی گرێبەستی فرۆشتن (عەرەبی)',
              hintText: 'عقد بيع وشراء'),
        ),
      ]);

  Widget _clauseRow(List<TextEditingController> list, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: _primaryDarkBlue.withValues(alpha: 0.1),
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.current.textStrong)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: list[i],
                maxLines: null,
                minLines: 1,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _appBg,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Column(
              children: [
                _iconBtn(Icons.arrow_upward, i == 0 ? null : () => _move(list, i, -1)),
                _iconBtn(Icons.arrow_downward,
                    i == list.length - 1 ? null : () => _move(list, i, 1)),
                _iconBtn(Icons.delete_outline, () => _remove(list, i),
                    color: AppColors.current.danger),
              ],
            ),
          ],
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {Color? color}) =>
      SizedBox(
        width: 32,
        height: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: color ?? AppColors.current.textMuted,
          icon: Icon(icon),
          onPressed: onTap,
        ),
      );

  void _move(List<TextEditingController> list, int i, int delta) {
    setState(() {
      final c = list.removeAt(i);
      list.insert(i + delta, c);
    });
  }

  void _remove(List<TextEditingController> list, int i) {
    setState(() {
      list.removeAt(i).dispose();
    });
  }

  // --------------------------- shared panel ---------------------------
  Widget _panel(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.current.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.current.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.current.textStrong)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}
