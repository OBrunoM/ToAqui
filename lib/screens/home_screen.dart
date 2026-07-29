import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToAqui', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.shield, size: 48, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Rastreamento Ativo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Avisaremos sua família automaticamente quando você chegar aos seus destinos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Últimos Envios',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: const [
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.check, color: Colors.green),
                        backgroundColor: Colors.greenAccent,
                      ),
                      title: Text('Trabalho'),
                      subtitle: Text('Chegou hoje às 08:45'),
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.check, color: Colors.green),
                        backgroundColor: Colors.greenAccent,
                      ),
                      title: Text('Casa'),
                      subtitle: Text('Chegou ontem às 18:30'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
