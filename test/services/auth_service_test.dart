import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/services/auth_service.dart';

void main() {
  test('signInAnonymously returns the signed-in uid', () async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final service = AuthService(mockAuth);

    final uid = await service.signInAnonymously();

    expect(uid, isNotEmpty);
    expect(mockAuth.currentUser, isNotNull);
    expect(mockAuth.currentUser!.uid, uid);
  });

  test('signInAnonymously is a no-op if already signed in', () async {
    final mockAuth = MockFirebaseAuth(signedIn: true);
    final service = AuthService(mockAuth);
    final existingUid = mockAuth.currentUser!.uid;

    final uid = await service.signInAnonymously();

    expect(uid, existingUid);
  });
}
