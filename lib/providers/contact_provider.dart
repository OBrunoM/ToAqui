import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/contact_repository.dart';
import 'auth_provider.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(FirebaseFirestore.instance, ref.watch(currentUidProvider));
});

final contactsStreamProvider = StreamProvider((ref) {
  return ref.watch(contactRepositoryProvider).watchContacts();
});
