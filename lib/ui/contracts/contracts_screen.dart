import '../../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/plan_config_repository.dart';
import '../../data/template_repository.dart';
import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/contract_template_model.dart';
import '../../l10n/app_strings.dart';
import '../../models/enums.dart';
import '../../services/pdf/contract_pdf_remote.dart';
import 'contract_preview_screen.dart';
import 'doc_lang_field.dart';
import 'create_rent_contract_stepper.dart';
import 'create_sale_contract_stepper.dart';
import 'installment_grid.dart';
import 'widgets/contract_docs_field.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
Color get primaryDarkBlue => AppColors.current.brand;
Color get accentYellow => AppColors.current.accent;
Color get appBackgroundColor => AppColors.current.pageBg;

/// Reusable contracts body (rent / sale sub-tabs) with print/share + the rent
/// installment grid. Rendered inside the Archive screen's "گرێبەستەکان" tab —
/// no Scaffold/AppBar of its own so it can nest under the Archive's top tabs.
class ContractsArchiveBody extends StatelessWidget {
  const ContractsArchiveBody({super.key});

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppColors.current.card,
            elevation: 1,
            child: TabBar(
              indicatorColor: accentYellow,
              indicatorWeight: 3,
              labelColor: AppColors.current.textStrong,
              unselectedLabelColor: AppColors.current.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: [
                Tab(text: S.contractRent),
                Tab(text: S.contractSale),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _ContractsList(type: ContractType.rent),
                _ContractsList(type: ContractType.sale),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractsList extends ConsumerStatefulWidget {
  const _ContractsList({required this.type});
  final ContractType type;

  @override
  ConsumerState<_ContractsList> createState() => _ContractsListState();
}

class _ContractsListState extends ConsumerState<_ContractsList> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  ContractType get type => widget.type;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    final async = ref.watch(contractsStreamProvider);
    return async.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
      error: (e, _) => Center(child: Text(S.error(e), style: TextStyle(color: AppColors.current.danger))),
      data: (all) {
        final ofType = all.where((c) => c.type == type).toList();
        if (ofType.isEmpty) {
          return _emptyBox(
            type == ContractType.rent ? S.noRentContracts : S.noSaleContracts,
            type == ContractType.rent ? Icons.key_outlined : Icons.sell_outlined,
          );
        }
        final contracts =
            _query.isEmpty ? ofType : ofType.where((c) => c.matches(_query)).toList();
        return Column(
          children: [
            _searchField(),
            Expanded(
              child: contracts.isEmpty
                  ? _emptyBox(S.noResultsFor(_query),
                      Icons.search_off_rounded)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: contracts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ContractCard(contract: contracts[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Matches on either party's name or mobile, the property/project and the
  /// contract number — see Contract.searchIndex.
  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: S.searchHint,
            hintStyle: TextStyle(color: AppColors.current.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.current.textStrong),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.current.textMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: AppColors.current.inputFill,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.current.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.current.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryDarkBlue, width: 1.5),
            ),
          ),
        ),
      );

  // دیزاینی مۆدێرن بۆ شاشەی بەتاڵ
  Widget _emptyBox(String text, IconData icon) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.current.divider, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.current.shadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: inputFillColor, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: AppColors.current.textFaint),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: AppColors.current.textMuted, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Color get inputFillColor => AppColors.current.inputFill;

class _ContractCard extends ConsumerWidget {
  const _ContractCard({required this.contract});
  final Contract contract;

  /// [lang] null means "whichever edition this interface opens on" — Kurdish,
  /// or Arabic when the app itself is in Arabic and the company has Arabic
  /// clauses. The long-press menu passes an explicit language to override it.
  void _openPreview(
      BuildContext context, Company? company, ContractTemplate? template,
      {String? lang, bool arabicAvailable = false}) {
    final effective =
        lang ?? docLangFor(S.language, arabicAvailable: arabicAvailable);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractPreviewScreen(
            contract: contract,
            company: company,
            template: template,
            initialLang: effective),
      ),
    );
  }

  /// Long-pressing the view button asks which edition to open. A plain tap
  /// still goes straight to Kurdish, so the common case stays one tap.
  Future<void> _pickLangThenPreview(
      BuildContext context, Company? company, ContractTemplate? template) async {
    final lang = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(S.pickViewLanguage,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.current.textStrong)),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined,
                  color: AppColors.current.textStrong),
              title: Text(S.langKurdish,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, 'ku'),
            ),
            ListTile(
              leading:
                  Icon(Icons.translate_rounded, color: AppColors.current.textStrong),
              title: Text(S.langArabic,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, 'ar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (lang == null || !context.mounted) return;
    _openPreview(context, company, template, lang: lang);
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.printFailed(e)),
            backgroundColor: AppColors.current.danger,
          ),
        );
      }
    }
  }

  /// The contract's attachment photos on their own screen. Reachable for rent
  /// AND sale contracts — the installments screen that used to host them only
  /// exists for rent, so a sale contract's documents had nowhere to be seen.
  void _openDocs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: appBackgroundColor,
          appBar: AppBar(
            title: Text(S.attachments,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: primaryDarkBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ContractDocsViewer(urls: contract.attachmentUrls),
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context) {
    final c = contract;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => c is RentContract
            ? CreateRentContractStepper(existing: c)
            : CreateSaleContractStepper(existing: c as SaleContract),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.deleteContract,
            style: TextStyle(
                color: AppColors.current.textStrong, fontWeight: FontWeight.bold)),
        content: Text(
            S.deleteContractConfirm(contract.contractNumber, contract.listTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel,
                style: TextStyle(color: AppColors.current.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.current.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(contractRepositoryProvider).deleteContract(contract);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.contractDeleted),
              backgroundColor: AppColors.current.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.error(e)),
              backgroundColor: AppColors.current.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchAppShell(context);
    final isRent = contract.type == ContractType.rent;
    final company = ref.watch(currentCompanyProvider).value;
    final template =
        ref.watch(contractTemplateProvider(contract.companyId)).value;
    final isAdmin = ref.watch(currentUserProvider).isAdmin;
    final features = ref.watch(currentPlanFeaturesProvider);
    // The plan sells it, and this company has Arabic clauses for THIS contract
    // type — both are needed before an Arabic option may be offered.
    // A null template is one still streaming in, not a company without Arabic;
    // the built-in template always carries the Arabic clauses.
    final arabicAvailable = features.arabicContracts &&
        (template ?? ContractTemplate.defaults()).arabicReadyFor(contract);
    final typeLabel = isRent ? S.contractRent : S.contractSale;

    // ڕەنگکردنی جۆری گرێبەستەکە
    final Color iconBgColor = isRent ? AppColors.current.success.withValues(alpha: 0.15) : AppColors.current.info.withValues(alpha: 0.15);
    final Color iconColor = isRent ? AppColors.current.success : AppColors.current.info;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.current.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isRent
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) {
                final rent = contract as RentContract;
                return Scaffold(
                  backgroundColor: appBackgroundColor,
                  appBar: AppBar(
                    title: Text(contract.listTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: primaryDarkBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    centerTitle: true,
                  ),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        InstallmentGrid(contract: rent),
                        // بەڵگە هاوپێچەکانی گرێبەستەکە (ئەگەر هەبن).
                        ContractDocsViewer(urls: rent.attachmentUrls),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ئایکۆن و ژمارەی گرێبەست
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#${contract.contractNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // زانیارییەکان
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contract.listTitle,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.current.textStrong),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: inputFillColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.current.textBody),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contract.listSubtitle,
                        style: TextStyle(fontSize: 13, color: AppColors.current.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // دوگمەکانی خێرا و مینیو
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // هەمیشە دەردەکەوێت — بە بەتاڵی ڕەنگخنکاو دەبێت، تا
                    // بەکارهێنەر بزانێت بەڵگەکان لەکوێن.
                    if (contract.attachmentUrls.isNotEmpty)
                      IconButton(
                        tooltip: S.attachmentsCount(contract.attachmentUrls.length),
                        icon: Badge.count(
                          count: contract.attachmentUrls.length,
                          backgroundColor: accentYellow,
                          textColor: AppColors.current.textStrong,
                          child: Icon(Icons.photo_library_outlined,
                              color: AppColors.current.textStrong),
                        ),
                        onPressed: () => _openDocs(context),
                      )
                    else
                      IconButton(
                        tooltip: S.attachmentsEmpty,
                        icon: Icon(Icons.photo_library_outlined,
                            color: AppColors.current.textFaint),
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                              S.attachmentsNoneHint),
                        )),
                      ),
                    // InkWell, not IconButton: IconButton has no long-press,
                    // and the long press is what offers the Arabic edition.
                    Tooltip(
                      message: arabicAvailable
                          ? S.previewHint
                          : S.preview,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _openPreview(context, company, template, arabicAvailable: arabicAvailable),
                        onLongPress: arabicAvailable
                            ? () => _pickLangThenPreview(
                                context, company, template)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.visibility_outlined,
                              color: AppColors.current.textStrong),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: AppColors.current.textMuted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'preview') {
                          _openPreview(context, company, template, arabicAvailable: arabicAvailable);
                        } else if (v == 'print') {
                          _run(context, () => ContractPdfRemote.printContract(contract.id));
                        } else if (v == 'print_ar') {
                          _run(context,
                              () => ContractPdfRemote.printContract(contract.id, lang: 'ar'));
                        } else if (v == 'share') {
                          _run(context, () => ContractPdfRemote.shareContract(contract.id));
                        } else if (v == 'edit') {
                          _edit(context);
                        } else if (v == 'delete') {
                          _delete(context, ref);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: AppColors.current.textStrong, size: 20),
                              const SizedBox(width: 12),
                              Text(S.preview),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print_outlined, color: AppColors.current.textStrong, size: 20),
                              const SizedBox(width: 12),
                              Text(S.print),
                            ],
                          ),
                        ),
                        // Only when the plan includes it AND this company has
                        // Arabic clauses for THIS contract type on file.
                        if (arabicAvailable)
                          PopupMenuItem(
                            value: 'print_ar',
                            child: Row(
                              children: [
                                Icon(Icons.translate_rounded,
                                    color: AppColors.current.textStrong, size: 20),
                                const SizedBox(width: 12),
                                Text(S.printArabic),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, color: AppColors.current.textStrong, size: 20),
                              const SizedBox(width: 12),
                              Text(S.share),
                            ],
                          ),
                        ),
                        if (isAdmin) ...[
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.current.textStrong, size: 20),
                                const SizedBox(width: 12),
                                Text(S.edit),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: AppColors.current.danger, size: 20),
                                const SizedBox(width: 12),
                                Text(S.delete),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}