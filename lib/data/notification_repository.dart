import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/notification_model.dart';

/// How many notifications the centre keeps on screen. Older ones stay in
/// Firestore (the daily scan prunes them) but are never streamed — an unbounded
/// listener here would grow with every month the tenant uses the product.
const _kNotificationPageSize = 60;

/// Repository for the `notifications` collection. Reads are scoped the same way
/// contracts are — by company, and by branch for everyone who isn't a
/// company-wide admin — so a user only ever sees alerts about contracts they
/// can already open.
class NotificationRepository {
  NotificationRepository(this._db, this._user);

  final FirebaseFirestore _db;
  final SessionUser _user;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  /// Mirrors ContractRepository._scopedQuery — see the note there: these
  /// clauses must match the security rules or isolation is client-side only.
  Query<Map<String, dynamic>> _scopedQuery() {
    var query = _col.where('company_id', isEqualTo: _user.companyId);
    if (!_user.isCompanyWide) {
      query = query.where('branch', isEqualTo: _user.branch);
    }
    return query.orderBy('created_at', descending: true).limit(
          _kNotificationPageSize,
        );
  }

  Stream<List<AppNotification>> watchNotifications() {
    if (_user.companyId.isEmpty) return Stream.value(const []);
    return _scopedQuery().snapshots().map((snap) => snap.docs
        .map((d) => AppNotification.fromJson(d.id, d.data()))
        .toList());
  }

  /// Adds this user to the notification's `read_by` array. arrayUnion is
  /// idempotent, so opening the same notification twice costs one write at
  /// most and can never duplicate the uid.
  Future<void> markRead(String id) =>
      _col.doc(id).update({'read_by': FieldValue.arrayUnion([_user.uid])});

  /// Marks everything currently unread for this user as read, in one batch.
  Future<void> markAllRead(List<AppNotification> shown) async {
    final unread = shown.where((n) => !n.isReadBy(_user.uid)).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final n in unread) {
      batch.update(_col.doc(n.id), {
        'read_by': FieldValue.arrayUnion([_user.uid]),
      });
    }
    await batch.commit();
  }
}

/// ---------------------------------------------------------------------------
/// Riverpod wiring
/// ---------------------------------------------------------------------------

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUserProvider),
  );
});

/// Live notifications for the signed-in user's company/branch.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).watchNotifications();
});

/// Unread count for the dashboard badge. Derived from the list stream, so the
/// badge costs no extra read on top of the centre itself.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final uid = ref.watch(currentUserProvider).uid;
  final all = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return all.where((n) => !n.isReadBy(uid)).length;
});
