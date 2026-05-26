import 'package:latlong2/latlong.dart';

/// Representa uma instrução de manobra do OSRM
class RouteStep {
  final String type;      // depart | turn | arrive | roundabout | etc.
  final String modifier; // left | right | straight | slight left | etc.
  final String streetName;
  final double distance;  // metros até a próxima manobra
  final LatLng location;  // ponto onde ocorre a manobra

  const RouteStep({
    required this.type,
    required this.modifier,
    required this.streetName,
    required this.distance,
    required this.location,
  });

  /// Parseia um step do JSON do OSRM
  factory RouteStep.fromOsrm(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>? ?? {};
    final loc = maneuver['location'] as List<dynamic>? ?? [0.0, 0.0];
    return RouteStep(
      type: (maneuver['type'] as String? ?? 'turn'),
      modifier: (maneuver['modifier'] as String? ?? 'straight'),
      streetName: (json['name'] as String? ?? ''),
      distance: (json['distance'] as num? ?? 0).toDouble(),
      location: LatLng(
        (loc[1] as num).toDouble(),
        (loc[0] as num).toDouble(),
      ),
    );
  }

  /// Distância formatada para exibição ("300 m" / "1,2 km")
  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.toInt()} m';
  }

  /// Texto em português da manobra
  String get translatedManeuver {
    if (type == 'depart') return 'Siga em frente';
    if (type == 'arrive') return 'Chegou ao destino';
    if (type == 'roundabout' || type == 'rotary') return 'Entre na rotatória';
    if (type == 'fork') {
      return modifier.contains('right') ? 'Mantenha à direita' : 'Mantenha à esquerda';
    }
    if (type == 'merge') return 'Entre na via';
    if (type == 'on ramp') return 'Acesse a rampa';
    if (type == 'off ramp') return 'Saída da rampa';
    return switch (modifier) {
      'left'          => 'Vire à esquerda',
      'sharp left'    => 'Vire acentuadamente à esquerda',
      'slight left'   => 'Vire levemente à esquerda',
      'right'         => 'Vire à direita',
      'sharp right'   => 'Vire acentuadamente à direita',
      'slight right'  => 'Vire levemente à direita',
      'uturn'         => 'Faça o retorno',
      _               => 'Continue em frente',
    };
  }
}
