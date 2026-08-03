import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/widgets/emergency_button.dart';

// A top-level (and therefore tear-off-constant) no-op location fetcher, so
// it can be passed to a `const EmergencyButton(...)`.
Future<Position?> _fetchNoLocation() async => null;

void main() {
  Future<void> seedLinkedContact(FakeFirebaseFirestore firestore) async {
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await contacts.addContact(contact);
    await contacts.linkContact(contact.id, 'family-uid');
  }

  Widget buildApp(
    FakeFirebaseFirestore firestore, {
    LocationFetcher? fetchLocation,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
        ...extraOverrides,
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

  // Drives a long-press gesture the same way a real hold works: press down,
  // wait past the recognizer's internal win-timer (kLongPressTimeout, the
  // point at which the LongPressGestureRecognizer locks out competing
  // recognizers like a ScrollView's drag recognizer), optionally move the
  // pointer a little (simulating an unsteady hand), then wait out the rest
  // of the button's own hold animation before releasing.
  Future<TestGesture> pressAndHoldPastArenaWin(
    WidgetTester tester, {
    Offset moveBy = Offset.zero,
  }) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
    if (moveBy != Offset.zero) {
      await gesture.moveBy(moveBy);
      await tester.pump();
    }
    return gesture;
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

    await pressAndHoldPastArenaWin(tester);
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

    await pressAndHoldPastArenaWin(tester);
    await tester.pumpAndSettle();

    final data = (await firestore.collection('emergencies').get()).docs.single.data();
    expect(data['latitude'], -23.55);
    expect(data['longitude'], -46.63);
  });

  testWidgets('with no linked contacts, holding shows a warning and records nothing', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await pressAndHoldPastArenaWin(tester);
    await tester.pumpAndSettle();

    expect((await firestore.collection('emergencies').get()).docs, isEmpty);
    expect(find.textContaining('não tem familiares vinculados'), findsOneWidget);
  });

  testWidgets(
    'the hold survives a small pointer move inside a SingleChildScrollView ancestor',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await seedLinkedContact(firestore);

      // Wrap the button in a real SingleChildScrollView, mirroring how it is
      // hosted on the real Home screen, so there is an actual competing
      // vertical-drag recognizer in the gesture arena. The hold duration is
      // deliberately longer than kLongPressTimeout so the pointer move below
      // happens *after* the long-press recognizer has already won the arena
      // (locking out the scroll view) but *before* the button's own hold
      // animation completes — proving the move doesn't cancel the hold. A
      // plain TapGestureRecognizer (the pre-fix implementation) would have
      // lost the arena to the ScrollView the instant this move exceeded
      // touch-slop, regardless of timing.
      const holdDuration = Duration(milliseconds: 700);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUidProvider.overrideWithValue('owner-uid'),
            firestoreProvider.overrideWithValue(firestore),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: const EmergencyButton(
                  holdDuration: holdDuration,
                  fetchLocation: _fetchNoLocation,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await pressAndHoldPastArenaWin(tester, moveBy: const Offset(0, 30));
      await tester.pumpAndSettle();

      final docs = (await firestore.collection('emergencies').get()).docs;
      expect(docs, hasLength(1));
    },
  );

  testWidgets(
    'a fetchLocation that throws still records an emergency without coordinates',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await seedLinkedContact(firestore);
      await tester.pumpWidget(buildApp(
        firestore,
        fetchLocation: () async => throw StateError('boom'),
      ));
      await tester.pumpAndSettle();

      await pressAndHoldPastArenaWin(tester);
      await tester.pumpAndSettle();

      final docs = (await firestore.collection('emergencies').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['ownerUid'], 'owner-uid');
      expect(docs.single.data().containsKey('latitude'), isFalse);
      expect(docs.single.data().containsKey('longitude'), isFalse);
    },
  );

  testWidgets(
    'an errored contacts stream fails open: the send is not blocked',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      // Note: no linked contact is seeded — the stream override below
      // supplies an error state directly rather than relying on the fake
      // Firestore stream itself erroring.
      await tester.pumpWidget(
        buildApp(
          firestore,
          extraOverrides: [
            contactsStreamProvider.overrideWith(
              (ref) => Stream<List<ContactModel>>.error(Exception('offline')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await pressAndHoldPastArenaWin(tester);
      await tester.pumpAndSettle();

      final docs = (await firestore.collection('emergencies').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['ownerUid'], 'owner-uid');
      expect(find.textContaining('não tem familiares vinculados'), findsNothing);
    },
  );

  testWidgets(
    'a resolved, genuinely empty contacts list still shows the warning and records nothing',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        buildApp(
          firestore,
          extraOverrides: [
            contactsStreamProvider.overrideWith(
              (ref) => Stream<List<ContactModel>>.value(const []),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await pressAndHoldPastArenaWin(tester);
      await tester.pumpAndSettle();

      expect((await firestore.collection('emergencies').get()).docs, isEmpty);
      expect(find.textContaining('não tem familiares vinculados'), findsOneWidget);
    },
  );
}