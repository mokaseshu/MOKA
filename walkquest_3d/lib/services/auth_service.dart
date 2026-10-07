import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Auth when available; otherwise a persistent local guest id.
class AuthService {
  AuthService({required this.firebaseEnabled, required SharedPreferences prefs}) : _prefs = prefs;

  final bool firebaseEnabled;
  final SharedPreferences _prefs;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get currentUid {
    if (firebaseEnabled) return _auth.currentUser?.uid;
    return _prefs.getString('wq_local_uid');
  }

  String? get currentEmail => firebaseEnabled ? _auth.currentUser?.email : null;

  Future<String> signInAsGuest() async {
    if (firebaseEnabled) {
      final cred = await _auth.signInAnonymously();
      return cred.user!.uid;
    }
    final uid = 'local_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 20)}';
    await _prefs.setString('wq_local_uid', uid);
    return uid;
  }

  Future<String> signInWithEmail(String email, String password) async {
    _requireFirebase();
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return cred.user!.uid;
  }

  Future<String> signUpWithEmail(String email, String password) async {
    _requireFirebase();
    // Upgrade an anonymous account in place so progress carries over.
    final user = _auth.currentUser;
    final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
    if (user != null && user.isAnonymous) {
      final cred = await user.linkWithCredential(credential);
      return cred.user!.uid;
    }
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    return cred.user!.uid;
  }

  Future<void> signOut() async {
    if (firebaseEnabled) {
      await _auth.signOut();
    } else {
      await _prefs.remove('wq_local_uid');
    }
  }

  void _requireFirebase() {
    if (!firebaseEnabled) {
      throw StateError(
        'Email sign-in needs Firebase. See docs/FIREBASE_SETUP.md, '
        'or continue as a guest.',
      );
    }
  }

  /// 6-char friend code without ambiguous characters.
  static String newFriendCode([math.Random? rnd]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = rnd ?? math.Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
