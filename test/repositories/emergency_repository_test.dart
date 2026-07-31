import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/repositories/emergency_repository.dart';

void main() {
  test('recordEmergency writes ownerUid, coordinates, and createdAt', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmergencyRepository(firestore);

    await repo.recordEmergency(ownerUid: 'owner-uid', latitude: -23.55, longitude: -46.63);

    final snapshot = await firestore.collection('emergencies').get();
    expect(snapshot.docs, hasLength(1));
    final data = snapshot.docs.single.data();
    expect(data['ownerUid'], 'owner-uid');
    expect(data['latitude'], -23.55);
    expect(data['longitude'], -46.63);
    expect(data['createdAt'], isNotNull);
  });

  test('recordEmergency omits coordinates when not provided', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmergencyRepository(firestore);

    await repo.recordEmergency(ownerUid: 'owner-uid');

    final data = (await firestore.collection('emergencies').get()).docs.single.data();
    expect(data.containsKey('latitude'), isFalse);
    expect(data.containsKey('longitude'), isFalse);
  });
}
