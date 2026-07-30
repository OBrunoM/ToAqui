import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/contact_repository.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';

export 'firestore_provider.dart' show firestoreProvider;

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(firestoreProvider), ref.watch(currentUidProvider));
});

final contactsStreamProvider = StreamProvider((ref) {
  return ref.watch(contactRepositoryProvider).watchContacts();
});
