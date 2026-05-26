import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../models/marker_model.dart';
import '../models/road_analysis.dart';
import '../models/route_step.dart';
import '../models/truck_profile.dart';
import '../models/truck_route.dart';
import '../services/database_service.dart';
import '../services/road_analysis_service.dart';
import '../services/truck_profile_service.dart';
import '../services/tts_service.dart';

class TruckController extends ChangeNotifier {
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  final List<TruckerMarker> _customMarkers = [];
  List<TruckRoute> _availableRoutes = [];
  int _selectedRouteIndex = 0;

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
  bool _isNavigating = false;
  int _currentStepIndex = 0;

  bool _avoidTolls = false;
  bool _avoidFerries = false;
  bool _avoidUnpaved = false;

  // --- Alerta de Fadiga ---
  Timer? _drivingTimer;
  int _drivingSeconds = 0;
  bool _isFatigueAlertTriggered = false;
  static const int _fatigueLimitSeconds = 5 * 3600 + 30 * 60; // 5h30m (Lei 13.103)

  double _distance = 0;
  double _duration = 0;

  List<RoadSegmentAnalysis> _routeAnalysisSegments = [];
  List<RoadAnalysisFinding> _routeAnalysisFindings = [];
  RoadHazardLevel _routeRiskLevel = RoadHazardLevel.safe;

  List<String> _suggestions = [];

  LatLng? get destination => _destination;
  List<LatLng> get routePoints => _routePoints;
  List<TruckerMarker> get customMarkers => _customMarkers;
  bool get isRouting => _isRouting;
  bool get isNavigating => _isNavigating;
  List<String> get suggestions => _suggestions;
  List<RoadSegmentAnalysis> get routeAnalysisSegments => _routeAnalysisSegments;
  List<RoadAnalysisFinding> get routeAnalysisFindings => _routeAnalysisFindings;
  RoadHazardLevel get routeRiskLevel => _routeRiskLevel;
  TruckProfile get truckProfile => TruckProfileService.instance.currentProfile;
  List<TruckRoute> get availableRoutes => _availableRoutes;
  int get selectedRouteIndex => _selectedRouteIndex;

  bool get avoidTolls => _avoidTolls;
  bool get avoidFerries => _avoidFerries;
  bool get avoidUnpaved => _avoidUnpaved;

  int get drivingSeconds => _drivingSeconds;
  bool get hasFatigueAlert => _isFatigueAlertTriggered;

