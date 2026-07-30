import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Future<String> signInAnonymously() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }
}
