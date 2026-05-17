import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../models/marker_model.dart';
import '../services/database_service.dart';

class TruckController extends ChangeNotifier {
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  final List<TruckerMarker> _customMarkers = [];

  TruckController() {
    loadMarkers();
  }

  Future<void> loadMarkers() async {
    try {
      final markers = await DatabaseService.instance.getAllMarkers();
      _customMarkers.clear();
      _customMarkers.addAll(markers);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar marcadores do banco: $e');
    }
  }
  bool _isRouting = false;
  bool _isNavigating = false; // Estado de navegação ativa
  
  double _distance = 0;
  double _duration = 0;

  List<String> _suggestions = [];

  LatLng? get destination => _destination;
  List<LatLng> get routePoints => _routePoints;
  List<TruckerMarker> get customMarkers => _customMarkers;
  bool get isRouting => _isRouting;
  bool get isNavigating => _isNavigating;
  List<String> get suggestions => _suggestions;
  
  String get formattedDistance {
    if (_distance >= 1000) return '${(_distance / 1000).toStringAsFixed(1)} km';
    return '${_distance.toInt()} m';
  }

  String get formattedDuration {
    if (_duration >= 3600) {
      int hours = (_duration / 3600).floor();
      int minutes = ((_duration % 3600) / 60).floor();
      return '${hours}h ${minutes}min';
    }
    return '${(_duration / 60).floor()} min';
  }

  void toggleNavigation() {
    _isNavigating = !_isNavigating;
    notifyListeners();
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.length < 3) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    try {
      final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'TrallZeroApp'});
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _suggestions = data.map((item) => item['display_name'] as String).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao buscar sugestões: $e');
    }
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  Future<LatLng?> searchAddress(String address, LatLng userLocation) async {
    try {
      _isRouting = true;
      _suggestions = [];
      notifyListeners();

      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final point = LatLng(locations.first.latitude, locations.first.longitude);
        await setDestination(point, userLocation);
        return point;
      }
    } catch (e) {
      debugPrint('Erro na busca de endereço: $e');
    } finally {
      _isRouting = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> setDestination(LatLng point, LatLng userLocation) async {
    _destination = point;
    _isNavigating = false; // Reset navigation when setting new destination
    await fetchRoute(userLocation);
    notifyListeners();
  }

  Future<void> addMarker(LatLng point, MarkerType type, String description) async {
    final marker = TruckerMarker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: point,
      type: type,
      description: description,
    );

    try {
      await DatabaseService.instance.insertMarker(marker);
      _customMarkers.add(marker);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao salvar marcador no banco: $e');
    }
  }

  Future<void> removeMarker(String id) async {
    try {
      await DatabaseService.instance.deleteMarker(id);
      _customMarkers.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao deletar marcador no banco: $e');
    }
  }

  Future<void> fetchRoute(LatLng start) async {
    if (_destination == null) return;

    _isRouting = true;
    notifyListeners();

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${_destination!.longitude},${_destination!.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        _distance = route['distance'].toDouble();
        _duration = route['duration'].toDouble();
        final geometry = route['geometry']['coordinates'] as List;
        _routePoints = geometry.map((coord) => LatLng(coord[1], coord[0])).toList();
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota: $e');
    } finally {
      _isRouting = false;
      notifyListeners();
    }
  }

  void clearRoute() {
    _destination = null;
    _routePoints = [];
    _distance = 0;
    _duration = 0;
    _suggestions = [];
    _isNavigating = false;
    notifyListeners();
  }
}
