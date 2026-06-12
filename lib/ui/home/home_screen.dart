import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../services/pdf/contract_pdf_service.dart';
import '../contracts/create_rent_contract_stepper.dart';
import '../contracts/create_sale_contract_stepper.dart';
import '../contracts/installment_grid.dart';
import '../market/global_market_tab.dart';

/// Top-level shell: Contracts list + Global Market tabs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('عقارات · ${user.displayName}'),
          actions: [
            IconButton(
              tooltip: 'دەرچوون',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'گرێبەستەکان', icon: Icon(Icons.description_outlined)),
              Tab(text: 'بازاڕی گشتی', icon: Icon(Icons.public)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ContractsTab(),
            GlobalMarketTab(kind: ListingKind.offer),
          ],
        ),
        floatingActionButton: _NewContractFab(),
      ),
    );
  }
}

class _NewContractFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('گرێبەستی نوێ'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('گرێبەستی کرێ'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateRentContractStepper()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('گرێبەستی فرۆشتن'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateSaleContractStepper()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractsTab extends ConsumerWidget {
  const _ContractsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsStreamProvider);
    return async.when(
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
    );
  }
}

class _ContractCard extends ConsumerWidget {
  const _ContractCard({required this.contract});
  final Contract contract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRent = contract.type == ContractType.rent;
    // Company is loaded for the branded PDF header (may still be loading/null).
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
                        child: InstallmentGrid(
                            contract: contract as RentContract),
                      ),
                    ),
                  ),
                )
            : null,
      ),
    );
  }
}
