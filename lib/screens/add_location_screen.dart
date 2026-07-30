import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../models/location_model.dart';
import '../widgets/app_snackbar.dart';

class AddLocationScreen extends ConsumerStatefulWidget {
  const AddLocationScreen({super.key});

  @override
  ConsumerState<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends ConsumerState<AddLocationScreen> {
  LatLng? _selectedLocation;
  double _radius = 100;
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-23.550520, -46.633308),
    zoom: 14.0,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _saveLocation() {
    if (_selectedLocation == null || _nameController.text.isEmpty) {
      AppSnackbar.showError(context, 'Selecione um local no mapa e dê um nome.');
      return;
    }

    final newLocation = LocationModel(
      name: _nameController.text,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radius: _radius,
      message: _messageController.text.isNotEmpty
          ? _messageController.text
          : 'Cheguei em ${_nameController.text} em segurança!',
    );

    ref.read(locationRepositoryProvider).addLocation(newLocation);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onTap: (latLng) => setState(() => _selectedLocation = latLng),
            markers: _selectedLocation == null
                ? {}
                : {Marker(markerId: const MarkerId('selected'), position: _selectedLocation!)},
            circles: _selectedLocation == null
                ? {}
                : {
                    Circle(
                      circleId: const CircleId('radius'),
                      center: _selectedLocation!,
                      radius: _radius,
                      fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      strokeColor: Theme.of(context).colorScheme.primary,
                      strokeWidth: 2,
                    )
                  },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedLocation == null)
                  const Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text('Toque no mapa para selecionar o local'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Local (ex: Trabalho)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Raio de detecção: ${_radius.toInt()} metros'),
                    Slider(
                      value: _radius,
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      label: '${_radius.toInt()}m',
                      onChanged: (val) => setState(() => _radius = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem personalizada (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saveLocation,
                      child: const Text('Salvar Local'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
