import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/screens/contacts_screen.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/repositories/contact_repository.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: ContactsScreen()),
    );
  }

  testWidgets('adding a contact shows a dialog with the invite code', (tester) async {
    await tester.pumpWidget(buildApp(FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Vovó');
    await tester.pump();
    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Envie esse código'), findsOneWidget);
    expect(find.byKey(const Key('invite-code-text')), findsOneWidget);
  });

  testWidgets('Pendentes tab shows only contacts without a linked uid', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = ContactRepository(firestore, 'owner-uid');
    final linked = ContactModel(name: 'Mãe', relationship: 'Família');
    await repo.addContact(linked);
    await repo.linkContact(linked.id, 'family-uid');
    await repo.addContact(ContactModel(name: 'Convidado', relationship: 'Amigo'));

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsOneWidget);
    expect(find.text('Convidado'), findsOneWidget);

    await tester.tap(find.text('Pendentes'));
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsNothing);
    expect(find.text('Convidado'), findsOneWidget);
  });

  testWidgets('autoOpenAdd opens the add-contact sheet on first frame', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: ContactsScreen(autoOpenAdd: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contact-name-field')), findsOneWidget);
  });

  testWidgets('shows an invite footer card below the contact list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = ContactRepository(firestore, 'owner-uid');
    await repo.addContact(ContactModel(name: 'Mãe', relationship: 'Mãe'));

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Convide novos contatos'), findsOneWidget);
  });
}
