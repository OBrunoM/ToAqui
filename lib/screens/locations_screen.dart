import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Locais'),
      ),
      body: locations.isEmpty
          ? const Center(child: Text('Nenhum local cadastrado.'))
          : ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final loc = locations[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.place)),
                  title: Text(loc.name),
                  subtitle: Text('Raio: ${loc.radius.toInt()}m'),
                  trailing: Switch(
                    value: loc.isActive,
                    onChanged: (val) {
                      ref.read(locationProvider.notifier).toggleLocation(loc.id);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/locations/add');
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Novo Local'),
      ),
    );
  }
}
