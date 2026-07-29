import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geofence_service/geofence_service.dart';
import '../models/location_model.dart';
import '../providers/location_provider.dart';

class GeofenceHandler {
  final _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    retries: 3,
    useActivityRecognition: false,
    allowMockLocations: true,
    printDevLog: true,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
  );

  void init(WidgetRef ref) {
    _geofenceService.addGeofenceStatusChangeListener((geofence, geofenceRadius, geofenceStatus, location) {
      if (geofenceStatus == GeofenceStatus.ENTER) {
        _onEnterGeofence(geofence.id, ref);
      } else if (geofenceStatus == GeofenceStatus.DWELL) {
        // Can optionally trigger after staying for some time
      }
    });

    _geofenceService.addLocationChangeListener((location) {
      // Background location update
    });

    _geofenceService.addLocationServicesStatusChangeListener((status) {
      // GPS turned on/off
    });

    _geofenceService.addActivityChangeListener((activity) {
      // User activity changes (walking, driving)
    });

    _geofenceService.addStreamErrorListener((error) {
      // Handle errors
    });
  }

  void _onEnterGeofence(String locationId, WidgetRef ref) {
    // Find the location
    final locations = ref.read(locationProvider);
    final loc = locations.firstWhere((l) => l.id == locationId, orElse: () => throw Exception('Location not found'));
    
    if (loc.isActive) {
      // 1. Log to history
      // 2. Trigger Firebase Cloud Function to send Push Notification to Family
      print('=== AVISO === Chegou no local: ${loc.name}');
      // TODO: Firebase Call
    }
  }

  Future<void> requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return;
    }
    
    // Request background permission (required for geofencing when app is closed)
    // Needs to be done via permission_handler for Android 10+
  }

  void start(List<LocationModel> locations) {
    _geofenceService.clearGeofenceList();
    
    final geofences = locations.map((loc) {
      return Geofence(
        id: loc.id,
        latitude: loc.latitude,
        longitude: loc.longitude,
        radius: [
          GeofenceRadius(id: 'radius_1', length: loc.radius),
        ],
      );
    }).toList();

    _geofenceService.start(geofenceList: geofences).catchError((error) {
      print('Error starting geofence: $error');
    });
  }

  void stop() {
    _geofenceService.stop();
  }
}

final geofenceHandlerProvider = Provider<GeofenceHandler>((ref) {
  return GeofenceHandler();
});
