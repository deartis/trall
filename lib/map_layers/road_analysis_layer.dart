import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/road_analysis.dart';

List<Polyline> buildRoadAnalysisPolylines(List<RoadSegmentAnalysis> segments) {
  return segments.map((segment) {
    return Polyline(
      points: [segment.start, segment.end],
      color: _colorForHazard(segment.hazardLevel),
      strokeWidth: 6.0,
    );
  }).toList();
}

Color _colorForHazard(RoadHazardLevel hazardLevel) {
  switch (hazardLevel) {
    case RoadHazardLevel.safe:
      return const Color(0xFF34C759);
    case RoadHazardLevel.attention:
      return const Color(0xFFFFD60A);
    case RoadHazardLevel.heavy:
      return const Color(0xFFFF9F0A);
    case RoadHazardLevel.avoid:
      return const Color(0xFFFF453A);
  }
}
