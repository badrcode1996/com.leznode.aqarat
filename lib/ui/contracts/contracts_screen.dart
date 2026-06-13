import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/company_model.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../services/pdf/contract_pdf_service.dart';
import 'contract_preview_screen.dart';
import 'installment_grid.dart';

/// Contracts tab: rent / sale sub-tabs (like the market), with print/share +
/// the rent installment grid.
class ContractsScreen extends StatelessWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('گرێبەستەکان'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'کرێ'),
              Tab(text: 'فرۆشتن'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ContractsList(type: ContractType.rent),
            _ContractsList(type: ContractType.sale),
          ],
        ),
      ),
    );
  }
}

class _ContractsList extends ConsumerWidget {
  const _ContractsList({required this.type});
  final ContractType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsStreamProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('هەڵە: $e')),
      data: (all) {
        final contracts = all.where((c) => c.type == type).toList();
        if (contracts.isEmpty) {
          return const Center(child: Text('هیچ گرێبەستێک نییە'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: contracts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _ContractCard(contract: contracts[i]),
        );
      },
    );
  }
}

class _ContractCard extends ConsumerWidget {
  const _ContractCard({required this.contract});
  final Contract contract;

  void _openPreview(BuildContext context, Company? company) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ContractPreviewScreen(contract: contract, company: company),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('پرینت سەرکەوتوو نەبوو: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRent = contract.type == ContractType.rent;
    final company = ref.watch(currentCompanyProvider).value;
    final typeLabel = isRent ? 'کرێ' : 'فرۆشتن';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isRent ? Colors.green : Colors.blue)
              .withValues(alpha: 0.12),
          child: Text('#${contract.contractNumber}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        title: Text('${contract.listTitle} · $typeLabel'),
        subtitle: Text(contract.listSubtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'پێشبینین',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => _openPreview(context, company),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'preview') {
                  _openPreview(context, company);
                } else if (v == 'print') {
                  _run(context,
                      () => ContractPdfService.printContract(contract, company: company));
                } else if (v == 'share') {
                  _run(context,
                      () => ContractPdfService.shareContract(contract, company: company));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'preview',
                  child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('پێشبینین')),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('پرینت')),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('هاوبەشکردن')),
                ),
              ],
            ),
          ],
        ),
        onTap: isRent
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(contract.listTitle)),
                      body: SingleChildScrollView(
                        child:
                            InstallmentGrid(contract: contract as RentContract),
                      ),
                    ),
                  ),
                )
            : null,
      ),
    );
  }
}
