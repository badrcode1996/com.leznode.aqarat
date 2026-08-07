import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/plan_config_repository.dart';
import '../../data/template_repository.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';
import '../../models/contract_template_model.dart';
import '../../theme/app_colors.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _inputFill => AppColors.current.inputFill;

/// Whether this company can actually produce an ARABIC document for a rent
/// (or sale) contract right now.
///
/// Two things have to hold: the plan sells Arabic contracts, and this company
/// has Arabic clauses stored for THIS contract type — a company may have
/// translated its rent clauses and not its sale ones. A Super Admin has no
/// company of their own, and the template stream is briefly unresolved on a
/// cold open; neither means "no Arabic", so both fall back to the built-in
/// template, which always carries the Arabic clauses.
bool arabicDocAvailable(WidgetRef ref, {required bool isRent}) {
  if (!ref.watch(currentPlanFeaturesProvider).arabicContracts) return false;
  final companyId = ref.watch(currentUserProvider).companyId;
  final tpl = companyId.isEmpty
      ? ContractTemplate.defaults()
      : (ref.watch(contractTemplateProvider(companyId)).valueOrNull ??
          ContractTemplate.defaults());
  return (isRent ? tpl.rentClausesAr : tpl.saleClausesAr).isNotEmpty;
}

/// The language a contract's document opens on, given the interface language.
///
/// Kurdish is the house default and stays so for the Kurdish AND English
/// interfaces — an English-speaking agent in Erbil still issues the Kurdish
/// paperwork. Only an Arabic interface flips it, and only when Arabic is
/// actually available: defaulting to a document the plan doesn't include would
/// fail at render time, since the renderer re-checks the plan server-side.
///
/// It is only a DEFAULT — the user still switches per contract, exactly as
/// before.
///
/// Kept free of Riverpod so the rule itself is unit-testable; the widget-facing
/// [defaultDocLang] just feeds it.
String docLangFor(AppLanguage app, {required bool arabicAvailable}) =>
    app == AppLanguage.ar && arabicAvailable ? 'ar' : 'ku';

/// [docLangFor] for a new contract on this screen.
String defaultDocLang(WidgetRef ref, {required bool isRent}) => docLangFor(
      S.language,
      arabicAvailable: arabicDocAvailable(ref, isRent: isRent),
    );

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
    watchPalette(context);
    if (!arabicDocAvailable(ref, isRent: isRent)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.translate_rounded,
                    size: 18, color: AppColors.current.textStrong),
                const SizedBox(width: 8),
                Text('زمانی گرێبەست',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.current.textStrong)),
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
                side: BorderSide(color: AppColors.current.divider),
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
