import 'package:firebase_auth/firebase_auth.dart';

/// Handles Firebase Auth sign-in/out. Account provisioning (companies, admins,
/// agents) is done by Super Admins via AdminRepository, not self-registration.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();
}
