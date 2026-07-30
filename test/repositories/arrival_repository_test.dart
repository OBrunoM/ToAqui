import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/repositories/arrival_repository.dart';

void main() {
  test('recordArrival writes a document under the top-level arrivals collection', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ArrivalRepository(firestore);

    await repo.recordArrival(
      ownerUid: 'owner-uid',
      locationId: 'location-1',
      message: 'Cheguei em segurança!',
    );

    final snapshot = await firestore.collection('arrivals').get();
    expect(snapshot.docs, hasLength(1));
    final data = snapshot.docs.single.data();
    expect(data['ownerUid'], 'owner-uid');
    expect(data['locationId'], 'location-1');
    expect(data['message'], 'Cheguei em segurança!');
    expect(data['createdAt'], isNotNull);
  });
}
