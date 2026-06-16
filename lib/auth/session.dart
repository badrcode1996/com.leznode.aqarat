import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_model.dart';
import '../models/enums.dart';
import 'auth_repository.dart';

/// The authenticated user's tenant context. Single source of truth that every
/// data query depends on — change it and all dependent providers rebuild +
/// dispose, which is what structurally prevents tenant data bleed-through.
class SessionUser {
  const SessionUser({
    required this.uid,
    required this.companyId,
    required this.role,
    required this.displayName,
    required this.phone,
    this.branch = '',
    this.branchAdmin = false,
    this.plan = CompanyPlan.bronze,
  });

  final String uid;
  final String companyId;
  final UserRole role;
  final String displayName;

  /// The company's subscription tier — gates which features are available.
  /// Super admins are treated as [CompanyPlan.gold] (they see everything).
  final CompanyPlan plan;

  /// The signed-in user's own phone (their Global Market contact number).
  final String phone;

  /// The branch (لق) this user belongs to.
  final String branch;

  /// Company admin scoped to their branch (ئادمینی لق) when true.
  final bool branchAdmin;

  String get agentId => uid;

  /// Sees ALL company data: super admin, or a company-wide admin (not branch).
  bool get isCompanyWide =>
      role == UserRole.superAdmin ||
      (role == UserRole.companyAdmin && !branchAdmin);

  /// Company admin limited to their own branch.
  bool get isBranchAdmin => role == UserRole.companyAdmin && branchAdmin;

  /// May edit/delete contracts and receipts. Both company-wide and branch
  /// admins qualify (a branch admin only ever sees their own branch's data).
  /// Plain agents cannot.
  bool get isAdmin => role == UserRole.companyAdmin;
}

// --------------------------------------------------------------------------
// Singletons
// --------------------------------------------------------------------------
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

/// Raw Firebase Auth state (null = signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Resolves the full [SessionUser] for the signed-in account by reading the
/// `users/{uid}` profile and its company. Returns:
///   - null when signed out, OR
///   - null when signed in but no profile yet (needs onboarding).
final sessionProvider = FutureProvider<SessionUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final db = ref.watch(firestoreProvider);
  final userSnap = await db.collection('users').doc(user.uid).get();
  if (!userSnap.exists) return null; // signed in, but not provisioned yet

  final data = userSnap.data()!;
  final role = UserRole.fromWire(data['role'] as String?);

  // Super Admin is identified by their profile document (role == super_admin),
  // NOT by a hardcoded email. This allows any number of super admins, managed
  // as documents in Firestore. They have no company.
  if (role == UserRole.superAdmin) {
    return SessionUser(
      uid: user.uid,
      companyId: '',
      role: UserRole.superAdmin,
      displayName: data['display_name'] as String? ?? user.email ?? '',
      phone: '',
      plan: CompanyPlan.gold, // sees everything
    );
  }

  // Resolve the company's subscription plan (one read) so feature gates can be
  // checked synchronously off the session everywhere in the UI.
  final companyId = data['company_id'] as String? ?? '';
  var plan = CompanyPlan.bronze;
  if (companyId.isNotEmpty) {
    final companySnap =
        await db.collection('companies').doc(companyId).get();
    plan = CompanyPlan.fromWire(companySnap.data()?['plan'] as String?);
  }

  return SessionUser(
    uid: user.uid,
    companyId: companyId,
    role: role,
    displayName: data['display_name'] as String? ?? user.email ?? '',
    phone: data['phone'] as String? ?? '',
    branch: data['branch'] as String? ?? '',
    branchAdmin: data['branch_admin'] as bool? ?? false,
    plan: plan,
  );
});

/// The signed-in user's company (for the contract PDF header, etc.).
final currentCompanyProvider = FutureProvider<Company?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user.companyId.isEmpty) return null;
  final snap =
      await ref.watch(firestoreProvider).collection('companies').doc(user.companyId).get();
  return snap.exists ? Company.fromJson(snap.id, snap.data()!) : null;
});

/// Synchronous access for screens shown only when a session exists.
/// Throws if read before the session resolves — by design.
final currentUserProvider = Provider<SessionUser>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) {
    throw StateError('No active session — user must be authenticated first.');
  }
  return session;
});
