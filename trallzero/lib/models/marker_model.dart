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

  TruckerMarker({
    required this.id,
    required this.position,
    required this.type,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type.name,
      'description': description,
    };
  }

  factory TruckerMarker.fromMap(Map<String, dynamic> map) {
    return TruckerMarker(
      id: map['id'] as String,
      position: LatLng(map['latitude'] as double, map['longitude'] as double),
      type: MarkerType.values.byName(map['type'] as String),
      description: map['description'] as String? ?? '',
    );
  }
}
