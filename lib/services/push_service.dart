import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../ui/notifications/notifications_screen.dart';

/// Web push additionally needs a VAPID key pair (Firebase console → Cloud
/// Messaging → Web configuration) and a `firebase-messaging-sw.js` service
/// worker in web/. Until both exist, web silently skips registration — the
/// in-app notification centre still works there, it just doesn't ring.
const String kWebVapidKey = '';

/// Lets a notification tap push a route without a BuildContext. Wired to
/// MaterialApp in main.dart.
final navigatorKey = GlobalKey<NavigatorState>();

/// Registers this device for push and routes taps to the notification centre.
///
/// Tokens live on `users/{uid}.fcm_tokens` as an array — a user may be signed
/// in on a phone and the web at once, and both should ring. The token is
/// removed again on sign-out so a shared device stops receiving another
/// company's alerts.
class PushService {
  PushService(this._db, this._user);

  final FirebaseFirestore _db;
  final SessionUser _user;

  static StreamSubscription<String>? _refreshSub;
  static StreamSubscription<RemoteMessage>? _openedSub;

  /// The token this process registered, kept so [stop] can remove exactly it
  /// (deleteToken() would also kill delivery for a user who signs back in).
  static String? _current;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_user.uid);

  /// Idempotent: safe to call on every app start / session change.
  ///
  /// Everything is best-effort. Push is a convenience on top of the in-app
  /// centre, so a device that refuses permission, has no Play Services, or is
  /// an emulator must degrade quietly rather than break the dashboard.
  Future<void> start() async {
    if (kIsWeb && kWebVapidKey.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS + Android 13 both gate notifications behind a runtime prompt.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken(
        vapidKey: kIsWeb ? kWebVapidKey : null,
      );
      if (token != null) await _save(token);

      // Tokens rotate (app restore, cache clear); keep the stored set current.
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_save);

      // Tapping a tray notification while the app is running in the background.
      await _openedSub?.cancel();
      _openedSub =
          FirebaseMessaging.onMessageOpenedApp.listen((_) => _openCentre());

      // …and the same tap when it cold-started the app.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _openCentre();
    } catch (e) {
      debugPrint('Push registration unavailable on this device: $e');
    }
  }

  /// Drops this device's token. Called before sign-out — after it, the user
  /// doc is no longer writable by this account.
  Future<void> stop() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    await _openedSub?.cancel();
    _openedSub = null;
    final token = _current;
    _current = null;
    if (token == null) return;
    try {
      await _userDoc.update({
        'fcm_tokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('Could not remove push token: $e');
    }
  }

  Future<void> _save(String token) async {
    _current = token;
    try {
      await _userDoc.update({
        'fcm_tokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      debugPrint('Could not store push token: $e');
    }
  }

  /// A push always concerns something in the centre, so the tap lands there
  /// rather than guessing at a contract that may no longer be readable.
  static void _openCentre() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute<void>(
      builder: (_) => const NotificationsScreen(),
    ));
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    ref.watch(firestoreProvider),
    ref.watch(currentUserProvider),
  );
});
