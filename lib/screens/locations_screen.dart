import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/arrival_provider.dart';
import '../providers/location_provider.dart';
import '../models/location_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_snackbar.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meus Locais'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Ativos'), Tab(text: 'Inativos')],
          ),
        ),
        body: locationsAsync.when(
          loading: () => ListView(
            children: const [SkeletonListTile(), SkeletonListTile(), SkeletonListTile()],
          ),
          error: (error, stack) => Center(child: Text('Erro ao carregar locais: $error')),
          data: (locations) {
            final active = locations.where((l) => l.isActive).toList();
            final inactive = locations.where((l) => !l.isActive).toList();
            return TabBarView(
              children: [
                _LocationList(locations: active, emptyTitle: 'Nenhum local ativo'),
                _LocationList(locations: inactive, emptyTitle: 'Nenhum local inativo'),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/locations/add'),
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Novo Local'),
        ),
      ),
    );
  }
}

class _LocationList extends ConsumerWidget {
  final List<LocationModel> locations;
  final String emptyTitle;

  const _LocationList({required this.locations, required this.emptyTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locations.isEmpty) {
      return EmptyState(
        emoji: '📍',
        title: emptyTitle,
        subtitle: 'Adicione um local para começar a avisar sua família',
      );
    }
    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(loc.icon, style: const TextStyle(fontSize: 20))),
            title: Text(loc.name),
            subtitle: Text('Raio: ${loc.radius.toInt()}m'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(loc.isActive ? 'Ativo' : 'Inativo'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: loc.isActive
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'simulate') {
                      ref.read(arrivalRepositoryProvider).recordArrival(
                        ownerUid: ref.read(currentUidProvider),
                        locationId: loc.id,
                        message: loc.message,
                      );
                      AppSnackbar.showConfirmation(context, 'Chegada simulada em ${loc.name}!');
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'simulate', child: Text('Simular chegada')),
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
