import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../models/lawyer_model.dart';

/// Repository for the `lawyers` collection. Every read/write is scoped to the
/// current company. Admin-only restriction is enforced in the UI (consistent
/// with the app's branch/agent narrowing); the tenant boundary lives in the
/// Firestore rules.
class LawyerRepository {
  LawyerRepository(this._db, this._user);

  final FirebaseFirestore _db;
  final SessionUser _user;

  CollectionReference<Map<String, dynamic>> get _lawyers =>
      _db.collection('lawyers');

  /// Company lawyers, newest first.
  Stream<List<Lawyer>> watchLawyers() {
    return _lawyers
        .where('company_id', isEqualTo: _user.companyId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Lawyer.fromJson(d.id, d.data())).toList());
  }

  /// Uploads a lawyer photo and returns its download URL.
  Future<String> _uploadPhoto(
    String lawyerId,
    Uint8List bytes,
    String contentType,
  ) async {
    final ref = FirebaseStorage.instance
        .ref('lawyer_photos/${_user.companyId}/$lawyerId');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Creates a lawyer, optionally with a photo.
  Future<void> addLawyer({
    required String name,
    required String phone,
    Uint8List? photoBytes,
    String photoContentType = 'image/jpeg',
  }) async {
    final ref = _lawyers.doc();
    final photoUrl = photoBytes == null
        ? ''
        : await _uploadPhoto(ref.id, photoBytes, photoContentType);
    final lawyer = Lawyer(
      id: ref.id,
      companyId: _user.companyId,
      name: name.trim(),
      phone: phone.trim(),
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
    );
    await ref.set(lawyer.toJson());
  }

  /// Edits a lawyer. A new [photoBytes] replaces the existing photo; pass null
  /// to keep the current one.
  Future<void> updateLawyer(
    Lawyer lawyer, {
    required String name,
    required String phone,
    Uint8List? photoBytes,
    String photoContentType = 'image/jpeg',
  }) async {
    if (lawyer.companyId != _user.companyId) {
      throw StateError('Cross-tenant write blocked.');
    }
    final photoUrl = photoBytes == null
        ? lawyer.photoUrl
        : await _uploadPhoto(lawyer.id, photoBytes, photoContentType);
    await _lawyers.doc(lawyer.id).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'photo_url': photoUrl,
    });
  }

  /// Deletes a lawyer (and its photo, if any).
  Future<void> deleteLawyer(Lawyer lawyer) async {
    if (lawyer.companyId != _user.companyId) {
      throw StateError('Cross-tenant write blocked.');
    }
    await _lawyers.doc(lawyer.id).delete();
    if (lawyer.photoUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance
            .ref('lawyer_photos/${_user.companyId}/${lawyer.id}')
            .delete();
      } catch (_) {
        // Photo already gone / never existed — ignore.
      }
    }
  }
}

final lawyerRepositoryProvider = Provider<LawyerRepository>((ref) {
  return LawyerRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUserProvider),
  );
});

final lawyersStreamProvider = StreamProvider<List<Lawyer>>((ref) {
  return ref.watch(lawyerRepositoryProvider).watchLawyers();
});
