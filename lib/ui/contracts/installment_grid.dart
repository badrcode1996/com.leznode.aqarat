import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';

/// Grid of the 12 rent installments. Tapping the status chip cycles
/// pending → received → delivered and persists via the transactional
/// [ContractRepository.updateInstallmentStatus] (which also updates stats).
class InstallmentGrid extends ConsumerWidget {
  const InstallmentGrid({super.key, required this.contract});

  final RentContract contract;

  static final _date = DateFormat('yyyy/MM/dd');

  PaymentStatus _next(PaymentStatus s) => switch (s) {
        PaymentStatus.pending => PaymentStatus.receivedFromTenant,
        PaymentStatus.receivedFromTenant => PaymentStatus.deliveredToOwner,
        PaymentStatus.deliveredToOwner => PaymentStatus.pending,
      };

  (String, Color) _style(PaymentStatus s) => switch (s) {
        PaymentStatus.pending => ('چاوەڕوان', Colors.grey),
        PaymentStatus.receivedFromTenant => ('وەرگیرا', Colors.orange),
        PaymentStatus.deliveredToOwner => ('گەیەنرا', Colors.green),
      };

  Future<void> _cycle(
      BuildContext context, WidgetRef ref, Installment inst) async {
    try {
      await ref.read(contractRepositoryProvider).updateInstallmentStatus(
            contractId: contract.id,
            monthNumber: inst.monthNumber,
            newStatus: _next(inst.status),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('هەڵە: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contract.installments.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final inst = contract.installments[i];
        final (label, color) = _style(inst.status);
        return Card(
          color: color.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => _cycle(context, ref, inst),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('مانگی ${inst.monthNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(_date.format(inst.dueDate),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
