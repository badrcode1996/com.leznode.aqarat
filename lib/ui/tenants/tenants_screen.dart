import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../contracts/installment_grid.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);
const Color _accentYellow = Color(0xFFF8B115);
const Color _appBg = Color(0xFFF5F7FA);
const Color _inputFill = Color(0xFFF3F4F6);

/// Tenants tab: a simple list of rent-contract tenants by name. Tapping a name
/// opens its 12 rent installment cells (the day-to-day rent tracking). Full
/// contract actions (print/preview/edit/delete) live in the Archive.
class TenantsScreen extends ConsumerWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractsStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: const Text('کرێچیەکان',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _primaryDarkBlue)),
        error: (e, _) => Center(
            child: Text('هەڵە: $e', style: const TextStyle(color: Colors.red))),
        data: (all) {
          final tenants = all.whereType<RentContract>().toList();
          if (tenants.isEmpty) {
            return _empty();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: tenants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TenantRow(contract: tenants[i]),
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('هیچ کرێچییەک نییە',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      );
}

class _TenantRow extends StatelessWidget {
  const _TenantRow({required this.contract});
  final RentContract contract;

  /// Name shown for the tenant; falls back to the owner if a tenant name is
  /// missing.
  String get _name => contract.party2Name.isNotEmpty
      ? contract.party2Name
      : contract.party1Name;

  void _openInstallments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: _appBg,
          appBar: AppBar(
            title: Text(_name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: _primaryDarkBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: InstallmentGrid(contract: contract),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onTap: () => _openInstallments(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: _inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline,
                      color: _primaryDarkBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryDarkBlue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: _accentYellow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
