import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/invite_repository.dart';
import 'package:to_aqui/widgets/add_contact_sheet.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                final code = await showAddContactSheet(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('code:${code ?? ''}')),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('saving a contact generates and returns an invite code', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(buildApp(firestore));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Vovó');
    await tester.pump();
    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('code:'), findsOneWidget);
    final snackBarText = tester.widget<Text>(find.textContaining('code:')).data!;
    final code = snackBarText.substring('code:'.length);
    expect(code, hasLength(6));

    final invites = InviteRepository(firestore);
    final result = await invites.redeemInvite(code: code, redeemerUid: 'family-uid');
    expect(result, isA<InviteRedeemSuccess>());
  });
}
