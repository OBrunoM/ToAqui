import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/location_repository.dart';
import 'auth_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(FirebaseFirestore.instance, ref.watch(currentUidProvider));
});

final locationsStreamProvider = StreamProvider((ref) {
  return ref.watch(locationRepositoryProvider).watchLocations();
});
