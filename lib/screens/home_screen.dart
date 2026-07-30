import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

class ArrivalEntry {
  final String title;
  final String subtitle;

  const ArrivalEntry({required this.title, required this.subtitle});
}

const _defaultArrivals = [
  ArrivalEntry(title: 'Trabalho', subtitle: 'Chegou hoje às 08:45'),
  ArrivalEntry(title: 'Casa', subtitle: 'Chegou ontem às 18:30'),
];

class HomeScreen extends ConsumerStatefulWidget {
  final List<ArrivalEntry>? arrivals;

  const HomeScreen({super.key, this.arrivals});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  List<ArrivalEntry> _arrivals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = widget.arrivals ?? await _fetchArrivals();
    if (!mounted) return;

    // Ensure loading state is visible before showing data when arrivals are injected
    if (widget.arrivals != null) {
      await Future.delayed(Duration.zero);
    }

    if (!mounted) return;
    setState(() {
      _arrivals = result;
      _isLoading = false;
    });
  }

  Future<List<ArrivalEntry>> _fetchArrivals() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _defaultArrivals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/icon.png', height: 28),
            const SizedBox(width: 8),
            const Text('ToAqui', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Tenho um convite',
            onPressed: () => context.push('/join'),
          ),
        ],
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
                      const Text('🏡', style: TextStyle(fontSize: 40)),
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
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ListView(
        children: const [SkeletonListTile(), SkeletonListTile()],
      );
    }
    if (_arrivals.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'Nenhuma chegada registrada ainda',
        subtitle: 'Quando você chegar a um local salvo, ele aparece aqui',
      );
    }
    return ListView(
      children: _arrivals
          .map((entry) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(Icons.check, color: Theme.of(context).colorScheme.secondary),
                ),
                title: Text(entry.title),
                subtitle: Text(entry.subtitle),
              ))
          .toList(),
    );
  }
}
