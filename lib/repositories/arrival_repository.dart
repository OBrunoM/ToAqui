import 'package:cloud_firestore/cloud_firestore.dart';

class ArrivalRepository {
  ArrivalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> recordArrival({
    required String ownerUid,
    required String locationId,
    required String message,
  }) {
    return _firestore.collection('arrivals').add({
      'ownerUid': ownerUid,
      'locationId': locationId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
