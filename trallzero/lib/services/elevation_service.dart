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

  Future<List<double?>> _fetchElevations(List<LatLng> points) async {
    if (points.isEmpty) return [];

    final available = <double?>[];
    final batches = <List<LatLng>>[];
    for (var i = 0; i < points.length; i += 20) {
      batches.add(points.sublist(i, i + 20 > points.length ? points.length : i + 20));
    }

    for (final batch in batches) {
      final query = batch.map((point) => '${point.latitude},${point.longitude}').join('|');
      final url = Uri.parse('https://api.open-elevation.com/api/v1/lookup?locations=$query');

      var fetched = false;
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.length == batch.length) {
            available.addAll(results.map((item) => (item['elevation'] as num?)?.toDouble()));
            fetched = true;
          }
        }
      } catch (_) {}

      if (fetched) continue;

      // Fallback para OpenTopoData quando o OpenElevation não responde
      final geoUrl = Uri.parse('https://api.opentopodata.org/v1/srtm90m?locations=$query');
      try {
        final response = await http.get(geoUrl).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.length == batch.length) {
            available.addAll(results.map((item) => (item['elevation'] as num?)?.toDouble()));
            fetched = true;
          }
        }
      } catch (_) {}

      if (!fetched) {
        available.addAll(List<double?>.filled(batch.length, null));
      }
    }

    return available;
  }

  Future<double> getElevation(LatLng point) async {
    await _ensureInitialized();
    final key = _key(point);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final value = await _fetchPointElevation(point);
    if (value != null) {
      _cache[key] = value;
      await _saveCache();
      return value;
    }
    return 0.0;
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
        elevations.add(double.nan);
        missing.add(point);
        missingIndexes.add(i);
      }
    }

    if (missing.isNotEmpty) {
      final fetched = await _fetchElevations(missing);
      for (var i = 0; i < fetched.length && i < missingIndexes.length; i++) {
        final val = fetched[i];
        if (val != null) {
          elevations[missingIndexes[i]] = val;
          _cache[_key(missing[i])] = val;
        }
      }
      await _saveCache();
    }

    // Interpolar valores ausentes para evitar penhascos artificiais de 0.0m
    _interpolateMissing(elevations);
    return elevations;
  }

  void _interpolateMissing(List<double> list) {
    if (list.isEmpty) return;

    var firstValid = -1;
    for (var i = 0; i < list.length; i++) {
      if (!list[i].isNaN) {
        firstValid = i;
        break;
      }
    }

    // Se nenhum valor for válido, preenche com 0.0 constante (plano, sem falsos desníveis)
    if (firstValid == -1) {
      for (var i = 0; i < list.length; i++) {
        list[i] = 0.0;
      }
      return;
    }

    // Preenche início se faltante
    for (var i = 0; i < firstValid; i++) {
      list[i] = list[firstValid];
    }

    // Interpola o meio e preenche o fim
    for (var i = firstValid + 1; i < list.length; i++) {
      if (list[i].isNaN) {
        var nextValid = -1;
        for (var j = i + 1; j < list.length; j++) {
          if (!list[j].isNaN) {
            nextValid = j;
            break;
          }
        }

        if (nextValid != -1) {
          final startVal = list[i - 1];
          final endVal = list[nextValid];
          final steps = nextValid - (i - 1);
          for (var k = i; k < nextValid; k++) {
            final factor = (k - (i - 1)) / steps;
            list[k] = startVal + (endVal - startVal) * factor;
          }
          i = nextValid;
        } else {
          for (var k = i; k < list.length; k++) {
            list[k] = list[i - 1];
          }
          break;
        }
      }
    }
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFile;
      await file.writeAsString(json.encode(_cache));
    } catch (_) {}
  }
}
