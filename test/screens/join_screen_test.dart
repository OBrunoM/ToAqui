import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/repositories/invite_repository.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/screens/join_screen.dart';

/// A [FirebaseFirestore] double that throws on every method call, used to
/// simulate an offline/`permission-denied`-style failure from
/// `redeemInvite` without depending on a real backend.
class _ThrowingFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw Exception('simulated network failure');
  }
}

/// Wraps a real [FirebaseFirestore] but makes reads on the `invites`
/// collection wait for an artificial delay before resolving. `fake_cloud_firestore`
/// otherwise resolves every read/write within the same microtask, which makes
/// it impossible to reliably observe an "in flight" UI state (spinner /
/// disabled button) in a widget test. The delay is a real `Future.delayed`,
/// so the test controls it by advancing the fake test clock with
/// `tester.pump(duration)` rather than relying on timing luck.
class _DelayedInvitesFirestore implements FirebaseFirestore {
  _DelayedInvitesFirestore(this._real);
  final FirebaseFirestore _real;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    final real = _real.collection(collectionPath);
    if (collectionPath != 'invites') return real;
    return _DelayedCollection(real);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// A test-only pass-through wrapper is the standard way to inject a
// controllable delay into an otherwise-instant fake Firestore call; there is
// no supported public API for this in `fake_cloud_firestore`.
// ignore: subtype_of_sealed_class
class _DelayedCollection implements CollectionReference<Map<String, dynamic>> {
  _DelayedCollection(this._real);
  final CollectionReference<Map<String, dynamic>> _real;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _DelayedDoc(_real.doc(path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// ignore: subtype_of_sealed_class
class _DelayedDoc implements DocumentReference<Map<String, dynamic>> {
  _DelayedDoc(this._real);
  final DocumentReference<Map<String, dynamic>> _real;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _real.get(options);
  }

  @override
  Future<void> update(Map<Object, Object?> data) => _real.update(data);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('redeeming a valid code shows a success message', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Vovó', relationship: 'Avó');
    await contacts.addContact(contact);
    final code = await InviteRepository(firestore).createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), code);
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Conectado'), findsOneWidget);
  });

  testWidgets('an unknown code shows a not-found error', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), 'ZZZZZZ');
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('não encontrado'), findsOneWidget);
  });

  testWidgets('an already-used code shows an already-used error', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Vovó', relationship: 'Avó');
    await contacts.addContact(contact);
    final code = await InviteRepository(firestore).createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
    );
    await InviteRepository(firestore).redeemInvite(code: code, redeemerUid: 'first-redeemer');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), code);
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('já foi usado'), findsOneWidget);
  });

  testWidgets('an expired code shows an expired error', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Vovó', relationship: 'Avó');
    await contacts.addContact(contact);
    final code = await InviteRepository(firestore).createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
      now: DateTime.now().subtract(const Duration(hours: 25)),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), code);
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('expirou'), findsOneWidget);
  });

  testWidgets(
      'the submit button disables and shows a spinner while a redemption is '
      'in flight, guarding against a double-tap firing two redemptions',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Vovó', relationship: 'Avó');
    await contacts.addContact(contact);
    final code = await InviteRepository(firestore).createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(_DelayedInvitesFirestore(firestore)),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), code);
    await tester.tap(find.byKey(const Key('join-submit-button')));
    // Pump one frame without advancing the clock: the artificial 200ms
    // delay on the invite read hasn't elapsed yet, so the redemption is
    // still genuinely in flight here.
    await tester.pump();

    final button =
        tester.widget<FilledButton>(find.byKey(const Key('join-submit-button')));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The button is disabled, so this tap must be a no-op: it must not
    // trigger a second, concurrent redemption of the same code.
    await tester.tap(find.byKey(const Key('join-submit-button')));
    // Advance the clock past the artificial delay and let everything settle.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.textContaining('Conectado'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    final invite = await firestore.collection('invites').doc(code).get();
    expect(invite.data()!['used'], isTrue);
  });

  testWidgets('an exception while redeeming shows a connection error message',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(_ThrowingFirestore()),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), 'ABC123');
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Não foi possível conectar'), findsOneWidget);

    // The submit button must be re-enabled after the failure so the user
    // can retry.
    final button =
        tester.widget<FilledButton>(find.byKey(const Key('join-submit-button')));
    expect(button.onPressed, isNotNull);
  });
}
