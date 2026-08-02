import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/arrival_record.dart';
import '../models/location_model.dart';
import '../providers/arrival_provider.dart';
import '../providers/location_provider.dart';
import '../providers/stats_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/emergency_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrivalsAsync = ref.watch(arrivalsStreamProvider);
    final locationsAsync = ref.watch(locationsStreamProvider);
    final activeLocations = ref.watch(activeLocationsCountProvider);
    final linkedContacts = ref.watch(linkedContactsCountProvider);
    final arrivalsThisMonth = ref.watch(arrivalsThisMonthCountProvider);

    LocationModel? locationFor(String id) {
      final locations = locationsAsync.value ?? [];
      for (final loc in locations) {
        if (loc.id == id) return loc;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/icon.png', height: 28),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ToAqui', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Sempre avisando quem importa.', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(arrivalsAsync: arrivalsAsync, locationFor: locationFor),
              const SizedBox(height: 16),
              _StatsRow(
                activeLocations: activeLocations,
                linkedContacts: linkedContacts,
                arrivalsThisMonth: arrivalsThisMonth,
              ),
              const SizedBox(height: 16),
              const EmergencyButton(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Últimas chegadas',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Text('Ver todas', style: TextStyle(color: AppColors.teal)),
                ],
              ),
              const SizedBox(height: 12),
              _ArrivalsList(
                arrivalsAsync: arrivalsAsync,
                locationFor: locationFor,
                linkedContacts: linkedContacts,
              ),
              const SizedBox(height: 24),
              _InviteCard(onInvite: () => context.go('/contacts?openAdd=true')),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final AsyncValue<List<ArrivalRecord>> arrivalsAsync;
  final LocationModel? Function(String id) locationFor;

  const _HeroCard({required this.arrivalsAsync, required this.locationFor});

  @override
  Widget build(BuildContext context) {
    final arrivals = arrivalsAsync.value ?? [];
    final latest = arrivals.isEmpty ? null : arrivals.first;
    final latestLocation = latest == null ? null : locationFor(latest.locationId);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.shield, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Você está protegido',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Monitoramento ativo', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          if (latest != null)
            Row(
              children: [
                const Icon(Icons.place, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${latestLocation?.name ?? 'Local'} • ${TimeOfDay.fromDateTime(latest.createdAt).format(context)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            )
          else
            const Text('Nenhuma chegada registrada ainda', style: TextStyle(color: Colors.white)),
          const Divider(color: Colors.white30, height: 24),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Tudo funcionando normalmente.', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int activeLocations;
  final int linkedContacts;
  final int arrivalsThisMonth;

  const _StatsRow({
    required this.activeLocations,
    required this.linkedContacts,
    required this.arrivalsThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('$activeLocations', 'Locais ativos'),
        const SizedBox(width: 8),
        tile('$linkedContacts', 'Contatos avisados'),
        const SizedBox(width: 8),
        tile('$arrivalsThisMonth', 'Chegadas este mês'),
      ],
    );
  }
}

class _ArrivalsList extends StatelessWidget {
  final AsyncValue<List<ArrivalRecord>> arrivalsAsync;
  final LocationModel? Function(String id) locationFor;
  final int linkedContacts;

  const _ArrivalsList({
    required this.arrivalsAsync,
    required this.locationFor,
    required this.linkedContacts,
  });

  @override
  Widget build(BuildContext context) {
    return arrivalsAsync.when(
      loading: () => const Column(children: [SkeletonListTile(), SkeletonListTile()]),
      error: (error, stack) => Text('Erro ao carregar chegadas: $error'),
      data: (arrivals) {
        if (arrivals.isEmpty) {
          return const SizedBox(
            height: 280,
            child: EmptyState(
              emoji: '📭',
              title: 'Nenhuma chegada registrada ainda',
              subtitle: 'Quando você chegar a um local salvo, ele aparece aqui',
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: arrivals.length,
          itemBuilder: (context, index) {
            final arrival = arrivals[index];
            final location = locationFor(arrival.locationId);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text(location?.icon ?? '📍')),
                title: Text(location?.name ?? 'Local removido'),
                subtitle: const Text('Chegada registrada com sucesso'),
                trailing: Text('$linkedContacts contatos avisados', style: const TextStyle(fontSize: 11)),
              ),
            );
          },
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  final VoidCallback onInvite;

  const _InviteCard({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convide seus contatos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Eles recebem um código de convite para acompanhar suas chegadas.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onInvite, child: const Text('Convidar')),
          ],
        ),
      ),
    );
  }
}
