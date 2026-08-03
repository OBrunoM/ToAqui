import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Future<String> signInAnonymously() async {
    // On web, `currentUser` can still be null right after `initializeApp`
    // even when a persisted anonymous session exists (IndexedDB restore
    // hasn't resolved yet). Awaiting the resolved auth state avoids
    // spuriously creating a brand-new anonymous account and losing data
    // for returning web users.
    final existing = await _auth.authStateChanges().first;
    if (existing != null) return existing.uid;

    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }
}
