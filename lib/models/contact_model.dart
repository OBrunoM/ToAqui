import 'package:uuid/uuid.dart';

class ContactModel {
  final String id;
  final String name;
  final String relationship;
  final String? linkedUid;
  final String? inviteCode;

  ContactModel({
    String? id,
    required this.name,
    required this.relationship,
    this.linkedUid,
    this.inviteCode,
  }) : id = id ?? const Uuid().v4();

  ContactModel copyWith({
    String? name,
    String? relationship,
    String? linkedUid,
    String? inviteCode,
  }) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      linkedUid: linkedUid ?? this.linkedUid,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'linkedUid': linkedUid,
      'inviteCode': inviteCode,
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'],
      name: map['name'],
      relationship: map['relationship'],
      linkedUid: map['linkedUid'],
      inviteCode: map['inviteCode'],
    );
  }
}
