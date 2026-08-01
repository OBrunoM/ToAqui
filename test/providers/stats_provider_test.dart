import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/providers/arrival_provider.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/providers/location_provider.dart';
import 'package:to_aqui/providers/stats_provider.dart';
import 'package:to_aqui/repositories/arrival_repository.dart';

void main() {
  ProviderContainer buildContainer(FakeFirebaseFirestore firestore) {
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(firestore),
      currentUidProvider.overrideWithValue('owner-uid'),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('activeLocationsCountProvider counts only active locations', () async {
    final firestore = FakeFirebaseFirestore();
    final container = buildContainer(firestore);

    await container.read(locationRepositoryProvider).addLocation(
          LocationModel(name: 'Casa', latitude: 0, longitude: 0, radius: 50, message: 'x'),
        );
    await container.read(locationRepositoryProvider).addLocation(
          LocationModel(
            name: 'Inativo',
            latitude: 0,
            longitude: 0,
            radius: 50,
            message: 'x',
            isActive: false,
          ),
        );
    await container.read(locationsStreamProvider.future);

    expect(container.read(activeLocationsCountProvider), 1);
  });

  test('linkedContactsCountProvider counts only linked contacts', () async {
    final firestore = FakeFirebaseFirestore();
    final container = buildContainer(firestore);

    final repo = container.read(contactRepositoryProvider);
    final linked = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(linked);
    await repo.linkContact(linked.id, 'family-uid');
    await repo.addContact(ContactModel(name: 'Pendente', relationship: 'Amigo'));
    await container.read(contactsStreamProvider.future);

    expect(container.read(linkedContactsCountProvider), 1);
  });

  test('arrivalsThisMonthCountProvider counts arrivals from the current month', () async {
    final firestore = FakeFirebaseFirestore();
    final container = buildContainer(firestore);

    await ArrivalRepository(firestore).recordArrival(
      ownerUid: 'owner-uid',
      locationId: 'loc-1',
      message: 'x',
    );
    await container.read(arrivalsStreamProvider.future);

    expect(container.read(arrivalsThisMonthCountProvider), 1);
  });
}
