import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/invite_repository.dart';
import '../providers/firestore_provider.dart';
import '../widgets/app_snackbar.dart';

Future<String?> showAddContactSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
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
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final relationship = _relationshipController.text.isNotEmpty
          ? _relationshipController.text
          : 'Familiar';
      final contact = ContactModel(name: _nameController.text, relationship: relationship);

      await ref.read(contactRepositoryProvider).addContact(contact);

      final invites = InviteRepository(ref.read(firestoreProvider));
      final code = await invites.createInvite(
        ownerUid: ref.read(currentUidProvider),
        contactId: contact.id,
      );
      await ref.read(contactRepositoryProvider).updateInviteCode(contact.id, code);

      if (!mounted) return;
      Navigator.of(context).pop(code);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.showError(context, 'Não foi possível salvar. Tente de novo.');
    }
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
            onPressed: (_canSave && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
