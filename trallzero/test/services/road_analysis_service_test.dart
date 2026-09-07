import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trallzero/models/road_analysis.dart';
import 'package:trallzero/models/truck_profile.dart';
import 'package:trallzero/services/road_analysis_service.dart';

void main() {
  group('RoadAnalysisService - Slope and Elevation Tests', () {
    final service = RoadAnalysisService.instance;

    test('classifySlope correctly classifies both uphill and downhill slopes', () {
      // Slopes <= 6% (flat / gentle)
      expect(service.classifySlope(0.0), RoadHazardLevel.safe);
      expect(service.classifySlope(4.5), RoadHazardLevel.safe);
      expect(service.classifySlope(-4.5), RoadHazardLevel.safe);
      expect(service.classifySlope(-6.0), RoadHazardLevel.safe);

      // Slopes between 6% and 10% (attention)
      expect(service.classifySlope(7.5), RoadHazardLevel.attention);
      expect(service.classifySlope(-7.5), RoadHazardLevel.attention);
      expect(service.classifySlope(-9.9), RoadHazardLevel.attention);

      // Slopes between 10% and 15% (heavy)
      expect(service.classifySlope(12.0), RoadHazardLevel.heavy);
      expect(service.classifySlope(-12.0), RoadHazardLevel.heavy);

      // Slopes > 15% (avoid)
      expect(service.classifySlope(16.0), RoadHazardLevel.avoid);
      expect(service.classifySlope(-18.0), RoadHazardLevel.avoid);
    });

    test('smoothElevations eliminates high-frequency DEM jitter on flat terrain', () {
      // Simulated flat route points spaced ~15 meters apart
      final points = [
        const LatLng(-23.5500, -46.6330),
        const LatLng(-23.5501, -46.6331),
        const LatLng(-23.5502, -46.6332),
        const LatLng(-23.5503, -46.6333),
        const LatLng(-23.5504, -46.6334),
        const LatLng(-23.5505, -46.6335),
      ];

      // Raw elevations with +/- 1m satellite noise around 700m
      final rawElevations = [700.0, 701.2, 699.8, 701.0, 699.5, 700.0];

      final smoothed = service.smoothElevations(points, rawElevations, windowMeters: 80.0);

      // Smoothed values should stay very close to 700m without sharp 1.5m jumps
      for (var i = 0; i < smoothed.length - 1; i++) {
        final diff = (smoothed[i + 1] - smoothed[i]).abs();
        expect(diff, lessThan(0.8),
            reason: 'Step diff between point $i and ${i + 1} should be smoothed');
      }
    });

    test('smoothElevations preserves macro mountain descents', () {
      // 5 points descending significantly over ~200 meters
      final points = [
        const LatLng(-23.5500, -46.6300),
        const LatLng(-23.5505, -46.6300),
        const LatLng(-23.5510, -46.6300),
        const LatLng(-23.5515, -46.6300),
        const LatLng(-23.5520, -46.6300),
      ];

      // Drops 30 meters (from 800m down to 770m)
      final rawElevations = [800.0, 792.0, 785.0, 777.0, 770.0];

      final smoothed = service.smoothElevations(points, rawElevations, windowMeters: 80.0);

      expect(smoothed.first, greaterThan(795.0));
      expect(smoothed.last, lessThan(775.0));
      expect(smoothed.first - smoothed.last, greaterThan(20.0),
          reason: 'Overall macro descent should be preserved');
    });
  });
}
