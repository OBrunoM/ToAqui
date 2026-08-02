import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/add_contact_sheet.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  final bool autoOpenAdd;

  const ContactsScreen({super.key, this.autoOpenAdd = false});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addContact(context);
      });
    }
  }

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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsStreamProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Família e Contatos'),
          bottom: const TabBar(tabs: [Tab(text: 'Todos'), Tab(text: 'Pendentes')]),
        ),
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
            final pending = contacts.where((c) => c.linkedUid == null).toList();
            return Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      _ContactList(contacts: contacts, onDelete: _deleteContact),
                      _ContactList(contacts: pending, onDelete: _deleteContact),
                    ],
                  ),
                ),
                _InviteFooterCard(onInvite: () => _addContact(context)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addContact(context),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Adicionar'),
        ),
      ),
    );
  }

  void _deleteContact(String id) {
    ref.read(contactRepositoryProvider).deleteContact(id);
  }
}

class _InviteFooterCard extends StatelessWidget {
  final VoidCallback onInvite;

  const _InviteFooterCard({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Convide novos contatos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Compartilhe o convite para que possam acompanhar suas chegadas.'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onInvite, child: const Text('Convidar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactList extends StatelessWidget {
  final List<ContactModel> contacts;
  final void Function(String id) onDelete;

  const _ContactList({required this.contacts, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'Nenhum contato aqui',
        subtitle: 'Contatos pendentes aparecem aqui até aceitarem o convite',
      );
    }
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(contact.name.isNotEmpty ? contact.name[0] : '?')),
            title: Text(contact.name),
            subtitle: Text(
              contact.linkedUid == null ? 'Convite pendente' : 'Recebe todas as notificações',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(label: Text(contact.relationship), visualDensity: VisualDensity.compact),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete(contact.id);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Remover')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
