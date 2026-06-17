import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/enums.dart';
import '../models/plan_config_model.dart';

/// Live stream of the Super-Admin-edited plan config (`config/plans`). Falls
/// back to the built-in defaults when the document is missing.
final planConfigProvider = StreamProvider<PlanConfig>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('config')
      .doc('plans')
      .snapshots()
      .map((s) =>
          s.exists ? PlanConfig.fromJson(s.data()!) : PlanConfig.defaults);
});

/// The feature set that applies to the SIGNED-IN user's company plan. Super
/// admins get the Gold set (they see everything). Falls back to defaults until
/// the stream resolves.
final currentPlanFeaturesProvider = Provider<PlanFeatures>((ref) {
  final user = ref.watch(currentUserProvider);
  final config =
      ref.watch(planConfigProvider).valueOrNull ?? PlanConfig.defaults;
  if (user.role == UserRole.superAdmin) return config.gold;
  return config.forPlan(user.plan);
});

final planConfigRepositoryProvider = Provider<PlanConfigRepository>((ref) {
  return PlanConfigRepository(ref.watch(firestoreProvider));
});

/// Reads/writes the global plan configuration. Writes are Super-Admin-only
/// (enforced by the Firestore rules).
class PlanConfigRepository {
  PlanConfigRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('config').doc('plans');

  Future<PlanConfig> fetch() async {
    final snap = await _doc.get();
    return snap.exists ? PlanConfig.fromJson(snap.data()!) : PlanConfig.defaults;
  }

  Future<void> save(PlanConfig config) => _doc.set(config.toJson());
}
