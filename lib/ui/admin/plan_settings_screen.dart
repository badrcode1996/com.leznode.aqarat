import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/plan_config_repository.dart';
import '../../models/plan_config_model.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);

/// Super-Admin editor for the Bronze/Silver/Gold feature matrix + limits. Saves
/// to `config/plans`; the app reads it live to gate features.
class PlanSettingsScreen extends ConsumerStatefulWidget {
  const PlanSettingsScreen({super.key});

  @override
  ConsumerState<PlanSettingsScreen> createState() => _PlanSettingsScreenState();
}

class _PlanSettingsScreenState extends ConsumerState<PlanSettingsScreen> {
  PlanFeatures _bronze = PlanConfig.defaults.bronze;
  PlanFeatures _silver = PlanConfig.defaults.silver;
  PlanFeatures _gold = PlanConfig.defaults.gold;

  final _controllers = <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await ref.read(planConfigRepositoryProvider).fetch();
    _bronze = cfg.bronze;
    _silver = cfg.silver;
    _gold = cfg.gold;
    for (final e in {
      'bronze': cfg.bronze,
      'silver': cfg.silver,
      'gold': cfg.gold,
    }.entries) {
      _controllers['${e.key}_branches'] =
          TextEditingController(text: e.value.maxBranches.toString());
      _controllers['${e.key}_users'] =
          TextEditingController(text: e.value.maxUsers.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _num(String key) => int.tryParse(_controllers[key]?.text.trim() ?? '') ?? 0;

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = PlanConfig(
      bronze: _bronze.copyWith(
          maxBranches: _num('bronze_branches'), maxUsers: _num('bronze_users')),
      silver: _silver.copyWith(
          maxBranches: _num('silver_branches'), maxUsers: _num('silver_users')),
      gold: _gold.copyWith(
          maxBranches: _num('gold_branches'), maxUsers: _num('gold_users')),
    );
    try {
      await ref.read(planConfigRepositoryProvider).save(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('پلانەکان پاشەکەوتکران'),
            backgroundColor: Color(0xFF10B981)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('هەڵە: $e'), backgroundColor: Colors.red.shade700));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: const Text('ڕێکخستنی پلانەکان',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryDarkBlue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _planCard('🥉 بڕۆنز', 'bronze', _bronze,
                    (f) => setState(() => _bronze = f)),
                const SizedBox(height: 16),
                _planCard('🥈 سیلڤەر', 'silver', _silver,
                    (f) => setState(() => _silver = f)),
                const SizedBox(height: 16),
                _planCard('🥇 گۆڵد', 'gold', _gold,
                    (f) => setState(() => _gold = f)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryDarkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('پاشەکەوتکردن',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _planCard(String title, String key, PlanFeatures f,
      ValueChanged<PlanFeatures> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryDarkBlue)),
          const Divider(height: 24),
          _toggle('گرێبەستی فرۆشتن', f.sale,
              (v) => onChanged(f.copyWith(sale: v))),
          _toggle('ئاگاداری کرێی دواکەوتوو', f.overdue,
              (v) => onChanged(f.copyWith(overdue: v))),
          _toggle('بازاڕی گشتی', f.market,
              (v) => onChanged(f.copyWith(market: v))),
          _toggle('خستنەڕووی موڵک', f.offers,
              (v) => onChanged(f.copyWith(offers: v))),
          _toggle('داواکاری موشتەری', f.requests,
              (v) => onChanged(f.copyWith(requests: v))),
          _toggle('پارێزەران', f.lawyers,
              (v) => onChanged(f.copyWith(lawyers: v))),
          _toggle('تەنها وێب (ئەپ ڕێگری لێدەکات)', f.webOnly,
              (v) => onChanged(f.copyWith(webOnly: v))),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                  child: _numField('ژمارەی لق', '${key}_branches')),
              const SizedBox(width: 12),
              Expanded(child: _numField('ژمارەی یوزەر', '${key}_users')),
            ],
          ),
          const SizedBox(height: 4),
          const Text('٠ = بێسنوور',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: _accentYellow,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _numField(String label, String controllerKey) {
    return TextField(
      controller: _controllers[controllerKey],
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
