import 'package:geolocator/geolocator.dart';

typedef LocationFetcher = Future<Position?> Function();

Future<Position?> fetchCurrentLocation() async {
  try {
    return await _fetchCurrentLocation().timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  }
}

Future<Position?> _fetchCurrentLocation() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    return null;
  }
  return await Geolocator.getCurrentPosition();
}
