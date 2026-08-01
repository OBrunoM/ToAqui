import 'package:cloud_firestore/cloud_firestore.dart';

class ArrivalRecord {
  final String id;
  final String locationId;
  final String message;
  final DateTime createdAt;

  ArrivalRecord({
    required this.id,
    required this.locationId,
    required this.message,
    required this.createdAt,
  });

  factory ArrivalRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return ArrivalRecord(
      id: id,
      locationId: map['locationId'] as String,
      message: map['message'] as String,
      // A just-written doc can be read back before the server timestamp
      // resolves (optimistic local snapshot); fall back to now() rather
      // than crash on a null cast.
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : DateTime.now(),
    );
  }
}
