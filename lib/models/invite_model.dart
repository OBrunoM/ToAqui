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
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'used': used,
    };
  }

  factory InviteModel.fromMap(String code, Map<String, dynamic> map) {
    return InviteModel(
      code: code,
      ownerUid: map['ownerUid'],
      contactId: map['contactId'],
      createdAt: DateTime.parse(map['createdAt']),
      expiresAt: DateTime.parse(map['expiresAt']),
      used: map['used'] ?? false,
    );
  }
}
