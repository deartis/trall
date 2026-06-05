import 'package:latlong2/latlong.dart';

class DeliveryStop {
  final String id;           // pode ser o id numérico da API (como string) ou UUID local
  final int? apiId;          // id real do RouteStop no banco (null até ser salvo)
  final String recipientName;
  final String address;
  final double lat;
  final double lng;
  final String? eta;
  bool isCompleted;

  DeliveryStop({
    required this.id,
    this.apiId,
    required this.recipientName,
    required this.address,
    required this.lat,
    required this.lng,
    this.eta,
    this.isCompleted = false,
  });

  LatLng get position => LatLng(lat, lng);

  factory DeliveryStop.fromApiJson(Map<String, dynamic> json) {
    return DeliveryStop(
      id: json['id'].toString(),
      apiId: json['id'] as int?,
      recipientName: json['recipientName'] ?? '',
      address: json['address'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'recipientName': recipientName,
      'address': address,
      'lat': lat,
      'lng': lng,
      'isCompleted': isCompleted,
    };
  }

  DeliveryStop copyWith({
    String? id,
    int? apiId,
    String? recipientName,
    String? address,
    double? lat,
    double? lng,
    String? eta,
    bool? isCompleted,
  }) {
    return DeliveryStop(
      id: id ?? this.id,
      apiId: apiId ?? this.apiId,
      recipientName: recipientName ?? this.recipientName,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      eta: eta ?? this.eta,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
