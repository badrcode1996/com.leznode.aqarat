import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../firebase_options.dart';
import '../models/app_user_model.dart';
import '../models/company_model.dart';
import '../models/contract_model.dart';
import '../models/enums.dart';
import '../models/plan_config_model.dart';
import '../models/receipt_model.dart';

/// Super-Admin provisioning: create companies (with logo), company admins, and
/// agents.
///
/// KEY TRICK: creating an Auth account with `createUserWithEmailAndPassword`
/// signs you IN as that new user, which would kick the Super Admin out. To
/// avoid that, we create accounts on a throwaway SECONDARY [FirebaseApp], then
/// sign it out and delete it. The Super Admin's primary session is never
/// touched. All Firestore/Storage writes go through the PRIMARY app (the Super
/// Admin), so the rules authorize them via isSuperAdmin().
class AdminRepository {
  AdminRepository(this._db);

  final FirebaseFirestore _db;

  /// Creates an Auth user on a throwaway secondary app and returns its uid.
  Future<String> _createAuthUser(String email, String password) async {
    final secondary = await Firebase.initializeApp(
      name: 'provisioner',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await auth.signOut();
      return uid;
    } finally {
      await secondary.delete();
    }
  }

  /// Uploads the company logo to Storage and returns its download URL.
  Future<String> _uploadLogo(
    String companyId,
    Uint8List bytes,
    String contentType,
  ) async {
    final ref = FirebaseStorage.instance.ref('company_logos/$companyId');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Creates a company together with TWO accounts:
  ///   - the Company Admin (oversight + full user access), and
  ///   - one normal User/Agent (creates & sees only their own contracts).
  ///
  /// The English name is slugified into the shared document id (companies +
  /// company_stats + logo path) so the data is readable in the console.
  Future<String> createCompanyWithAccounts({
    required String companyNameKu,
    required String companyNameAr,
    required String companyNameEn,
    required String companyPhone1,
    required String companyPhone2,
    required String companyAddress,
    required Uint8List logoBytes,
    required String logoContentType,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String adminPhone,
    required String userName,
    required String userEmail,
    required String userPassword,
    required String userPhone,
    List<String> branches = const [],
    CompanyPlan plan = CompanyPlan.bronze,
    bool webOnly = false,
  }) async {
    final companyId = Company.slugify(companyNameEn);
    if (companyId.isEmpty) {
      throw Exception('ناوی ئینگلیزی نادروستە — تەنها پیتی ئینگلیزی بەکاربهێنە');
    }

    final companyRef = _db.collection('companies').doc(companyId);
    if ((await companyRef.get()).exists) {
      throw Exception('ئەم ناوە ئینگلیزییە پێشتر بەکارهاتووە: "$companyId"');
    }

    // Create both Auth accounts first (so we fail before writing any docs).
    final adminUid = await _createAuthUser(adminEmail, adminPassword);
    final userUid = await _createAuthUser(userEmail, userPassword);

    // Upload the logo (required).
    final logoUrl = await _uploadLogo(companyId, logoBytes, logoContentType);

    final now = DateTime.now();
    final company = Company(
      id: companyId,
      nameKu: companyNameKu.trim(),
      nameAr: companyNameAr.trim(),
      nameEn: companyNameEn.trim(),
      phone1: companyPhone1.trim(),
      phone2: companyPhone2.trim(),
      address: companyAddress.trim(),
      logoUrl: logoUrl,
      ownerUid: adminUid,
      createdAt: now,
      branches: branches.map((b) => b.trim()).where((b) => b.isNotEmpty).toList(),
      plan: plan,
      webOnly: webOnly,
    );
    final firstBranch = company.branches.isNotEmpty ? company.branches.first : '';
    final admin = AppUser(
      uid: adminUid,
      companyId: companyId,
      role: UserRole.companyAdmin,
      displayName: adminName.trim(),
      email: adminEmail.trim(),
      phone: adminPhone.trim(),
      createdAt: now,
      branch: firstBranch,
      branchAdmin: false, // initial admin is company-wide
    );
    final user = AppUser(
      uid: userUid,
      companyId: companyId,
      role: UserRole.agent,
      displayName: userName.trim(),
      email: userEmail.trim(),
      phone: userPhone.trim(),
      createdAt: now,
      branch: firstBranch,
    );

    final batch = _db.batch();
    batch.set(companyRef, company.toJson());
    batch.set(_db.collection('users').doc(adminUid), admin.toJson());
    batch.set(_db.collection('users').doc(userUid), user.toJson());
    batch.set(_db.collection('company_stats').doc(companyId), {
      'company_id': companyId,
      'contract_count': 0,
      'rent_contract_count': 0,
      'sale_contract_count': 0,
      'total_revenue': 0,
      'collected_revenue': 0,
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return companyId;
  }

  /// The feature set + limits for [companyId]'s current plan.
  Future<PlanFeatures> _planFeaturesFor(String companyId) async {
    final companySnap =
        await _db.collection('companies').doc(companyId).get();
    final plan = CompanyPlan.fromWire(companySnap.data()?['plan'] as String?);
    final cfgSnap = await _db.collection('config').doc('plans').get();
    final config = cfgSnap.exists
        ? PlanConfig.fromJson(cfgSnap.data()!)
        : PlanConfig.defaults;
    return config.forPlan(plan);
  }

  /// Adds a single user (agent or admin) to an existing company.
  Future<String> addUserToCompany({
    required String companyId,
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
    String branch = '',
    bool branchAdmin = false,
  }) async {
    // Enforce the plan's user limit before creating the auth account.
    final features = await _planFeaturesFor(companyId);
    if (!features.unlimitedUsers) {
      final count = (await _db
                  .collection('users')
                  .where('company_id', isEqualTo: companyId)
                  .count()
                  .get())
              .count ??
          0;
      if (count >= features.maxUsers) {
        throw Exception(
            'سنووری یوزەری ئەم پلانە پڕبووە (${features.maxUsers}). بۆ زیادکردن پلانەکە بەرز بکەرەوە.');
      }
    }

    final uid = await _createAuthUser(email, password);
    final profile = AppUser(
      uid: uid,
      companyId: companyId,
      role: role,
      displayName: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
      branch: branch,
      branchAdmin: role == UserRole.companyAdmin && branchAdmin,
    );
    await _db.collection('users').doc(uid).set(profile.toJson());
    return uid;
  }

  /// Replaces the company's branch (لق) list. Enforces the plan's branch limit.
  Future<void> setBranches(String companyId, List<String> branches) async {
    final cleaned =
        branches.map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    final features = await _planFeaturesFor(companyId);
    if (!features.unlimitedBranches && cleaned.length > features.maxBranches) {
      throw Exception(
          'ئەم پلانە تەنها ${features.maxBranches} لقی ڕێگەپێدراوە. پلانەکە بەرز بکەرەوە.');
    }
    await _db
        .collection('companies')
        .doc(companyId)
        .update({'branches': cleaned});
  }

  /// Changes a company's subscription plan (Super Admin only).
  Future<void> setPlan(String companyId, CompanyPlan plan) {
    return _db
        .collection('companies')
        .doc(companyId)
        .update({'plan': plan.wire});
  }

  /// Toggles whether a company is web-only (mobile app blocks login).
  Future<void> setWebOnly(String companyId, bool webOnly) {
    return _db
        .collection('companies')
        .doc(companyId)
        .update({'web_only': webOnly});
  }

  /// Changes a user's password via the `setUserPassword` Cloud Function
  /// (direct password setting requires the Admin SDK). The function verifies
  /// the caller is a Super Admin.
  Future<void> setUserPassword(String uid, String newPassword) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('setUserPassword');
    await callable.call<dynamic>({'uid': uid, 'newPassword': newPassword});
  }

  /// Creates another Super Admin (no company). Only an existing Super Admin can
  /// do this — the rules require isSuperAdmin() to mint a super_admin profile.
  Future<String> createSuperAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final uid = await _createAuthUser(email, password);
    final profile = AppUser(
      uid: uid,
      companyId: '',
      role: UserRole.superAdmin,
      displayName: name.trim(),
      email: email.trim(),
      phone: '',
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set(profile.toJson());
    return uid;
  }

  Stream<List<AppUser>> watchSuperAdmins() {
    return _db
        .collection('users')
        .where('role', isEqualTo: UserRole.superAdmin.wire)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AppUser.fromJson(d.id, d.data())).toList());
  }

