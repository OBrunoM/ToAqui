import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyRepository {
  EmergencyRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> recordEmergency({
    required String ownerUid,
    double? latitude,
    double? longitude,
  }) {
    return _firestore.collection('emergencies').add({
      'ownerUid': ownerUid,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
