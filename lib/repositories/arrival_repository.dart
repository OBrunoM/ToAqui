import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/arrival_record.dart';

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

  Stream<List<ArrivalRecord>> watchArrivals(String ownerUid) {
    return _firestore
        .collection('arrivals')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ArrivalRecord.fromMap(doc.id, doc.data())).toList());
  }
}