  Stream<List<Company>> watchCompanies() {
    return _db
        .collection('companies')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Company.fromJson(d.id, d.data())).toList());
  }

  Stream<List<AppUser>> watchCompanyUsers(String companyId) {
    return _db
        .collection('users')
        .where('company_id', isEqualTo: companyId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AppUser.fromJson(d.id, d.data())).toList());
  }

  /// One-shot fetch of a company's contracts (super admin only — for export).
  Future<List<Contract>> fetchCompanyContracts(String companyId) async {
    final snap = await _db
        .collection('contracts')
        .where('company_id', isEqualTo: companyId)
        .get();
    return snap.docs.map((d) => Contract.fromJson(d.id, d.data())).toList();
  }

  /// One-shot fetch of a company's receipts (super admin only — for export).
  Future<List<Receipt>> fetchCompanyReceipts(String companyId) async {
    final snap = await _db
        .collection('receipts')
        .where('company_id', isEqualTo: companyId)
        .get();
    return snap.docs.map((d) => Receipt.fromJson(d.id, d.data())).toList();
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(firestoreProvider));
});

final companiesProvider = StreamProvider<List<Company>>((ref) {
  return ref.watch(adminRepositoryProvider).watchCompanies();
});

final companyUsersProvider =
    StreamProvider.family<List<AppUser>, String>((ref, companyId) {
  return ref.watch(adminRepositoryProvider).watchCompanyUsers(companyId);
});

final superAdminsProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchSuperAdmins();
});
