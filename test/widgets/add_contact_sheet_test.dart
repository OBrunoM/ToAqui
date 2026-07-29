import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/widgets/add_contact_sheet.dart';

void main() {
  Widget buildApp() {
    return ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAddContactSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('save is disabled until a name is entered, then adds the contact', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(find.byKey(const Key('contact-save-button')));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Vovó');
    await tester.enterText(find.byKey(const Key('contact-relationship-field')), 'Avó');
    await tester.pump();

    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));
    final contacts = ProviderScope.containerOf(context).read(contactProvider);
    expect(contacts.any((c) => c.name == 'Vovó' && c.relationship == 'Avó'), isTrue);
  });

  testWidgets('defaults relationship to "Familiar" when left blank', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Tio Zé');
    await tester.pump();
    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));
    final contacts = ProviderScope.containerOf(context).read(contactProvider);
    expect(contacts.any((c) => c.name == 'Tio Zé' && c.relationship == 'Familiar'), isTrue);
  });
}
