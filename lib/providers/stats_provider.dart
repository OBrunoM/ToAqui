import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'arrival_provider.dart';
import 'contact_provider.dart';
import 'location_provider.dart';

final activeLocationsCountProvider = Provider<int>((ref) {
  final locations = ref.watch(locationsStreamProvider).value ?? [];
  return locations.where((location) => location.isActive).length;
});

final linkedContactsCountProvider = Provider<int>((ref) {
  final contacts = ref.watch(contactsStreamProvider).value ?? [];
  return contacts.where((contact) => contact.linkedUid != null).length;
});

final arrivalsThisMonthCountProvider = Provider<int>((ref) {
  final arrivals = ref.watch(arrivalsStreamProvider).value ?? [];
  final now = DateTime.now();
  return arrivals
      .where((arrival) =>
          arrival.createdAt.year == now.year && arrival.createdAt.month == now.month)
      .length;
});
