import 'package:latlong2/latlong.dart';
import 'road_analysis.dart';
import 'route_step.dart';

class TruckRoute {
  final List<LatLng> points;
  final double distance;
  final double duration;
  final List<RoadSegmentAnalysis> slopeSegments;
  final List<RoadAnalysisFinding> findings;
  final RoadHazardLevel riskLevel;
  final List<RouteStep> steps;

  TruckRoute({
    required this.points,
    required this.distance,
    required this.duration,
    required this.slopeSegments,
    required this.findings,
    required this.riskLevel,
    this.steps = const [],
  });
}
