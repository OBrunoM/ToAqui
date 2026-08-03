import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactRepository {
  ContactRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('contacts');

  Stream<List<ContactModel>> watchContacts() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ContactModel.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<void> addContact(ContactModel contact) {
    return _collection.doc(contact.id).set(contact.toMap());
  }

  Future<void> linkContact(String contactId, String linkedUid) {
    return _collection.doc(contactId).update({'linkedUid': linkedUid});
  }

  Future<void> updateInviteCode(String contactId, String code) {
    return _collection.doc(contactId).update({'inviteCode': code});
  }

  Future<void> deleteContact(String id) {
    return _collection.doc(id).delete();
  }
}
