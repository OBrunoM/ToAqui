import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String code;
  final String ownerUid;
  final String contactId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;

  InviteModel({
    required this.code,
    required this.ownerUid,
    required this.contactId,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'contactId': contactId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': used,
    };
  }

  factory InviteModel.fromMap(String code, Map<String, dynamic> map) {
    return InviteModel(
      code: code,
      ownerUid: map['ownerUid'],
      contactId: map['contactId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      used: map['used'] ?? false,
    );
  }
}
