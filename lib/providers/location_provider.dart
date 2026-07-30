import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/location_repository.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(firestoreProvider), ref.watch(currentUidProvider));
});

final locationsStreamProvider = StreamProvider((ref) {
  return ref.watch(locationRepositoryProvider).watchLocations();
});
