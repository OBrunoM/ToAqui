import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/services/fcm_service.dart';

void main() {
  test('saveToken writes the token under users/{uid}', () async {
    final firestore = FakeFirebaseFirestore();
    final service = FcmService(firestore);

    await service.saveToken(uid: 'owner-uid', token: 'fake-token-123');

    final doc = await firestore.collection('users').doc('owner-uid').get();
    expect(doc.data()!['fcmToken'], 'fake-token-123');
  });
}
