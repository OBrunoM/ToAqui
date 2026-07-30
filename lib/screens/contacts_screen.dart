import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contact_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/add_contact_sheet.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  Future<void> _addContact(BuildContext context) async {
    final code = await showAddContactSheet(context);
    if (code == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convite criado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Envie esse código pro seu familiar por WhatsApp, SMS ou como preferir:'),
            const SizedBox(height: 16),
            SelectableText(
              code,
              key: const Key('invite-code-text'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Família e Contatos')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro ao carregar contatos: $error')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return EmptyState(
              emoji: '👨‍👩‍👧‍👦',
              title: 'Sua família ainda não está por aqui',
              subtitle: 'Convide quem você ama pra saber que você chegou bem',
              ctaLabel: 'Convidar familiar',
              onCtaPressed: () => _addContact(context),
            );
          }
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                ),
                title: Text(contact.name),
                subtitle: Text(
                  contact.linkedUid == null
                      ? '${contact.relationship} · convite pendente'
                      : contact.relationship,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(contactRepositoryProvider).deleteContact(contact.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
    );
  }
}