  String get formattedDrivingTime {
    final h = (_drivingSeconds / 3600).floor();
    final m = ((_drivingSeconds % 3600) / 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Próxima manobra da rota selecionada (null se não há steps)
  RouteStep? get nextStep {
    final route = _availableRoutes.isNotEmpty
        ? _availableRoutes[_selectedRouteIndex]
        : null;
    if (route == null || route.steps.isEmpty) return null;
    final idx = _currentStepIndex.clamp(0, route.steps.length - 1);
    return route.steps[idx];
  }

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

  String get formattedETA {
    if (_duration <= 0) return '';
    final arrival = DateTime.now().add(Duration(seconds: _duration.toInt()));
    final h = arrival.hour.toString().padLeft(2, '0');
    final m = arrival.minute.toString().padLeft(2, '0');
    return 'Chega às $h:$m';
  }

  void toggleAvoidTolls() {
    _avoidTolls = !_avoidTolls;
    if (_destination != null && _routePoints.isNotEmpty) {
      fetchRoute(_routePoints.first); // Recalcula rota do ponto atual
    }
    notifyListeners();
  }

  void toggleAvoidFerries() {
    _avoidFerries = !_avoidFerries;
    if (_destination != null && _routePoints.isNotEmpty) {
      fetchRoute(_routePoints.first);
    }
    notifyListeners();
  }

  void toggleAvoidUnpaved() {
    _avoidUnpaved = !_avoidUnpaved;
    if (_destination != null && _routePoints.isNotEmpty) {
      fetchRoute(_routePoints.first);
    }
    notifyListeners();
  }

  void toggleNavigation() {
    _isNavigating = !_isNavigating;
    if (_isNavigating) {
      _currentStepIndex = 0;
      _drivingSeconds = 0;
      _isFatigueAlertTriggered = false;
      
      final step = nextStep;
      if (step != null) {
        TtsService.instance.speak(
            'Navegação iniciada. Em ${step.distance.toInt()} metros, ${step.translatedManeuver}');
      } else {
        TtsService.instance.speak('Navegação iniciada.');
      }
      
      // Inicia o timer de fadiga
      _drivingTimer?.cancel();
      _drivingTimer = Timer.periodic(const Duration(seconds: 1), _onDrivingTick);
    } else {
      TtsService.instance.stop();
      _drivingTimer?.cancel();
    }
    notifyListeners();
  }

  void _onDrivingTick(Timer timer) {
    _drivingSeconds++;
    
    // Dispara alerta ao atingir o limite (5h30m)
    if (_drivingSeconds >= _fatigueLimitSeconds && !_isFatigueAlertTriggered) {
      _isFatigueAlertTriggered = true;
      TtsService.instance.speak(
        'Atenção motorista. Você atingiu o tempo limite de direção contínua estabelecido por lei. '
        'Por favor, procure um local seguro para descanso o mais rápido possível.'
      );
    }
    notifyListeners();
  }

  /// Avança para o próximo step quando o motorista passa pela manobra.
  /// Chamado pelo MapScreen a cada update de GPS.
  void updateCurrentStep(LatLng position) {
    final route = _availableRoutes.isNotEmpty
        ? _availableRoutes[_selectedRouteIndex]
        : null;
    if (route == null || route.steps.isEmpty) return;
    if (_currentStepIndex >= route.steps.length - 1) return;

    final nextManeuver = route.steps[_currentStepIndex];
    final dist = const Distance().as(
      LengthUnit.Meter,
      position,
      nextManeuver.location,
    );

    // Avança o step quando está a menos de 30m do ponto de manobra
    if (dist < 30) {
      _currentStepIndex++;
      
      final step = nextStep;
      if (step != null) {
        final phrase = 'Em ${step.distance.toInt()} metros, ${step.translatedManeuver}'
            '${step.streetName.isNotEmpty ? ' na ${step.streetName}' : ''}';
        TtsService.instance.speak(phrase);
      }
      
      notifyListeners();
    }
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
    _isNavigating = false;
    _currentStepIndex = 0;
    await fetchRoute(userLocation);
    notifyListeners();
  }

  /// Alterna para a próxima rota alternativa disponível
  void cycleRoute() {
    if (_availableRoutes.length <= 1) return;
    
    _selectedRouteIndex = (_selectedRouteIndex + 1) % _availableRoutes.length;
    final selected = _availableRoutes[_selectedRouteIndex];
    
    _routePoints = selected.points;
    _distance = selected.distance;
    _duration = selected.duration;
    _routeAnalysisSegments = selected.slopeSegments;
    _routeAnalysisFindings = selected.findings;
    _routeRiskLevel = selected.riskLevel;
    _currentStepIndex = 0;
    
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
      // Prepara os parâmetros de exclude (se o backend OSRM suportar custom profiles)
      final excludes = <String>[];
      if (_avoidTolls) excludes.add('toll');
      if (_avoidFerries) excludes.add('ferry');
      if (_avoidUnpaved) excludes.add('unpaved');
      
      final excludeParam = excludes.isNotEmpty ? '&exclude=${excludes.join(',')}' : '';

      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${_destination!.longitude},${_destination!.latitude}'
          '?overview=full&geometries=geojson&alternatives=true&steps=true$excludeParam';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List routesData = data['routes'] as List;
        
        final tempRoutes = <TruckRoute>[];
        for (final routeData in routesData) {
          final distance = routeData['distance'].toDouble();
          final duration = routeData['duration'].toDouble();
          final geometry = routeData['geometry']['coordinates'] as List;
          final points = geometry.map((coord) => LatLng(coord[1], coord[0])).toList();
          
          final slopeSegments = await RoadAnalysisService.instance.analyzeSlopeSegments(points, truckProfile);
          final findings = await RoadAnalysisService.instance.analyzeOsmRestrictions(points, truckProfile);
          final riskLevel = RoadAnalysisService.instance.getMaxSeverity(slopeSegments, findings);

          // Parseia os steps de manobra (vêm dentro de legs)
          final legs = routeData['legs'] as List<dynamic>? ?? [];
          final steps = <RouteStep>[];
          for (final leg in legs) {
            final legSteps = leg['steps'] as List<dynamic>? ?? [];
            steps.addAll(legSteps
                .map((s) => RouteStep.fromOsrm(s as Map<String, dynamic>)));
          }

          tempRoutes.add(TruckRoute(
            points: points,
            distance: distance,
            duration: duration,
            slopeSegments: slopeSegments,
            findings: findings,
            riskLevel: riskLevel,
            steps: steps,
          ));
        }

        if (tempRoutes.isNotEmpty) {
          // Sort alternatives to find the safest first.
          // Sorting criteria:
          // 1. Lower risk index (safer) first.
          // 2. Shorter duration first if risk level is equal.
          tempRoutes.sort((a, b) {
            final riskComparison = a.riskLevel.index.compareTo(b.riskLevel.index);
            if (riskComparison != 0) return riskComparison;
            return a.duration.compareTo(b.duration);
          });
          
          _availableRoutes = tempRoutes;
          _selectedRouteIndex = 0;
          
          _updateActiveRouteFields();
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar rotas: $e');
    } finally {
      _isRouting = false;
      notifyListeners();
    }
  }

  void _updateActiveRouteFields() {
    if (_availableRoutes.isEmpty) return;
    final active = _availableRoutes[_selectedRouteIndex];
    _distance = active.distance;
    _duration = active.duration;
    _routePoints = active.points;
    _routeAnalysisSegments = active.slopeSegments;
    _routeAnalysisFindings = active.findings;
    _routeRiskLevel = active.riskLevel;
  }

  void selectRoute(int index) {
    if (index < 0 || index >= _availableRoutes.length) return;
    _selectedRouteIndex = index;
    _updateActiveRouteFields();
    notifyListeners();
  }

  void clearRoute() {
    _destination = null;
    _routePoints = [];
    _routeAnalysisSegments = [];
    _routeAnalysisFindings = [];
    _routeRiskLevel = RoadHazardLevel.safe;
    _distance = 0;
    _duration = 0;
    _suggestions = [];
    _isNavigating = false;
    _availableRoutes = [];
    _selectedRouteIndex = 0;
    _currentStepIndex = 0;
    _drivingTimer?.cancel();
    _drivingSeconds = 0;
    _isFatigueAlertTriggered = false;
    notifyListeners();
  }

  Future<void> setTruckProfile(TruckProfile profile) async {
    TruckProfileService.instance.selectProfile(profile);
    notifyListeners();
    
    if (_availableRoutes.isNotEmpty) {
      _isRouting = true;
      notifyListeners();
      
      try {
        final reanalyzedRoutes = <TruckRoute>[];
        for (final r in _availableRoutes) {
          final slopeSegments = await RoadAnalysisService.instance.analyzeSlopeSegments(r.points, profile);
          final findings = await RoadAnalysisService.instance.analyzeOsmRestrictions(r.points, profile);
          final riskLevel = RoadAnalysisService.instance.getMaxSeverity(slopeSegments, findings);
          
          reanalyzedRoutes.add(TruckRoute(
            points: r.points,
            distance: r.distance,
            duration: r.duration,
            slopeSegments: slopeSegments,
            findings: findings,
            riskLevel: riskLevel,
          ));
        }
        
        // Re-sort/re-rank based on the new profile safety
        reanalyzedRoutes.sort((a, b) {
          final riskComparison = a.riskLevel.index.compareTo(b.riskLevel.index);
          if (riskComparison != 0) return riskComparison;
          return a.duration.compareTo(b.duration);
        });
        
        _availableRoutes = reanalyzedRoutes;
        _selectedRouteIndex = 0;
        _updateActiveRouteFields();
      } catch (e) {
        debugPrint('Erro ao reanalisar rotas após mudança de perfil: $e');
      } finally {
        _isRouting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _drivingTimer?.cancel();
    super.dispose();
  }
}
