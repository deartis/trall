import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class ElevationService {
  ElevationService._();
  static final ElevationService instance = ElevationService._();

  final Map<String, double> _cache = {};
  bool _initialized = false;
  static const _fileName = 'trallzero_elevation_cache.json';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final file = await _cacheFile;
      if (await file.exists()) {
        final text = await file.readAsString();
        final data = json.decode(text) as Map<String, dynamic>;
        _cache.addAll(data.map((key, value) => MapEntry(key, (value as num).toDouble())));
      }
    } catch (_) {
      _cache.clear();
    }
    _initialized = true;
  }

  Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  String _key(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
  }

  Future<double?> _fetchPointElevation(LatLng point) async {
    final values = await _fetchElevations([point]);
    return values.isNotEmpty ? values.first : null;
  }

  Future<List<double>> _fetchElevations(List<LatLng> points) async {
    if (points.isEmpty) return [];

    final available = <double>[];
    final batches = <List<LatLng>>[];
    for (var i = 0; i < points.length; i += 20) {
      batches.add(points.sublist(i, i + 20 > points.length ? points.length : i + 20));
    }

    for (final batch in batches) {
      final query = batch.map((point) => '${point.latitude},${point.longitude}').join('|');
      final url = Uri.parse('https://api.open-elevation.com/api/v1/lookup?locations=$query');

      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.length == batch.length) {
            available.addAll(results.map((item) => (item['elevation'] as num).toDouble()));
            continue;
          }
        }
      } catch (_) {}

      // Fallback para OpenTopoData quando o OpenElevation não responde
      final geoUrl = Uri.parse('https://api.opentopodata.org/v1/srtm90m?locations=$query');
      try {
        final response = await http.get(geoUrl);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.length == batch.length) {
            available.addAll(results.map((item) => (item['elevation'] as num).toDouble()));
            continue;
          }
        }
      } catch (_) {}

      available.addAll(List<double>.filled(batch.length, 0.0));
    }

    return available;
  }

  Future<double> getElevation(LatLng point) async {
    await _ensureInitialized();
    final key = _key(point);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final value = await _fetchPointElevation(point) ?? 0.0;
    _cache[key] = value;
    await _saveCache();
    return value;
  }

  Future<List<double>> getElevations(List<LatLng> points) async {
    await _ensureInitialized();

    final elevations = <double>[];
    final missing = <LatLng>[];
    final missingIndexes = <int>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final key = _key(point);
      if (_cache.containsKey(key)) {
        elevations.add(_cache[key]!);
      } else {
        elevations.add(0.0);
        missing.add(point);
        missingIndexes.add(i);
      }
    }

    if (missing.isEmpty) {
      return elevations;
    }

    final fetched = await _fetchElevations(missing);
    for (var i = 0; i < fetched.length && i < missingIndexes.length; i++) {
      final index = missingIndexes[i];
      elevations[index] = fetched[i];
      _cache[_key(missing[i])] = fetched[i];
    }

    await _saveCache();
    return elevations;
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFile;
      await file.writeAsString(json.encode(_cache));
    } catch (_) {}
  }
}
