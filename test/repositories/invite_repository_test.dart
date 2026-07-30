import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/repositories/invite_repository.dart';
import 'package:to_aqui/models/contact_model.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late InviteRepository invites;
  late ContactRepository contacts;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    invites = InviteRepository(firestore);
    contacts = ContactRepository(firestore, 'owner-uid');
  });

  test('createInvite generates a 6-character code from the safe alphabet', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await contacts.addContact(contact);

    final code = await invites.createInvite(ownerUid: 'owner-uid', contactId: contact.id);

    expect(code, hasLength(6));
    expect(code, matches(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$')));
  });

  test('redeemInvite links the contact and marks the invite used', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await contacts.addContact(contact);
    final code = await invites.createInvite(ownerUid: 'owner-uid', contactId: contact.id);

    final result = await invites.redeemInvite(code: code, redeemerUid: 'family-uid');

    expect(result, isA<InviteRedeemSuccess>());
    final linked = await contacts.watchContacts().first;
    expect(linked.single.linkedUid, 'family-uid');
  });

  test('redeemInvite fails for an unknown code', () async {
    final result = await invites.redeemInvite(code: 'ZZZZZZ', redeemerUid: 'family-uid');
    expect(result, isA<InviteRedeemFailure>());
    expect((result as InviteRedeemFailure).reason, InviteFailureReason.notFound);
  });

  test('redeemInvite fails if the code was already used', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await contacts.addContact(contact);
    final code = await invites.createInvite(ownerUid: 'owner-uid', contactId: contact.id);
    await invites.redeemInvite(code: code, redeemerUid: 'first-redeemer');

    final result = await invites.redeemInvite(code: code, redeemerUid: 'second-redeemer');

    expect(result, isA<InviteRedeemFailure>());
    expect((result as InviteRedeemFailure).reason, InviteFailureReason.alreadyUsed);
  });

  test('redeemInvite fails if the code has expired', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await contacts.addContact(contact);
    final code = await invites.createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
      now: DateTime.now().subtract(const Duration(hours: 25)),
    );

    final result = await invites.redeemInvite(code: code, redeemerUid: 'family-uid');

    expect(result, isA<InviteRedeemFailure>());
    expect((result as InviteRedeemFailure).reason, InviteFailureReason.expired);
  });
}
