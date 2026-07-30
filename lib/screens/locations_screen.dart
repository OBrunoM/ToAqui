import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/location_provider.dart';
import '../repositories/arrival_repository.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_snackbar.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Locais')),
      body: locationsAsync.when(
        loading: () => ListView(
          children: const [SkeletonListTile(), SkeletonListTile(), SkeletonListTile()],
        ),
        error: (error, stack) => Center(child: Text('Erro ao carregar locais: $error')),
        data: (locations) {
          if (locations.isEmpty) {
            return const EmptyState(
              emoji: '📍',
              title: 'Nenhum local cadastrado',
              subtitle: 'Adicione um local para começar a avisar sua família',
            );
          }
          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final loc = locations[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.place)),
                title: Text(loc.name),
                subtitle: Text('Raio: ${loc.radius.toInt()}m'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_active),
                      tooltip: 'Simular chegada',
                      onPressed: () {
                        ArrivalRepository(ref.read(firestoreProvider)).recordArrival(
                          ownerUid: ref.read(currentUidProvider),
                          locationId: loc.id,
                          message: loc.message,
                        );
                        AppSnackbar.showConfirmation(context, 'Chegada simulada em ${loc.name}!');
                      },
                    ),
                    Switch(
                      value: loc.isActive,
                      onChanged: (val) {
                        ref.read(locationRepositoryProvider).toggleLocation(loc.id, val);
                        AppSnackbar.showConfirmation(
                          context,
                          '${loc.name} ${val ? 'ativado' : 'desativado'}',
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/add'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Novo Local'),
      ),
    );
  }
}
