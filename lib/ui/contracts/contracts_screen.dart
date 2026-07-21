import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/template_repository.dart';
import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/contract_template_model.dart';
import '../../models/enums.dart';
import '../../services/pdf/contract_pdf_remote.dart';
import 'contract_preview_screen.dart';
import 'create_rent_contract_stepper.dart';
import 'create_sale_contract_stepper.dart';
import 'installment_grid.dart';
import 'widgets/contract_docs_field.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color primaryDarkBlue = Color(0xFF0F2C59);
const Color accentYellow = Color(0xFFF8B115);
const Color appBackgroundColor = Color(0xFFF5F7FA);

/// Reusable contracts body (rent / sale sub-tabs) with print/share + the rent
/// installment grid. Rendered inside the Archive screen's "گرێبەستەکان" tab —
/// no Scaffold/AppBar of its own so it can nest under the Archive's top tabs.
class ContractsArchiveBody extends StatelessWidget {
  const ContractsArchiveBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            elevation: 1,
            child: TabBar(
              indicatorColor: accentYellow,
              indicatorWeight: 3,
              labelColor: primaryDarkBlue,
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: [
                Tab(text: 'کرێ'),
                Tab(text: 'فرۆشتن'),
              ],
            ),
          ),
          Expanded(
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
    final async = ref.watch(contractsStreamProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: primaryDarkBlue)),
      error: (e, _) => Center(child: Text('هەڵە: $e', style: const TextStyle(color: Colors.red))),
      data: (all) {
        final ofType = all.where((c) => c.type == type).toList();
        if (ofType.isEmpty) {
          return _emptyBox(
            type == ContractType.rent ? 'هیچ گرێبەستێکی کرێ نییە' : 'هیچ گرێبەستێکی فرۆشتن نییە',
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
                  ? _emptyBox('هیچ ئەنجامێک نەدۆزرایەوە بۆ «$_query»',
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
            hintText: 'گەڕان بە ناو، ژمارەی مۆبایل، ژمارەی عەقار…',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: primaryDarkBlue),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryDarkBlue, width: 1.5),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: inputFillColor, shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

const Color inputFillColor = Color(0xFFF3F4F6);

class _ContractCard extends ConsumerWidget {
  const _ContractCard({required this.contract});
  final Contract contract;

  void _openPreview(
      BuildContext context, Company? company, ContractTemplate? template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContractPreviewScreen(
            contract: contract, company: company, template: template),
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('پرینت سەرکەوتوو نەبوو: $e'),
            backgroundColor: Colors.red.shade700,
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
            title: const Text('بەڵگەکان',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('سڕینەوەی گرێبەست',
            style: TextStyle(
                color: primaryDarkBlue, fontWeight: FontWeight.bold)),
        content: Text(
            'دڵنیایت لە سڕینەوەی گرێبەست #${contract.contractNumber} (${contract.listTitle})؟ ئەم کردارە ناگەڕێتەوە.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('پاشگەزبوونەوە',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سڕینەوە'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(contractRepositoryProvider).deleteContract(contract);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('گرێبەست سڕایەوە'),
              backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('هەڵە: $e'),
              backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRent = contract.type == ContractType.rent;
    final company = ref.watch(currentCompanyProvider).value;
    final template =
        ref.watch(contractTemplateProvider(contract.companyId)).value;
    final isAdmin = ref.watch(currentUserProvider).isAdmin;
    final typeLabel = isRent ? 'کرێ' : 'فرۆشتن';

    // ڕەنگکردنی جۆری گرێبەستەکە
    final Color iconBgColor = isRent ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF3B82F6).withValues(alpha: 0.15);
    final Color iconColor = isRent ? const Color(0xFF10B981) : const Color(0xFF3B82F6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDarkBlue),
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
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contract.listSubtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                        tooltip: 'بەڵگەکان (${contract.attachmentUrls.length})',
                        icon: Badge.count(
                          count: contract.attachmentUrls.length,
                          backgroundColor: accentYellow,
                          textColor: primaryDarkBlue,
                          child: const Icon(Icons.photo_library_outlined,
                              color: primaryDarkBlue),
                        ),
                        onPressed: () => _openDocs(context),
                      )
                    else
                      IconButton(
                        tooltip: 'بەڵگەکان (بەتاڵ)',
                        icon: Icon(Icons.photo_library_outlined,
                            color: Colors.grey.shade400),
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              'هیچ بەڵگەیەک زیاد نەکراوە — لە دەستکاریدا دەتوانیت زیادی بکەیت'),
                        )),
                      ),
                    IconButton(
                      tooltip: 'پێشبینین',
                      icon: const Icon(Icons.visibility_outlined, color: primaryDarkBlue),
                      onPressed: () => _openPreview(context, company, template),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'preview') {
                          _openPreview(context, company, template);
                        } else if (v == 'print') {
                          _run(context, () => ContractPdfRemote.printContract(contract.id));
                        } else if (v == 'share') {
                          _run(context, () => ContractPdfRemote.shareContract(contract.id));
                        } else if (v == 'edit') {
                          _edit(context);
                        } else if (v == 'delete') {
                          _delete(context, ref);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: primaryDarkBlue, size: 20),
                              SizedBox(width: 12),
                              Text('پێشبینین'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print_outlined, color: primaryDarkBlue, size: 20),
                              SizedBox(width: 12),
                              Text('پرینت'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, color: primaryDarkBlue, size: 20),
                              SizedBox(width: 12),
                              Text('هاوبەشکردن'),
                            ],
                          ),
                        ),
                        if (isAdmin) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: primaryDarkBlue, size: 20),
                                SizedBox(width: 12),
                                Text('دەستکاری'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 12),
                                const Text('سڕینەوە'),
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