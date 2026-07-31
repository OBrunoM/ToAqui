import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/repositories/location_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LocationRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = LocationRepository(firestore, 'owner-uid');
  });

  test('watchLocations emits an empty list, then the added location', () async {
    expect(await repo.watchLocations().first, isEmpty);

    final location = LocationModel(
      name: 'Trabalho',
      latitude: -23.55,
      longitude: -46.63,
      radius: 100,
      message: 'Cheguei!',
    );
    await repo.addLocation(location);

    final result = await repo.watchLocations().first;
    expect(result, hasLength(1));
    expect(result.first.name, 'Trabalho');
  });

  test('toggleLocation flips isActive on the matching document', () async {
    final location = LocationModel(
      name: 'Casa',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'Cheguei em casa!',
      isActive: true,
    );
    await repo.addLocation(location);

    await repo.toggleLocation(location.id, false);

    final result = await repo.watchLocations().first;
    expect(result.single.isActive, isFalse);
  });

  test('deleteLocation removes the document', () async {
    final location = LocationModel(
      name: 'Casa',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'Cheguei em casa!',
    );
    await repo.addLocation(location);

    await repo.deleteLocation(location.id);

    expect(await repo.watchLocations().first, isEmpty);
  });

  test('scopes documents under users/{uid}/locations, not other users', () async {
    final otherRepo = LocationRepository(firestore, 'other-uid');
    await otherRepo.addLocation(LocationModel(
      name: 'Não deveria aparecer',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'x',
    ));

    expect(await repo.watchLocations().first, isEmpty);
  });
}
