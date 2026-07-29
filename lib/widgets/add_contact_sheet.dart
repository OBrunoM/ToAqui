import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';

void showAddContactSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const AddContactSheet(),
  );
}

class AddContactSheet extends ConsumerStatefulWidget {
  const AddContactSheet({super.key});

  @override
  ConsumerState<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<AddContactSheet> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _canSave = false;

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _save() {
    final relationship = _relationshipController.text.isNotEmpty
        ? _relationshipController.text
        : 'Familiar';

    ref.read(contactProvider.notifier).addContact(
          ContactModel(name: _nameController.text, relationship: relationship),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Convidar familiar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('contact-name-field'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _canSave = value.trim().isNotEmpty),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact-relationship-field'),
            controller: _relationshipController,
            decoration: const InputDecoration(
              labelText: 'Relação (ex: Mãe, Amigo)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('contact-save-button'),
            onPressed: _canSave ? _save : null,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
