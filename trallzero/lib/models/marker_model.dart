import 'package:latlong2/latlong.dart';

enum MarkerType {
  loading,
  restriction,
  weighStation,
  parking,
  police,
  danger,
  gasStation,
  mechanic,
  restaurant,
  speedCamera,
  other
}

class TruckerMarker {
  final String id;
  final LatLng position;
  final MarkerType type;
  final String description;
  final double? heading; // Azimute da via/veículo no momento do reporte (0° a 360°)
  final int confirmations; // Quantidade de confirmações de motoristas
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TruckerMarker({
    required this.id,
    required this.position,
    required this.type,
    this.description = '',
    this.heading,
    this.confirmations = 1,
    this.createdAt,
    this.updatedAt,
  });

  TruckerMarker copyWith({
    String? id,
    LatLng? position,
    MarkerType? type,
    String? description,
    double? heading,
    int? confirmations,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TruckerMarker(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      description: description ?? this.description,
      heading: heading ?? this.heading,
      confirmations: confirmations ?? this.confirmations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type.name,
      'description': description,
      'confirmations': confirmations,
    };
    if (heading != null) map['heading'] = heading;
    if (createdAt != null) map['createdAt'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updatedAt'] = updatedAt!.toIso8601String();
    return map;
  }

  factory TruckerMarker.fromMap(Map<String, dynamic> map) {
    return TruckerMarker(
      id: map['id'] as String,
      position: LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      ),
      type: MarkerType.values.byName(map['type'] as String),
      description: map['description'] as String? ?? '',
      heading: map['heading'] != null ? (map['heading'] as num).toDouble() : null,
      confirmations: map['confirmations'] != null
          ? (map['confirmations'] as num).toInt()
          : 1,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }
}
