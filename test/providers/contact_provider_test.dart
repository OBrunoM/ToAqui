import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/providers/contact_provider.dart';

void main() {
  test('starts with the mock contacts (Mãe and Amor)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final contacts = container.read(contactProvider);

    expect(contacts.length, 2);
    expect(contacts.map((c) => c.name), containsAll(['Mãe', 'Amor']));
  });

  test('addContact appends a new contact', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(contactProvider.notifier).addContact(
          ContactModel(name: 'Vovó', relationship: 'Avó'),
        );

    final contacts = container.read(contactProvider);
    expect(contacts.length, 3);
    expect(contacts.last.name, 'Vovó');
    expect(contacts.last.relationship, 'Avó');
  });

  test('deleteContact removes only the contact with the matching id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final firstId = container.read(contactProvider).first.id;
    container.read(contactProvider.notifier).deleteContact(firstId);

    final contacts = container.read(contactProvider);
    expect(contacts.length, 1);
    expect(contacts.any((c) => c.id == firstId), isFalse);
  });
}
