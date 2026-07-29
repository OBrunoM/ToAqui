import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_snackbar.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(locationsLoadingProvider);
    final locations = ref.watch(locationProvider);

    Widget body;
    if (isLoading) {
      body = ListView(
        children: const [
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      );
    } else if (locations.isEmpty) {
      body = const EmptyState(
        emoji: '📍',
        title: 'Nenhum local cadastrado',
        subtitle: 'Adicione um local para começar a avisar sua família',
      );
    } else {
      body = ListView.builder(
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
                AppSnackbar.showConfirmation(
                  context,
                  '${loc.name} ${val ? 'ativado' : 'desativado'}',
                );
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Locais')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/add'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Novo Local'),
      ),
    );
  }
}
