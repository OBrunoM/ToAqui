import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Safe to read anywhere: `main()` awaits anonymous sign-in before `runApp`,
/// so `FirebaseAuth.instance.currentUser` is guaranteed non-null by the time
/// any widget builds.
final currentUidProvider = Provider<String>((ref) {
  return FirebaseAuth.instance.currentUser!.uid;
});
