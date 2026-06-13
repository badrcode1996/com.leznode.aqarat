import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../services/pdf/contract_pdf_service.dart';
import 'installment_grid.dart';

/// Contracts tab: the current tenant/role's contracts with print/share + the
/// rent installment grid.
class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('گرێبەستەکان')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('هەڵە: $e')),
        data: (contracts) {
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
      ),
    );
  }
}

class _ContractCard extends ConsumerWidget {
  const _ContractCard({required this.contract});
  final Contract contract;

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
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'پرینت',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _run(context,
                  () => ContractPdfService.printContract(contract, company: company)),
            ),
            IconButton(
              tooltip: 'هاوبەشکردن',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _run(context,
                  () => ContractPdfService.shareContract(contract, company: company)),
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
