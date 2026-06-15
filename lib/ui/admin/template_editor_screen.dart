import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/template_repository.dart';
import '../../models/company_model.dart';
import '../../models/contract_template_model.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);

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
  final _color = TextEditingController();
  final _receiptColor = TextEditingController();
  final _rent = <TextEditingController>[];
  final _sale = <TextEditingController>[];
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
  }

  void _disposeLists() {
    for (final c in _rent) {
      c.dispose();
    }
    for (final c in _sale) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _rentTitle.dispose();
    _saleTitle.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تێمپلەیت پاشەکەوتکرا'),
            backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('گەڕاندنەوە بۆ بنەڕەت',
            style: TextStyle(
                color: _primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: const Text(
            'هەموو دەستکارییەکان دەسڕێنەوە و تێمپلەیتی بنەڕەتی (default) دەگەڕێتەوە. دڵنیایت؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('گەڕایەوە بۆ بنەڕەت'),
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
              foregroundColor: _primaryDarkBlue,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primaryDarkBlue))
                  : const Icon(Icons.save_rounded),
              label: const Text('پاشەکەوتکردن',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _saving ? null : _save,
            ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryDarkBlue))
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
                border: Border.all(color: Colors.grey.shade300),
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
                activeColor: _primaryDarkBlue,
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
    if (h.length != 6 || v == null) return Colors.grey.shade300;
    return Color(0xFF000000 | v);
  }

  // --------------------------- receipt design ---------------------------
  Widget _receiptSection() => _panel('دیزاینی پسولە (وەصڵ)', [
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
                border: Border.all(color: Colors.grey.shade300),
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
                activeColor: _primaryDarkBlue,
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
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          shape: const Border(),
          leading: const Icon(Icons.help_outline, color: _primaryDarkBlue),
          title: const Text('کۆدەکانی جێگرەوە (tokens)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                  'لەناو بەندەکاندا ئەم کۆدانە بەکاربهێنە؛ خۆکارانە بە داتای گرێبەست پڕدەبنەوە.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                          border: Border.all(color: Colors.grey.shade200),
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
  Widget _clauseSection(String title, List<TextEditingController> list) {
    return _panel(title, [
      for (var i = 0; i < list.length; i++) _clauseRow(list, i),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.add, color: _primaryDarkBlue),
          label: const Text('بەندی نوێ',
              style: TextStyle(
                  color: _primaryDarkBlue, fontWeight: FontWeight.bold)),
          onPressed: () =>
              setState(() => list.add(TextEditingController())),
        ),
      ),
    ]);
  }

  Widget _clauseRow(List<TextEditingController> list, int i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: _primaryDarkBlue.withValues(alpha: 0.1),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _primaryDarkBlue)),
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
                    color: Colors.red.shade400),
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
          color: color ?? Colors.grey.shade600,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryDarkBlue)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}
