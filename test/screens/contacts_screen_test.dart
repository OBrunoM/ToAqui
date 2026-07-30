import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/screens/contacts_screen.dart';

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
}
