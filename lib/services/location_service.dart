import 'package:geolocator/geolocator.dart';

typedef LocationFetcher = Future<Position?> Function();

Future<Position?> fetchCurrentLocation() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 5));
  } catch (_) {
    return null;
  }
}
