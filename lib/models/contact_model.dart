import 'package:uuid/uuid.dart';

class ContactModel {
  final String id;
  final String name;
  final String relationship;

  ContactModel({
    String? id,
    required this.name,
    required this.relationship,
  }) : id = id ?? const Uuid().v4();

  ContactModel copyWith({String? name, String? relationship}) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
    );
  }
}
