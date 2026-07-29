import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../models/location_model.dart';

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
    target: LatLng(-23.550520, -46.633308), // São Paulo default
    zoom: 14.0,
  );

  void _saveLocation() {
    if (_selectedLocation == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um local no mapa e dê um nome.')),
      );
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

    ref.read(locationProvider.notifier).addLocation(newLocation);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Local'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveLocation,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialPosition,
                  onTap: (latLng) {
                    setState(() {
                      _selectedLocation = latLng;
                    });
                  },
                  markers: _selectedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: _selectedLocation!,
                          )
                        },
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
                if (_selectedLocation == null)
                  const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Toque no mapa para selecionar o local'),
                      ),
                    ),
                  )
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    onChanged: (val) {
                      setState(() {
                        _radius = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Mensagem personalizada (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveLocation,
                      child: const Text('Salvar Local'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
