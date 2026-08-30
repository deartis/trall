import 'package:latlong2/latlong.dart';

enum RoadHazardLevel {
  safe,
  attention,
  heavy,
  avoid,
}

extension RoadHazardLevelExtension on RoadHazardLevel {
  String get label {
    switch (this) {
      case RoadHazardLevel.safe:
        return 'Segura';
      case RoadHazardLevel.attention:
        return 'Atenção';
      case RoadHazardLevel.heavy:
        return 'Pesada';
      case RoadHazardLevel.avoid:
        return 'Evitar';
    }
  }
}

class RoadSegmentAnalysis {
  final LatLng start;
  final LatLng end;
  final double distanceMeters;
  final double startAltitude;
  final double endAltitude;
  final double slopePercent;
  final RoadHazardLevel hazardLevel;
  final String description;

  RoadSegmentAnalysis({
    required this.start,
    required this.end,
    required this.distanceMeters,
    required this.startAltitude,
    required this.endAltitude,
    required this.slopePercent,
    required this.hazardLevel,
    required this.description,
  });
}

class RoadAnalysisFinding {
  final String title;
  final String detail;
  final RoadHazardLevel severity;
  final LatLng? location;

  RoadAnalysisFinding({
    required this.title,
    required this.detail,
    required this.severity,
    this.location,
  });
}
