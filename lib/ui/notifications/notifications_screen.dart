import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/session.dart';
import '../../data/contract_repository.dart';
import '../../data/notification_repository.dart';
import '../../models/contract_model.dart';
import '../../models/notification_model.dart';
import '../contracts/installment_grid.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

Color get _primaryDarkBlue => AppColors.current.brand;
Color get _accentYellow => AppColors.current.accent;
Color get _appBg => AppColors.current.pageBg;

/// Notification centre — opened from the bell on the dashboard.
///
/// Everything here is raised server-side by the daily `scanDueDates` schedule;
/// the app only reads, marks read and routes to the contract concerned.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static final _date = DateFormat('yyyy/MM/dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final uid = ref.watch(currentUserProvider).uid;
    final async = ref.watch(notificationsProvider);
    final items = async.valueOrNull ?? const <AppNotification>[];
    final hasUnread = items.any((n) => !n.isReadBy(uid));

    return Scaffold(
      backgroundColor: _appBg,
      appBar: AppBar(
        title: Text(S.notifications,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryDarkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: () => ref
                  .read(notificationRepositoryProvider)
                  .markAllRead(items),
              icon: Icon(Icons.done_all_rounded,
                  color: _accentYellow, size: 20),
              label: Text(S.markAllRead,
                  style: TextStyle(
                      color: _accentYellow, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: async.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.current.textStrong)),
        error: (e, _) => Center(child: Text(S.error(e))),
        data: (list) {
          if (list.isEmpty) return _empty();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _NotificationCard(notification: list[i]),
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 64, color: AppColors.current.divider),
              const SizedBox(height: 12),
              Text(S.noNotifications,
                  style: TextStyle(
                      color: AppColors.current.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                S.noNotificationsBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.current.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
}

/// Per-type presentation. Kept beside the card so adding a type is one entry.
({IconData icon, Color color}) _style(NotificationType type) =>
    switch (type) {
      NotificationType.rentOverdue => (
          icon: Icons.warning_rounded,
          color: AppColors.current.danger,
        ),
      NotificationType.rentDueSoon => (
          icon: Icons.schedule_rounded,
          color: AppColors.current.warning,
        ),
      NotificationType.contractExpiring => (
          icon: Icons.event_busy_rounded,
          color: AppColors.current.violet,
        ),
    };

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  /// The contract this concerns, when it is still in the streamed page. Null
  /// when it was deleted or falls outside what the user may read — the card
  /// then simply loses its tap target instead of erroring.
  RentContract? _contract(WidgetRef ref) {
    final all = ref.watch(contractsStreamProvider).valueOrNull ?? const [];
    for (final c in all) {
      if (c.id == notification.contractId && c is RentContract) return c;
    }
    return null;
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.cannotCall),
          backgroundColor: AppColors.current.danger));
    }
  }

  /// Opens the same installment grid the Tenants tab uses, so the alert lands
  /// on the screen where the payment is actually recorded.
  void _open(BuildContext context, RentContract contract) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: _appBg,
          appBar: AppBar(
            title: Text(
                contract.party2Name.isNotEmpty
                    ? contract.party2Name
                    : contract.party1Name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: _primaryDarkBlue,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
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
  Widget build(BuildContext context, WidgetRef ref) {
    watchPalette(context);
    final uid = ref.watch(currentUserProvider).uid;
    final unread = !notification.isReadBy(uid);
    final style = _style(notification.type);
    final contract = _contract(ref);
    final phone = contract?.party2Mobile ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.current.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unread
                ? style.color.withValues(alpha: 0.35)
                : AppColors.current.divider),
        boxShadow: [
          BoxShadow(
              color: AppColors.current.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (unread) {
              ref.read(notificationRepositoryProvider).markRead(notification.id);
            }
            if (contract != null) _open(context, contract);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.current.textStrong,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsetsDirectional.only(start: 6),
                              decoration: BoxDecoration(
                                  color: style.color, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                            fontSize: 13.5, color: AppColors.current.textBody),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          if (notification.dueDate != null)
                            _chip(
                                Icons.event_rounded,
                                S.dateLabel +
                                    NotificationsScreen._date
                                        .format(notification.dueDate!)),
                          _chip(Icons.access_time_rounded,
                              _relative(notification.createdAt)),
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
                      radius: 18,
                      child: const Icon(Icons.call_rounded,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => _call(context, phone),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.current.textMuted),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.current.textMuted,
                  fontWeight: FontWeight.w500)),
        ],
      );

  static String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 60) return S.justNow;
    if (diff.inHours < 24) return S.hoursAgo(diff.inHours);
    if (diff.inDays == 1) return S.yesterday;
    return S.daysAgo(diff.inDays);
  }
}
