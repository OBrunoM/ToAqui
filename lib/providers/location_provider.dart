import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';

class LocationNotifier extends StateNotifier<List<LocationModel>> {
  LocationNotifier() : super([]) {
    _loadMockData();
  }

  void _loadMockData() {
    state = [
      LocationModel(
        name: 'Trabalho',
        latitude: -23.550520,
        longitude: -46.633308,
        radius: 100,
        message: 'Cheguei no trabalho em segurança! 💼',
      ),
      LocationModel(
        name: 'Casa',
        latitude: -23.561684,
        longitude: -46.625378,
        radius: 50,
        message: 'Já estou em casa. 🏠',
        isActive: false,
      ),
    ];
  }

  void addLocation(LocationModel location) {
    state = [...state, location];
  }

  void toggleLocation(String id) {
    state = state.map((loc) {
      if (loc.id == id) {
        return loc.copyWith(isActive: !loc.isActive);
      }
      return loc;
    }).toList();
  }

  void deleteLocation(String id) {
    state = state.where((loc) => loc.id != id).toList();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, List<LocationModel>>((ref) {
  return LocationNotifier();
});
