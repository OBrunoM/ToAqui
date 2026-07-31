import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/widgets/emergency_button.dart';

void main() {
  Future<void> seedLinkedContact(FakeFirebaseFirestore firestore) async {
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await contacts.addContact(contact);
    await contacts.linkContact(contact.id, 'family-uid');
  }

  Widget buildApp(FakeFirebaseFirestore firestore, {LocationFetcher? fetchLocation}) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EmergencyButton(
            holdDuration: const Duration(milliseconds: 50),
            fetchLocation: fetchLocation ?? () async => null,
          ),
        ),
      ),
    );
  }

  testWidgets('releasing before the hold completes does not record an emergency', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedLinkedContact(firestore);
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 10));
    await gesture.up();
    await tester.pumpAndSettle();

    expect((await firestore.collection('emergencies').get()).docs, isEmpty);
  });

  testWidgets('holding for the full duration records an emergency without location', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedLinkedContact(firestore);
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    final docs = (await firestore.collection('emergencies').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['ownerUid'], 'owner-uid');
    expect(docs.single.data().containsKey('latitude'), isFalse);
    expect(find.text('Alerta enviado'), findsOneWidget);
  });

  testWidgets('holding with a location fetcher that returns a position includes coordinates', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedLinkedContact(firestore);
    await tester.pumpWidget(buildApp(
      firestore,
      fetchLocation: () async => Position(
        latitude: -23.55,
        longitude: -46.63,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    final data = (await firestore.collection('emergencies').get()).docs.single.data();
    expect(data['latitude'], -23.55);
    expect(data['longitude'], -46.63);
  });

  testWidgets('with no linked contacts, holding shows a warning and records nothing', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect((await firestore.collection('emergencies').get()).docs, isEmpty);
    expect(find.textContaining('não tem familiares vinculados'), findsOneWidget);
  });
}
