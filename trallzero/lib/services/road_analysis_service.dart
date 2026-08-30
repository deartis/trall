import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/road_analysis.dart';
import '../models/truck_profile.dart';
import 'elevation_service.dart';

class RoadAnalysisService {
  RoadAnalysisService._();
  static final RoadAnalysisService instance = RoadAnalysisService._();

  final Distance _distance = const Distance();

  RoadHazardLevel classifySlope(double slopePercent) {
    if (slopePercent <= 6.0) return RoadHazardLevel.safe;
    if (slopePercent <= 10.0) return RoadHazardLevel.attention;
    if (slopePercent <= 15.0) return RoadHazardLevel.heavy;
    return RoadHazardLevel.avoid;
  }

  Future<List<RoadSegmentAnalysis>> analyzeSlopeSegments(
    List<LatLng> routePoints,
    TruckProfile profile,
  ) async {
    final cleanedPoints = routePoints.toList();
    if (cleanedPoints.length < 2) return [];

    final elevations = await ElevationService.instance.getElevations(cleanedPoints);
    final segments = <RoadSegmentAnalysis>[];

    for (var i = 0; i < cleanedPoints.length - 1; i++) {
      final start = cleanedPoints[i];
      final end = cleanedPoints[i + 1];
      final startAltitude = elevations[i];
      final endAltitude = elevations[i + 1];
      final distanceMeters = _distance.as(LengthUnit.Meter, start, end);
      final uphill = endAltitude - startAltitude;
      final slopePercent = distanceMeters > 1 ? (uphill / distanceMeters) * 100 : 0.0;
      final hazardLevel = classifySlope(slopePercent);
      final description = _segmentDescription(slopePercent, startAltitude, endAltitude, distanceMeters, profile);

      segments.add(RoadSegmentAnalysis(
        start: start,
        end: end,
        distanceMeters: distanceMeters,
        startAltitude: startAltitude,
        endAltitude: endAltitude,
        slopePercent: slopePercent,
        hazardLevel: hazardLevel,
        description: description,
      ));
    }

    return segments;
  }

  String _segmentDescription(
    double slopePercent,
    double startAltitude,
    double endAltitude,
    double distanceMeters,
    TruckProfile profile,
  ) {
    final roundedSlope = slopePercent.abs().toStringAsFixed(1);
    final direction = slopePercent >= 0 ? 'subida' : 'descida';
    return '$roundedSlope% de $direction em ${distanceMeters.toStringAsFixed(0)} m';
  }

  Future<List<RoadAnalysisFinding>> analyzeOsmRestrictions(
    List<LatLng> routePoints,
    TruckProfile profile,
  ) async {
    final samples = _samplePoints(routePoints, 8);
    final findings = <RoadAnalysisFinding>[];

    for (final point in samples) {
      final tags = await _getNearestOsmTags(point);
      if (tags.isEmpty) continue;

      final maybeFinding = _mapTagsToFinding(tags, point, profile);
      if (maybeFinding != null) {
        findings.add(maybeFinding);
      }
    }

    return findings;
  }

  RoadHazardLevel getMaxSeverity(List<RoadSegmentAnalysis> segments, List<RoadAnalysisFinding> findings) {
    var maxSeverity = RoadHazardLevel.safe;
    for (final segment in segments) {
      if (segment.hazardLevel.index > maxSeverity.index) {
        maxSeverity = segment.hazardLevel;
      }
    }
    for (final finding in findings) {
      if (finding.severity.index > maxSeverity.index) {
        maxSeverity = finding.severity;
      }
    }
    return maxSeverity;
  }

  List<LatLng> _samplePoints(List<LatLng> routePoints, int maxSamples) {
    if (routePoints.length <= maxSamples) return routePoints;
    final step = routePoints.length ~/ maxSamples;
    final samples = <LatLng>[];
    for (var i = 0; i < routePoints.length; i += step) {
      samples.add(routePoints[i]);
    }
    if (samples.isEmpty) samples.add(routePoints.first);
    return samples;
  }

