import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:to_aqui/services/location_service.dart';

/// A fake [GeolocatorPlatform] whose [checkPermission]/[requestPermission]/
/// [getCurrentPosition] behavior is configurable per-test, so we can
/// simulate a permission dialog that never resolves (the user leaves it up
/// forever) or resolves slowly.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  _FakeGeolocatorPlatform({
    this.checkPermissionResult = LocationPermission.denied,
    Future<LocationPermission>? requestPermissionFuture,
    this.position,
  }) : requestPermissionFuture = requestPermissionFuture ?? Future.value(LocationPermission.whileInUse);

  final LocationPermission checkPermissionResult;
  final Future<LocationPermission> requestPermissionFuture;
  final Position? position;

  @override
  Future<LocationPermission> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermission> requestPermission() => requestPermissionFuture;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (position == null) {
      throw StateError('no fake position configured');
    }
    return position!;
  }
}

void main() {
  final originalPlatform = GeolocatorPlatform.instance;

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  test('returns null within the timeout when requestPermission() never resolves', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      checkPermissionResult: LocationPermission.denied,
      requestPermissionFuture: Completer<LocationPermission>().future, // never completes
    );

    final stopwatch = Stopwatch()..start();
    final result = await fetchCurrentLocation();
    stopwatch.stop();

    expect(result, isNull);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 7)));
  });

  test('returns null within the timeout when requestPermission() resolves slowly', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      checkPermissionResult: LocationPermission.denied,
      requestPermissionFuture: Future.delayed(
        const Duration(seconds: 30),
        () => LocationPermission.whileInUse,
      ),
    );

    final stopwatch = Stopwatch()..start();
    final result = await fetchCurrentLocation();
    stopwatch.stop();

    expect(result, isNull);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 7)));
  });

  test('returns null when permission is denied without prompting', () async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      checkPermissionResult: LocationPermission.deniedForever,
    );

    final result = await fetchCurrentLocation();

    expect(result, isNull);
  });

  test('returns the position when permission is already granted', () async {
    final position = Position(
      latitude: -23.55,
      longitude: -46.63,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      checkPermissionResult: LocationPermission.whileInUse,
      position: position,
    );

    final result = await fetchCurrentLocation();

    expect(result, position);
  });
}
