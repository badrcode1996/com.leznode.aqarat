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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRent = contract.type == ContractType.rent;
    final company = ref.watch(currentCompanyProvider).value;
    return Card(
      child: ListTile(
        leading: Icon(isRent ? Icons.home_outlined : Icons.sell_outlined),
        title: Text(contract.listTitle),
        subtitle: Text(contract.listSubtitle),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'پرینت',
              icon: const Icon(Icons.print_outlined),
              onPressed: () =>
                  ContractPdfService.printContract(contract, company: company),
            ),
            IconButton(
              tooltip: 'هاوبەشکردن',
              icon: const Icon(Icons.share_outlined),
              onPressed: () =>
                  ContractPdfService.shareContract(contract, company: company),
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
