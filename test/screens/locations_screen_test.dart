import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/location_repository.dart';
import 'package:to_aqui/screens/locations_screen.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: LocationsScreen()),
    );
  }

  testWidgets('Ativos tab shows only active locations, Inativos only inactive ones', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = LocationRepository(firestore, 'owner-uid');
    await repo.addLocation(
      LocationModel(name: 'Trabalho', latitude: 0, longitude: 0, radius: 50, message: 'x'),
    );
    await repo.addLocation(LocationModel(
      name: 'Faculdade',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'x',
      isActive: false,
    ));

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('Faculdade'), findsNothing);

    await tester.tap(find.text('Inativos'));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsNothing);
    expect(find.text('Faculdade'), findsOneWidget);
  });

  testWidgets('Simular chegada from the overflow menu records an arrival', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = LocationRepository(firestore, 'owner-uid');
    await repo.addLocation(
      LocationModel(name: 'Casa', latitude: 0, longitude: 0, radius: 50, message: 'Cheguei em casa!'),
    );

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular chegada'));
    await tester.pumpAndSettle();

    final docs = (await firestore.collection('arrivals').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['message'], 'Cheguei em casa!');
  });
}
