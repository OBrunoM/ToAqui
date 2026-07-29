import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/screens/contacts_screen.dart';

void main() {
  Widget buildApp() {
    return const ProviderScope(
      child: MaterialApp(home: ContactsScreen()),
    );
  }

  testWidgets('lists mock contacts and deletes one on tap', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsOneWidget);
    expect(find.text('Amor'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsNothing);
    expect(find.text('Amor'), findsOneWidget);
  });

  testWidgets('shows the empty state after deleting every contact', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ContactsScreen));
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(contactProvider.notifier);
    for (final contact in List.of(container.read(contactProvider))) {
      notifier.deleteContact(contact.id);
    }
    await tester.pumpAndSettle();

    expect(find.text('Sua família ainda não está por aqui'), findsOneWidget);
  });
}
