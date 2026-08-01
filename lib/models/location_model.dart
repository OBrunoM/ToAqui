import 'package:uuid/uuid.dart';

class LocationModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // em metros
  final String message;
  final bool isActive;
  final String icon;

  LocationModel({
    String? id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.message,
    this.isActive = true,
    this.icon = '📍',
  }) : id = id ?? const Uuid().v4();

  LocationModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    String? message,
    bool? isActive,
    String? icon,
  }) {
    return LocationModel(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'message': message,
      'isActive': isActive,
      'icon': icon,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      radius: map['radius'],
      message: map['message'],
      isActive: map['isActive'],
      icon: map['icon'] ?? '📍',
    );
  }
}
