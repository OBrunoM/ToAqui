import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família e Contatos'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Text('M')),
            title: const Text('Mãe'),
            subtitle: const Text('Recebe notificações'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Text('A')),
            title: const Text('Amor'),
            subtitle: const Text('Recebe notificações'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Lógica para convidar familiar
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
    );
  }
}
