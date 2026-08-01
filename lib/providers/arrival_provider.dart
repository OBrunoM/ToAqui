import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/arrival_repository.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';

final arrivalRepositoryProvider = Provider<ArrivalRepository>((ref) {
  return ArrivalRepository(ref.watch(firestoreProvider));
});

final arrivalsStreamProvider = StreamProvider((ref) {
  return ref.watch(arrivalRepositoryProvider).watchArrivals(ref.watch(currentUidProvider));
});
