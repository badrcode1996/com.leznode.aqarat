import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/contract_template_model.dart';

/// Repository for the `templates` collection (doc id == company_id). Reads are
/// allowed for the owning company (to render) and super admins; writes are
/// super-admin only (enforced by the Firestore rules).
class TemplateRepository {
  TemplateRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String companyId) =>
      _db.collection('templates').doc(companyId);

  /// The company's template, or the built-in [ContractTemplate.defaults] when
  /// no document exists yet. Missing fields always fall back to the defaults.
  Future<ContractTemplate> fetch(String companyId) async {
    if (companyId.isEmpty) return ContractTemplate.defaults();
    final snap = await _doc(companyId).get();
    if (!snap.exists) return ContractTemplate.defaults();
    return ContractTemplate.fromJson(snap.data()!);
  }

  /// Super-admin save.
  Future<void> save(String companyId, ContractTemplate template) {
    return _doc(companyId).set(template.toJson(), SetOptions(merge: true));
  }

  /// Resets a company back to the built-in default by deleting its override.
  Future<void> resetToDefault(String companyId) {
    return _doc(companyId).delete();
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(ref.watch(firestoreProvider));
});

/// The resolved template for a company (defaults if none). Used by the PDF
/// renderer; rebuilds when the stored template changes are re-fetched.
final contractTemplateProvider =
    FutureProvider.family<ContractTemplate, String>((ref, companyId) {
  return ref.watch(templateRepositoryProvider).fetch(companyId);
});
