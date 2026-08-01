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

  test('watchArrivals only returns arrivals for the given owner', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ArrivalRepository(firestore);

    await repo.recordArrival(ownerUid: 'owner-uid', locationId: 'loc-1', message: 'Cheguei em casa!');
    await repo.recordArrival(ownerUid: 'owner-uid', locationId: 'loc-2', message: 'Cheguei no trabalho!');
    await repo.recordArrival(ownerUid: 'other-uid', locationId: 'loc-3', message: 'Não deveria aparecer');

    final result = await repo.watchArrivals('owner-uid').first;

    expect(result, hasLength(2));
    expect(result.map((a) => a.locationId), containsAll(['loc-1', 'loc-2']));
    expect(result.every((a) => a.locationId != 'loc-3'), isTrue);
  });
}
