import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/app_colors.dart';
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
      return AppColors.safe;
    case RoadHazardLevel.attention:
      return AppColors.yellow;
    case RoadHazardLevel.heavy:
      return AppColors.attentionRoute;
    case RoadHazardLevel.avoid:
      return AppColors.dangerRoute;
  }
}
