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

  testWidgets('an invalid code shows an error', (tester) async {
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
  });
}
