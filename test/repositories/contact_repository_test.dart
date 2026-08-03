import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/repositories/contact_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ContactRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = ContactRepository(firestore, 'owner-uid');
  });

  test('addContact then watchContacts returns it with linkedUid null', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(contact);

    final result = await repo.watchContacts().first;
    expect(result.single.name, 'Mãe');
    expect(result.single.linkedUid, isNull);
  });

  test('linkContact sets linkedUid on the matching document', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await repo.addContact(contact);

    await repo.linkContact(contact.id, 'family-member-uid');

    final result = await repo.watchContacts().first;
    expect(result.single.linkedUid, 'family-member-uid');
  });

  test('updateInviteCode sets inviteCode on the matching document', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(contact);

    await repo.updateInviteCode(contact.id, 'ABC123');

    final result = await repo.watchContacts().first;
    expect(result.single.inviteCode, 'ABC123');
  });

  test('deleteContact removes the document', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(contact);

    await repo.deleteContact(contact.id);

    expect(await repo.watchContacts().first, isEmpty);
  });
}
