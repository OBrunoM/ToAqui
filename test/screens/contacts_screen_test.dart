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

    // Find 'Mãe' and 'Amor' in ListTile titles (not subtitles)
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Mãe'),
      ),
      findsWidgets, // Both title and subtitle have 'Mãe'
    );
    expect(find.text('Amor'), findsWidgets); // Title and subtitle

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // After deleting first contact, no more 'Mãe' in ListTiles
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Mãe'),
      ),
      findsNothing,
    );
    // 'Amor' should still exist in a ListTile
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Amor'),
      ),
      findsWidgets,
    );
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
