import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../contracts/installment_grid.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _accentYellow => AppColors.current.accent;
Color get _appBg => AppColors.current.pageBg;
Color get _inputFill => AppColors.current.inputFill;

/// Tenants tab: a simple list of rent-contract tenants by name. Tapping a name
/// opens its 12 rent installment cells (the day-to-day rent tracking). Full
/// contract actions (print/preview/edit/delete) live in the Archive.
class TenantsScreen extends ConsumerWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final async = ref.watch(contractsStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(S.tenants,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(
            child: Text(S.error(e), style: TextStyle(color: AppColors.current.danger))),
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
            Icon(Icons.people_outline, size: 72, color: AppColors.current.divider),
            const SizedBox(height: 16),
            Text(S.noTenants,
                style: TextStyle(
                    color: AppColors.current.textMuted,
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
    watchPalette(context);
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
          onTap: () => _openInstallments(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline,
                      color: AppColors.current.textStrong),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.current.textStrong),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: _accentYellow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
