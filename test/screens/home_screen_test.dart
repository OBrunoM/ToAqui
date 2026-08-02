import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/arrival_repository.dart';
import 'package:to_aqui/repositories/location_repository.dart';
import 'package:to_aqui/screens/home_screen.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('shows the empty state when there are no arrivals', (tester) async {
    await tester.pumpWidget(buildApp(FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma chegada registrada ainda'), findsWidgets);
  });

  testWidgets('shows the most recent arrival and real stat counts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final locationRepo = LocationRepository(firestore, 'owner-uid');
    await locationRepo.addLocation(
      LocationModel(name: 'Trabalho', latitude: 0, longitude: 0, radius: 100, message: 'x', icon: '🏢'),
    );
    final location = (await locationRepo.watchLocations().first).single;
    await ArrivalRepository(firestore).recordArrival(
      ownerUid: 'owner-uid',
      locationId: location.id,
      message: 'Cheguei!',
    );

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsWidgets);
    expect(find.text('Locais ativos'), findsOneWidget);
    expect(find.text('Chegadas este mês'), findsOneWidget);
  });

  testWidgets('tapping "Já tenho um convite" navigates to /join', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/join', builder: (context, state) => const Scaffold(body: Text('Join Screen'))),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Já tenho um convite'));
    await tester.tap(find.text('Já tenho um convite'));
    await tester.pumpAndSettle();

    expect(find.text('Join Screen'), findsOneWidget);
  });
}
