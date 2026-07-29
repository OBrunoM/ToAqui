import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';

class ContactNotifier extends StateNotifier<List<ContactModel>> {
  ContactNotifier() : super([]) {
    _loadMockData();
  }

  void _loadMockData() {
    state = [
      ContactModel(name: 'Mãe', relationship: 'Mãe'),
      ContactModel(name: 'Amor', relationship: 'Parceiro(a)'),
    ];
  }

  void addContact(ContactModel contact) {
    state = [...state, contact];
  }

  void deleteContact(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

final contactProvider = StateNotifierProvider<ContactNotifier, List<ContactModel>>((ref) {
  return ContactNotifier();
});
