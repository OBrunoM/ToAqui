import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../repositories/invite_repository.dart';
import '../widgets/app_snackbar.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeController = TextEditingController();
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invites = InviteRepository(ref.read(firestoreProvider));
    final result = await invites.redeemInvite(
      code: _codeController.text.trim().toUpperCase(),
      redeemerUid: ref.read(currentUidProvider),
    );

    if (!mounted) return;

    switch (result) {
      case InviteRedeemSuccess():
        setState(() => _successMessage = 'Conectado! Você vai receber os avisos de chegada.');
      case InviteRedeemFailure(reason: final reason):
        AppSnackbar.showError(context, switch (reason) {
          InviteFailureReason.notFound => 'Código não encontrado. Confira e tente de novo.',
          InviteFailureReason.expired => 'Esse código expirou. Peça um novo convite.',
          InviteFailureReason.alreadyUsed => 'Esse código já foi usado.',
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenho um convite')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Digite o código de 6 caracteres que você recebeu:'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('invite-code-field'),
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código do convite',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('join-submit-button'),
              onPressed: _submit,
              child: const Text('Conectar'),
            ),
            if (_successMessage != null) ...[
              const SizedBox(height: 20),
              Text(_successMessage!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
