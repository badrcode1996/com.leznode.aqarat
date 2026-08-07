import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/contract_repository.dart';
import '../../models/contract_model.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _appBg => AppColors.current.pageBg;
Color get _red => AppColors.current.danger;

/// One overdue rent installment for a tenant.
class _Overdue {
  _Overdue(this.contract, this.inst);
  final RentContract contract;
  final Installment inst;
}

/// Lists tenants (کرێچی) with overdue rent — name, phone, due date — opened
/// from the dashboard "پارەی دواکەوتوو" stat.
class OverdueScreen extends ConsumerWidget {
  const OverdueScreen({super.key});

  static final _date = DateFormat('yyyy/MM/dd');
  static final _money = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final async = ref.watch(contractsStreamProvider);
    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(S.overdueTenants,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e))),
        data: (contracts) {
          final now = DateTime.now();
          final items = <_Overdue>[];
          for (final c in contracts) {
            if (c is RentContract) {
              for (final inst in c.installments) {
                if (inst.status == PaymentStatus.pending &&
                    inst.dueDate.isBefore(now)) {
                  items.add(_Overdue(c, inst));
                }
              }
            }
          }
          items.sort((a, b) => a.inst.dueDate.compareTo(b.inst.dueDate));

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 56, color: AppColors.current.success),
                    const SizedBox(height: 12),
                    Text(S.noOverdue,
                        style: TextStyle(
                            color: AppColors.current.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OverdueCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _OverdueCard extends StatelessWidget {
  const _OverdueCard({required this.item});
  final _Overdue item;

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.cannotCall),
            backgroundColor: AppColors.current.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    watchPalette(context);
    final c = item.contract;
    final inst = item.inst;
    final days = DateTime.now().difference(inst.dueDate).inDays;
    final phone = c.party2Mobile;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: AppColors.current.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _red.withValues(alpha: 0.1),
              child: Icon(Icons.person_rounded, color: _red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.party2Name.isEmpty ? S.emptyValue : c.party2Name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.current.textStrong),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded,
                          size: 13, color: AppColors.current.textMuted),
                      const SizedBox(width: 4),
                      Text(phone.isEmpty ? S.emptyValue : phone,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.current.textBody)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      _chip(Icons.event_busy_rounded,
                          S.dateWith(OverdueScreen._date.format(inst.dueDate))),
                      _chip(Icons.payments_rounded,
                          '${OverdueScreen._money.format(c.rentAmount)} ${c.currency.label}'),
                      _chip(Icons.tag_rounded, S.monthNumber(inst.monthNumber)),
                      _chip(Icons.timelapse_rounded, S.daysOverdue(days),
                          color: _red),
                    ],
                  ),
                ],
              ),
            ),
            if (phone.isNotEmpty)
              IconButton(
                tooltip: S.callAction,
                icon: CircleAvatar(
                  backgroundColor: AppColors.current.success,
                  radius: 20,
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => _call(context, phone),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppColors.current.textMuted),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  color: color ?? AppColors.current.textBody,
                  fontWeight: color != null ? FontWeight.bold : FontWeight.w500)),
        ],
      );
}
