import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/plan_config_repository.dart';
import '../../data/template_repository.dart';
import '../../models/contract_template_model.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _inputFill = Color(0xFFF3F4F6);

/// Kurdish / Arabic picker for the document a contract form is about to
/// produce.
///
/// Renders NOTHING unless Arabic is actually usable: the plan must include it
/// AND this company must have Arabic clauses stored for this contract type. A
/// picker with one real option would just be a dead control, and picking
/// Arabic without clauses would fail at render time.
class DocLangField extends ConsumerWidget {
  const DocLangField({
    super.key,
    required this.isRent,
    required this.value,
    required this.onChanged,
  });

  /// Rent and sale have separate Arabic clause lists; a company may have
  /// translated one and not the other.
  final bool isRent;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(currentPlanFeaturesProvider).arabicContracts) {
      return const SizedBox.shrink();
    }
    // A Super Admin has no company of their own (session.dart gives them an
    // empty companyId), and the template stream is briefly unresolved on a
    // cold open. Neither means "no Arabic" — both fall back to the built-in
    // template, which always carries the Arabic clauses.
    final companyId = ref.watch(currentUserProvider).companyId;
    final tpl = companyId.isEmpty
        ? ContractTemplate.defaults()
        : (ref.watch(contractTemplateProvider(companyId)).valueOrNull ??
            ContractTemplate.defaults());

    final clauses = isRent ? tpl.rentClausesAr : tpl.saleClausesAr;
    if (clauses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.translate_rounded,
                    size: 18, color: _primaryDarkBlue),
                SizedBox(width: 8),
                Text('زمانی گرێبەست',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryDarkBlue)),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                backgroundColor: _inputFill,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: _primaryDarkBlue,
                side: BorderSide(color: Colors.grey.shade200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              segments: const [
                ButtonSegment(
                  value: 'ku',
                  label: Text('کوردی',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                ButtonSegment(
                  value: 'ar',
                  label: Text('عەرەبی',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
