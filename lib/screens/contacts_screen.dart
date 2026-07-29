import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contact_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/add_contact_sheet.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Família e Contatos')),
      body: contacts.isEmpty
          ? EmptyState(
              emoji: '👨‍👩‍👧‍👦',
              title: 'Sua família ainda não está por aqui',
              subtitle: 'Convide quem você ama pra saber que você chegou bem',
              ctaLabel: 'Convidar familiar',
              onCtaPressed: () => showAddContactSheet(context),
            )
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.relationship),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref.read(contactProvider.notifier).deleteContact(contact.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddContactSheet(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
    );
  }
}