  Future<Map<String, String>> _getNearestOsmTags(LatLng point) async {
    final query = '''
[out:json][timeout:15];
(
  way(around:40,${point.latitude},${point.longitude})[highway];
  relation(around:40,${point.latitude},${point.longitude})[highway];
);
out tags center qt;
''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );
      if (response.statusCode != 200) return {};

      final data = json.decode(response.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) return {};

      final tags = <String, String>{};
      for (final element in elements) {
        final elementTags = element['tags'] as Map<String, dynamic>?;
        if (elementTags == null) continue;
        elementTags.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            tags[key] = value.toString();
          }
        });
        if (tags.isNotEmpty) break;
      }
      return tags;
    } catch (_) {
      return {};
    }
  }

  RoadAnalysisFinding? _mapTagsToFinding(
    Map<String, String> tags,
    LatLng point,
    TruckProfile profile,
  ) {
    final highway = tags['highway'] ?? '';
    final surface = tags['surface'] ?? '';
    final smoothness = tags['smoothness'] ?? '';
    final maxweight = tags['maxweight'] ?? tags['maxweight:conditional'] ?? '';
    final maxheight = tags['maxheight'] ?? '';
    final maxwidth = tags['maxwidth'] ?? '';
    final hgv = tags['hgv'] ?? '';
    final access = tags['access'] ?? '';

    if (access == 'no' || tags['motor_vehicle'] == 'no' || tags['hgv'] == 'no' || tags['truck'] == 'no') {
      return RoadAnalysisFinding(
        title: 'Via proibida para caminhões',
        detail: 'A estrada tem restrição de caminhões ou veículos pesados.',
        severity: RoadHazardLevel.avoid,
        location: point,
      );
    }

    if (highway == 'residential' || highway == 'living_street' || highway == 'service') {
      return RoadAnalysisFinding(
        title: 'Via residencial ou serviço',
        detail: 'Rota pode ser inadequada para veículos grandes e pesados.',
        severity: RoadHazardLevel.attention,
        location: point,
      );
    }

    if (surface == 'unpaved' || surface == 'gravel' || surface == 'dirt' || surface == 'mud' || surface == 'sand') {
      return RoadAnalysisFinding(
        title: 'Superfície ruim',
        detail: 'A estrada apresenta superfície não pavimentada ou ruim: $surface.',
        severity: RoadHazardLevel.heavy,
        location: point,
      );
    }

    if (smoothness == 'bad' || smoothness == 'very_bad' || smoothness == 'horrible' || smoothness == 'impassable') {
      return RoadAnalysisFinding(
        title: 'Troca de piso severa',
        detail: 'A qualidade da via está abaixo do padrão para veículos pesados.',
        severity: RoadHazardLevel.heavy,
        location: point,
      );
    }

    if (maxweight.isNotEmpty) {
      final pattern = RegExp(r'([0-9]+\.?[0-9]*)');
      final match = pattern.firstMatch(maxweight.replaceAll('t', '').replaceAll('ton', ''));
      if (match != null) {
        final maxWeight = double.tryParse(match.group(1)!) ?? 0.0;
        final maxWeightKg = maxWeight > 0 ? maxWeight * 1000 : 0.0;
        if (maxWeightKg > 0 && maxWeightKg < profile.maxWeightKg) {
          return RoadAnalysisFinding(
            title: 'Limite de peso reduzido',
            detail: 'A via permite até $maxweight de peso, inferior ao perfil atual.',
            severity: RoadHazardLevel.heavy,
            location: point,
          );
        }
      }
    }

    if (maxheight.isNotEmpty) {
      final pattern = RegExp(r'([0-9]+\.?[0-9]*)');
      final match = pattern.firstMatch(maxheight.replaceAll('m', ''));
      if (match != null) {
        final heightMeters = double.tryParse(match.group(1)!) ?? 0.0;
        if (heightMeters > 0 && heightMeters < profile.maxHeightMeters) {
          return RoadAnalysisFinding(
            title: 'Altura limitada',
            detail: 'A via admite até $maxheight de altura, menor que o perfil atual.',
            severity: RoadHazardLevel.heavy,
            location: point,
          );
        }
      }
    }

    if (maxwidth.isNotEmpty) {
      final pattern = RegExp(r'([0-9]+\.?[0-9]*)');
      final match = pattern.firstMatch(maxwidth.replaceAll('m', ''));
      if (match != null) {
        final widthMeters = double.tryParse(match.group(1)!) ?? 0.0;
        if (widthMeters > 0 && widthMeters < 2.6) {
          return RoadAnalysisFinding(
            title: 'Via estreita',
            detail: 'A largura máxima é de $maxwidth, o que pode ser restrito para carga pesada.',
            severity: RoadHazardLevel.attention,
            location: point,
          );
        }
      }
    }

    if (hgv.isNotEmpty) {
      return RoadAnalysisFinding(
        title: 'Regra HGV detectada',
        detail: 'A via contém restrições específicas para veículos pesados (hgv).',
        severity: RoadHazardLevel.attention,
        location: point,
      );
    }

    return null;
  }
}
