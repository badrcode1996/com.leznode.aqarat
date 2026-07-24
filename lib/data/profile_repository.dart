import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';

/// Lets a signed-in user edit their OWN profile. Unlike AdminRepository (super
/// admin only), every write here targets the caller's own `users/{uid}` doc and
/// their own Storage path, which is all the security rules permit them.
class ProfileRepository {
  ProfileRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  /// Uploads a new profile photo and records its URL on the user's own doc.
  ///
  /// The object sits at `user_photos/{uid}` — one per user, overwritten on each
  /// change, so an old photo never lingers. The download URL is returned so the
  /// caller can refresh the session without a re-read.
  Future<String> uploadPhoto(Uint8List bytes, String contentType) async {
    final ref = FirebaseStorage.instance.ref('user_photos/$_uid');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(_uid).update({'photo_url': url});
    return url;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(firestoreProvider);
  final user = ref.watch(currentUserProvider);
  return ProfileRepository(db, user.uid);
});
