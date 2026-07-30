import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class LocationRepository {
  LocationRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('locations');

  Stream<List<LocationModel>> watchLocations() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => LocationModel.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<void> addLocation(LocationModel location) {
    return _collection.doc(location.id).set(location.toMap());
  }

  Future<void> toggleLocation(String id, bool isActive) {
    return _collection.doc(id).update({'isActive': isActive});
  }

  Future<void> deleteLocation(String id) {
    return _collection.doc(id).delete();
  }
}
