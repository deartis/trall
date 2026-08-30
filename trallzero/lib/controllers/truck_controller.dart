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
import '../services/api_service.dart';
import '../services/cep_service.dart';
import '../services/preferences_service.dart';
import '../services/road_analysis_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/truck_profile_service.dart';
import '../services/tts_service.dart';
import '../services/poi_service.dart';

import '../models/delivery_stop.dart';
import '../widgets/recent_destinations.dart';


enum FatigueSeverity { none, warning, danger, critical }

/// Nível de precisão do último endereço geocodificado.
enum GeocodePrecision {
  /// Número predial localizado (ou busca sem número, ex.: rua/ponto de interesse).
  exact,

  /// Apenas um ponto aproximado na via — o número não foi encontrado nos dados.
  approximate,
}


class TruckController extends ChangeNotifier {
  List<DeliveryStop> _deliveryStops = [];
  List<LatLng> _routePoints = [];
  final List<TruckerMarker> _customMarkers = [];
  final List<TruckerMarker> _automaticPOIs = [];
  bool _isLoadingPOIs = false;
  List<TruckRoute> _availableRoutes = [];
  int _selectedRouteIndex = 0;

  TruckController() {
    _init();
  }

  Future<void> _init() async {
    await loadMarkers();
    await restoreRoute();
  }

  Future<void> loadMarkers() async {
    try {
      final markers = await ApiService.instance.fetchAlerts();
      _customMarkers.clear();
      _customMarkers.addAll(markers);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar marcadores da API: $e');
    }
  }
  bool _isRouting = false;
  bool _isNavigating = false;
  int _currentStepIndex = 0;

  LatLng? _lastKnownUserPosition;
  bool _hasSpoken500mAlert = false;
  bool _hasSpoken200mAlert = false;
  bool _hasSpokenImmediateAlert = false;

  void _resetStepVoiceAlertFlags() {
    _hasSpoken500mAlert = false;
    _hasSpoken200mAlert = false;
    _hasSpokenImmediateAlert = false;
  }

  bool _avoidTolls = false;
  bool _avoidFerries = false;
  bool _avoidUnpaved = false;

  // --- Alerta de Fadiga ---
  Timer? _drivingTimer;
  int _drivingSeconds = 0;
  bool _isFatigueAlertTriggered = false;
  DateTime? _fatigueStartedAt; // Timestamp do início da sessão de direção
  static const int _fatigueLimitSeconds = 5 * 3600 + 30 * 60; // 5h30m (Lei 13.103)

  double _distance = 0;
  double _duration = 0;

  List<RoadSegmentAnalysis> _routeAnalysisSegments = [];
  List<RoadAnalysisFinding> _routeAnalysisFindings = [];
  RoadHazardLevel _routeRiskLevel = RoadHazardLevel.safe;

  List<String> _suggestions = [];
  GeocodePrecision _lastSearchPrecision = GeocodePrecision.exact;

  List<DeliveryStop> get deliveryStops => _deliveryStops;
  LatLng? get destination => _deliveryStops.isNotEmpty ? LatLng(_deliveryStops.last.lat, _deliveryStops.last.lng) : null;
  List<LatLng> get routePoints => _routePoints;
  List<TruckerMarker> get customMarkers => _customMarkers;
  List<TruckerMarker> get automaticPOIs => _automaticPOIs;
  bool get isLoadingPOIs => _isLoadingPOIs;
  bool get isRouting => _isRouting;
  bool get isNavigating => _isNavigating;
  List<String> get suggestions => _suggestions;
  GeocodePrecision get lastSearchPrecision => _lastSearchPrecision;
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

  /// Nível de fadiga gradual baseado no tempo de direção contínua
  FatigueSeverity get fatigueSeverity {
    if (_drivingSeconds < 4 * 3600) return FatigueSeverity.none;       // < 4h
    if (_drivingSeconds < 5 * 3600) return FatigueSeverity.warning;    // 4h-5h
    if (_drivingSeconds < _fatigueLimitSeconds) return FatigueSeverity.danger; // 5h-5h30
    return FatigueSeverity.critical;                                    // > 5h30
  }

  /// Distância percorrida na rota atual em metros (para a RouteRiskBar)
  double get progressOnRouteMeters {
    if (_routePoints.isEmpty) return 0;
    return (_distance * (_currentStepIndex / 
        (_availableRoutes.isNotEmpty && _availableRoutes[_selectedRouteIndex].steps.isNotEmpty
          ? _availableRoutes[_selectedRouteIndex].steps.length
          : 1))).clamp(0.0, _distance);
  }

  /// Fração do percurso concluído [0.0, 1.0] — usada pela barra de progresso no HUD.
  double get routeProgressFraction {
    if (_availableRoutes.isEmpty) return 0.0;
    final route = _availableRoutes[_selectedRouteIndex];
    if (route.steps.isEmpty) return 0.0;
    return (_currentStepIndex / route.steps.length).clamp(0.0, 1.0);
  }


  String get formattedDrivingTime {
    final h = (_drivingSeconds / 3600).floor();
    final m = ((_drivingSeconds % 3600) / 60).floor();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Próxima manobra da rota selecionada (null se não há steps).
  /// Retorna a manobra que o motorista deve realizar a seguir.
  RouteStep? get nextStep {
    final route = _availableRoutes.isNotEmpty
        ? _availableRoutes[_selectedRouteIndex]
        : null;
    if (route == null || route.steps.isEmpty) return null;
    final upcomingIdx = (_currentStepIndex + 1 < route.steps.length)
        ? _currentStepIndex + 1
        : route.steps.length - 1;
    return route.steps[upcomingIdx];
  }

  /// Distância em metros da posição atual do motorista até a próxima manobra
  double? get distanceToNextStepMeters {
    final step = nextStep;
    if (step == null || _lastKnownUserPosition == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      _lastKnownUserPosition!,
      step.location,
    );
  }

  /// Distância formatada em tempo real para a próxima manobra ("350 m" / "1,2 km")
  String get formattedDistanceToNextStep {
    final dist = distanceToNextStepMeters;
    if (dist == null) {
      final step = nextStep;
      return step?.formattedDistance ?? '';
    }
    if (dist >= 1000) {
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
    return '${dist.toInt()} m';
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
    if (_deliveryStops.isNotEmpty && _routePoints.isNotEmpty) {
      fetchRoute(_routePoints.first); // Recalcula rota do ponto atual
    }
    notifyListeners();
  }

  void toggleAvoidFerries() {
    _avoidFerries = !_avoidFerries;
    if (_deliveryStops.isNotEmpty && _routePoints.isNotEmpty) {
      fetchRoute(_routePoints.first);
    }
    notifyListeners();
  }

  void toggleAvoidUnpaved() {
    _avoidUnpaved = !_avoidUnpaved;
    if (_deliveryStops.isNotEmpty && _routePoints.isNotEmpty) {
      fetchRoute(_routePoints.first);
    }
    notifyListeners();
  }

  void toggleNavigation() {
    _isNavigating = !_isNavigating;
    if (_isNavigating) {
      _currentStepIndex = 0;
      _resetStepVoiceAlertFlags();

      // Restaura segundos de fadiga persistidos (caso o app tenha fechado
      // enquanto o motorista estava dirigindo).
      _drivingSeconds = PreferencesService.instance.restoreFatigueSeconds();
      _fatigueStartedAt = DateTime.now();
      _isFatigueAlertTriggered = _drivingSeconds >= _fatigueLimitSeconds;

      final step = nextStep;
      if (step != null) {
        final distMeters = distanceToNextStepMeters?.toInt() ?? step.distance.toInt();
        final totalDistMeters = _distance.toInt();
        final street = step.streetName.isNotEmpty ? ' na ${step.streetName}' : '';

        if (step.type == 'arrive' || distMeters <= 20) {
          final distStr = totalDistMeters >= 1000
              ? '${(totalDistMeters / 1000).toStringAsFixed(1)} quilômetros'
              : '$totalDistMeters metros';
          TtsService.instance.speak(
            'Navegação iniciada. Siga em frente por $distStr até o seu destino$street.',
          );
        } else {
          final distStr = distMeters >= 1000
              ? '${(distMeters / 1000).toStringAsFixed(1)} quilômetros'
              : '$distMeters metros';
          TtsService.instance.speak(
            'Navegação iniciada. Em $distStr, ${step.translatedManeuver}$street.',
          );
        }

        if (distMeters <= 500) _hasSpoken500mAlert = true;
        if (distMeters <= 200) _hasSpoken200mAlert = true;
      } else {
        TtsService.instance.speak('Navegação iniciada.');
      }

      // Inicia o timer de fadiga
      _drivingTimer?.cancel();
      _drivingTimer = Timer.periodic(const Duration(seconds: 1), _onDrivingTick);

      // Inicia o serviço em segundo plano
      FlutterBackgroundService().startService();
    } else {
      TtsService.instance.stop();
      _drivingTimer?.cancel();

      // Desliga o serviço em segundo plano
      FlutterBackgroundService().invoke('stopService');
    }
    notifyListeners();
  }

  void _onDrivingTick(Timer timer) {
    _drivingSeconds++;

    // Persiste a cada 30 segundos para não sobrecarregar o I/O.
    // Se o app fechar entre dois saves, perde no máximo 30s — aceitável.
    if (_drivingSeconds % 30 == 0 && _fatigueStartedAt != null) {
      PreferencesService.instance.saveFatigueState(
        seconds: _drivingSeconds,
        startedAt: _fatigueStartedAt!,
      );
    }

    // Dispara alerta ao atingir o limite (5h30m)
    if (_drivingSeconds >= _fatigueLimitSeconds && !_isFatigueAlertTriggered) {
      _isFatigueAlertTriggered = true;
      TtsService.instance.speak(
        'Atenção motorista. Você atingiu o tempo limite de direção contínua estabelecido por lei. '
        'Por favor, procure um local seguro para descanso o mais rápido possível.',
      );
    }
    notifyListeners();
  }

  /// Avança para o próximo step quando o motorista passa pela manobra
  /// e gerencia os alertas sonoros em tempo real com antecedência adequada.
  /// Chamado pelo MapScreen a cada update de GPS.
  void updateCurrentStep(LatLng position, {double speed = 0.0}) {
    _lastKnownUserPosition = position;

    final route = _availableRoutes.isNotEmpty
        ? _availableRoutes[_selectedRouteIndex]
        : null;
    if (route == null || route.steps.isEmpty) return;
    if (_currentStepIndex >= route.steps.length - 1) return;

    final upcomingManeuver = nextStep;
    if (upcomingManeuver == null) return;

    final dist = const Distance().as(
      LengthUnit.Meter,
      position,
      upcomingManeuver.location,
    );

    // Threshold iminente ajustado dinamicamente pela velocidade
    // A >60 km/h (~16.6 m/s), avisa a 50m para dar tempo de reação. Em menor velocidade, 35m.
    final double immediateThreshold = (speed > 16.6) ? 50.0 : 35.0;

    // 1. Alerta de antecedência média (~500m)
    if (dist <= 600 && dist > 250 && !_hasSpoken500mAlert) {
      _hasSpoken500mAlert = true;
      final roundedDist = (dist ~/ 50) * 50;
      final street = upcomingManeuver.streetName.isNotEmpty
          ? ' na ${upcomingManeuver.streetName}'
          : '';
      TtsService.instance.speak(
        'Em $roundedDist metros, ${upcomingManeuver.translatedManeuver}$street',
      );
    }
    // 2. Alerta de proximidade (~150m-200m)
    else if (dist <= 200 && dist > immediateThreshold + 15 && !_hasSpoken200mAlert) {
      _hasSpoken200mAlert = true;
      final roundedDist = (dist ~/ 10) * 10;
      final street = upcomingManeuver.streetName.isNotEmpty
          ? ' na ${upcomingManeuver.streetName}'
          : '';
      TtsService.instance.speak(
        'Em $roundedDist metros, ${upcomingManeuver.translatedManeuver}$street',
      );
    }
    // 3. Alerta iminente ("Vire à esquerda agora")
    else if (dist <= immediateThreshold && dist > 15 && !_hasSpokenImmediateAlert) {
      _hasSpokenImmediateAlert = true;
      final street = upcomingManeuver.streetName.isNotEmpty
          ? ' na ${upcomingManeuver.streetName}'
          : '';
      TtsService.instance.speak(
        '${upcomingManeuver.translatedManeuver} agora$street',
      );
    }

    // Avança o step quando fica a 20m ou menos do ponto de manobra
    if (dist <= 20) {
      _currentStepIndex++;
      _resetStepVoiceAlertFlags();

      final newUpcoming = nextStep;
      if (newUpcoming != null && newUpcoming.type == 'arrive') {
        TtsService.instance.speak('Você está chegando ao seu destino.');
      }

      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUSCA DE ENDEREÇOS
  // ─────────────────────────────────────────────────────────────────────────

  static const _httpTimeout = Duration(seconds: 15);

  /// Busca sugestões de endereço.
  ///
  /// - Se [query] for um CEP (8 dígitos), consulta ViaCEP e retorna
  ///   o endereço formatado como sugestão única.
  /// - Caso contrário, usa Nominatim com viewbox (priorização por
  ///   proximidade, SEM bounded=1 que suprime resultados distantes).
  Future<void> fetchSuggestions(String query, {LatLng? userLocation}) async {
    if (query.length < 3) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    // ── Detecção de CEP ──────────────────────────────────────────
    if (CepService.isCep(query)) {
      try {
        final result = await CepService.lookup(query);
        if (result != null) {
          _suggestions = [result.formattedAddress];
          notifyListeners();
          return;
        }
      } catch (_) {}
      // Se falhar, deixa cair para o Nominatim normal
    }

    // ── Nominatim ────────────────────────────────────────────────
    try {
      final encodedQuery = Uri.encodeComponent(query);
      String url =
          'https://nominatim.openstreetmap.org/search'
          '?q=$encodedQuery&format=jsonv2&addressdetails=1&limit=6&countrycodes=br';

      if (userLocation != null) {
        // viewbox apenas PRIORIZA a região próxima — não bloqueia
        // resultados fora dela (diferente de bounded=1 que suprimia).
        final lat = userLocation.latitude;
        final lon = userLocation.longitude;
        const offset = 1.5; // ~150km em graus (raio maior = menos falsos negativos)
        final viewBox =
            '${lon - offset},${lat + offset},${lon + offset},${lat - offset}';
        url += '&viewbox=$viewBox';
      }

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'TrallApp/1.0'})
          .timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _suggestions =
            data.map((item) => item['display_name'] as String).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Search] Erro ao buscar sugestões: $e');
    }
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  /// Geocodifica [address] e configura como destino com precisão de número predial.
  ///
  /// Fluxo de alta precisão:
  ///   1. Se for CEP → ViaCEP + geocode direto (precisão aproximada)
  ///   2. Nominatim v2 → resultado com house_number compatível = exato
  ///   3. Geocoder nativo (Google/Apple) → interpola o número na via,
  ///      mesmo quando o OSM não tem o número mapeado
  ///   4. Photon API → fallback OSM com house_number
  ///   5. Ponto aproximado na rua (quando nada encontrou o número)
  ///
  /// Após a busca, [lastSearchPrecision] indica se o ponto é exato ou
  /// aproximado, permitindo avisar o motorista na interface.
  Future<LatLng?> searchAddress(String address, LatLng userLocation) async {
    LatLng? streetFallback; // melhor ponto aproximado de rua encontrado
    try {
      _isRouting = true;
      _suggestions = [];
      notifyListeners();

      const dist = Distance();

      Future<void> finish(
        LatLng point,
        GeocodePrecision precision, {
        String? recentLabel,
      }) async {
        _lastSearchPrecision = precision;
        if (precision == GeocodePrecision.approximate) {
          TtsService.instance.speak(
              'Atenção. Não encontrei o número exato. O destino está marcado em um ponto aproximado da via.');
        }
        await setDestination(point, userLocation);
        await RecentDestinations.saveDestination(recentLabel ?? address);
      }

      // ── 1. Tentativa via CEP ───────────────────────────────────
      if (CepService.isCep(address)) {
        final cepResult = await CepService.lookup(address);
        if (cepResult != null) {
          final coords = await CepService.geocode(cepResult);
          if (coords != null) {
            // CEP centra no trecho do logradouro, não no número
            final label =
                '${address.replaceAll(RegExp(r'[^\d]'), '').replaceRange(5, 8, '-')} — ${cepResult.shortAddress}';
            await finish(coords, GeocodePrecision.approximate, recentLabel: label);
            return coords;
          }
        }
      }

      final expectedNumber = extractHouseNumber(address);

      // ── 2. Nominatim: casa exata tem prioridade; rua fica de reserva ───
      try {
        final encoded = Uri.encodeComponent(address);
        final lat = userLocation.latitude;
        final lon = userLocation.longitude;
        const offset = 1.0;
        final viewBox =
            '${lon - offset},${lat + offset},${lon + offset},${lat - offset}';

        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=$encoded&format=jsonv2&addressdetails=1&limit=8&countrycodes=br'
          '&accept-language=pt-BR&viewbox=$viewBox',
        );
        final response = await http
            .get(uri, headers: {'User-Agent': 'TrallApp/1.0'})
            .timeout(_httpTimeout);

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          LatLng? exactPoint;
          double bestExactDist = double.infinity;

          for (final item in data) {
            final rLat = double.tryParse('${item['lat']}');
            final rLon = double.tryParse('${item['lon']}');
            if (rLat == null || rLon == null) continue;
            final p = LatLng(rLat, rLon);
            final addr = item['address'] as Map<String, dynamic>?;
            final hn =
                addr?['house_number']?.toString().replaceAll(RegExp(r'\D'), '');
            final d = dist.distance(userLocation, p);

            final isExactMatch = hn != null &&
                hn.isNotEmpty &&
                hn != '0' &&
                (expectedNumber == null || hn == expectedNumber);

            if (isExactMatch && d < bestExactDist) {
              bestExactDist = d;
              exactPoint = p;
            } else if (!isExactMatch && streetFallback == null) {
              streetFallback = p;
            }
          }

          if (exactPoint != null) {
            await finish(exactPoint, GeocodePrecision.exact);
            return exactPoint;
          }
        }
      } catch (e) {
        debugPrint('[Search] Nominatim falhou: $e');
      }

      // ── 3. Geocoder nativo: interpola números mesmo fora do OSM ───────
      final nativePoint = await _nativeGeocode(address);
      if (nativePoint != null) {
        // Confia no nativo quando concorda com a rua candidata, quando não
        // há candidato ou quando nenhuma casa foi digitada. Desacordo muito
        // grande sugere cidade errada — nesse caso mantém o ponto local.
        final agrees = expectedNumber == null ||
            streetFallback == null ||
            dist.distance(nativePoint, streetFallback) <= 30000;
        if (agrees) {
          await finish(nativePoint, GeocodePrecision.exact);
          return nativePoint;
        }
        debugPrint('[Search] Nativo diverge do candidato OSM; usando ponto local.');
      }

      // ── 4. Fallback: Photon API (Geocoding de alta precisão OSM) ───────
      try {
        final encoded = Uri.encodeComponent(address);
        final uri = Uri.parse(
          'https://photon.komoot.io/api/?q=$encoded&lat=${userLocation.latitude}&lon=${userLocation.longitude}&limit=5&lang=pt',
        );
        final response = await http.get(uri).timeout(_httpTimeout);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? [];

          Map<String, dynamic>? exactFeature;
          for (final feat in features) {
            final props = feat['properties'] as Map<String, dynamic>?;
            final hn = props?['housenumber']
                ?.toString()
                .replaceAll(RegExp(r'\D'), '');
            if (hn != null &&
                hn.isNotEmpty &&
                (expectedNumber == null || hn == expectedNumber)) {
              exactFeature = feat as Map<String, dynamic>;
              break;
            }
          }

          final selected = exactFeature ??
              (features.isNotEmpty ? features.first as Map<String, dynamic> : null);
          if (selected != null) {
            final coords =
                selected['geometry']['coordinates'] as List<dynamic>;
            final point = LatLng(
                (coords[1] as num).toDouble(), (coords[0] as num).toDouble());
            if (exactFeature != null) {
              await finish(point, GeocodePrecision.exact);
              return point;
            }
            streetFallback ??= point;
          }
        }
      } catch (e) {
        debugPrint('[Search] Photon API falhou: $e');
      }

      // ── 5. Último recurso: ponto aproximado na rua ────────────────────
      if (streetFallback != null) {
        await finish(streetFallback, GeocodePrecision.approximate);
        return streetFallback;
      }

      debugPrint('[Search] Endereço não encontrado: $address');
    } catch (e) {
      debugPrint('[Search] Erro geral na busca de endereço: $e');
    } finally {
      _isRouting = false;
      notifyListeners();
    }
    return null;
  }

  /// Extrai o número predial digitado no fim do endereço ("Rua Europa 74" → "74").
  static String? extractHouseNumber(String address) {
    final t = address.trim();
    Match? m = RegExp(r'(\d{1,5})\s*[a-zA-Z]{0,2}$').firstMatch(t);
    m ??= RegExp(r'[,-]\s*n?[°º]?\s*(\d{1,5})').firstMatch(t);
    return m?.group(1);
  }

  /// Consulta o geocoder nativo da plataforma (Google Play Services no
  /// Android / Apple no iOS), que interpola o número ao longo da via.
  Future<LatLng?> _nativeGeocode(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint('[Search] Geocoder nativo falhou: $e');
    }
    return null;
  }

  Future<void> setDestination(LatLng point, LatLng userLocation) async {
    final stop = DeliveryStop(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recipientName: 'Destino Rápido',
      address: 'Ponto selecionado',
      lat: point.latitude,
      lng: point.longitude,
    );
    await setDeliveryStops([stop], userLocation);
  }

  Future<void> setDeliveryStops(List<DeliveryStop> stops, LatLng userLocation,
      {bool fromRestore = false}) async {
    _deliveryStops = stops;
    _isNavigating = false;
    _currentStepIndex = 0;
    await fetchRoute(userLocation);

    // Salva na nuvem somente quando o motorista criou (não restaurando)
    if (!fromRestore) {
      final savedStops = await ApiService.instance.saveRoute(
        stops.map((s) => s.toApiJson()).toList(),
        truckProfile.type.name,
      );
      // Atualiza as paradas com os IDs reais do banco
      if (savedStops != null) {
        _deliveryStops = savedStops
            .map((json) => DeliveryStop.fromApiJson(json))
            .toList();
      }
    }

    notifyListeners();
  }

  /// Tenta restaurar silenciosamente a rota ativa do banco.
  Future<void> restoreRoute() async {
    try {
      final stopsJson = await ApiService.instance.fetchActiveRoute();
      if (stopsJson == null || stopsJson.isEmpty) return;

      final stops = stopsJson.map((j) => DeliveryStop.fromApiJson(j)).toList();

      // Calcula o ponto de início como a primeira parada não concluída
      final firstPending = stops.firstWhere(
        (s) => !s.isCompleted,
        orElse: () => stops.first,
      );
      final startLoc = LatLng(firstPending.lat, firstPending.lng);

      _deliveryStops = stops;
      _isNavigating = false;
      _currentStepIndex = 0;
      await fetchRoute(startLoc);
      notifyListeners();
      debugPrint('Rota restaurada com ${stops.length} paradas.');
    } catch (e) {
      debugPrint('Erro ao restaurar rota: $e');
    }
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

  Future<void> addMarker(
    LatLng point,
    MarkerType type,
    String description, {
    double? heading,
  }) async {
    final marker = TruckerMarker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: point,
      type: type,
      description: description,
      heading: heading,
      confirmations: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final success = await ApiService.instance.postAlert(marker);
      if (success) {
        _customMarkers.add(marker);
        notifyListeners();
      } else {
        // Salva localmente mesmo se a API estiver em mock ou offline
        _customMarkers.add(marker);
        notifyListeners();
        debugPrint('Aviso: Marcador adicionado localmente (API offline)');
      }
    } catch (e) {
      _customMarkers.add(marker);
      notifyListeners();
      debugPrint('Erro ao enviar marcador para API: $e (salvo localmente)');
    }
  }

  /// Confirma que um alerta ainda está ativo no local (Padrão Waze / Upvote)
  Future<bool> confirmMarker(String id) async {
    final idx = _customMarkers.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final m = _customMarkers[idx];
      _customMarkers[idx] = m.copyWith(
        confirmations: m.confirmations + 1,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    }

    final autoIdx = _automaticPOIs.indexWhere((m) => m.id == id);
    if (autoIdx != -1) {
      final m = _automaticPOIs[autoIdx];
      _automaticPOIs[autoIdx] = m.copyWith(
        confirmations: m.confirmations + 1,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Substitui um alerta existente por um novo tipo (Resolução de Conflito)
  Future<void> replaceMarker(
    String oldId,
    LatLng point,
    MarkerType newType,
    String description, {
    double? heading,
  }) async {
    await removeMarker(oldId);
    await addMarker(point, newType, description, heading: heading);
  }

  Future<void> removeMarker(String id) async {
    try {
      final success = await ApiService.instance.deleteAlert(id);
      if (success) {
        _customMarkers.removeWhere((m) => m.id == id);
        notifyListeners();
      } else {
        // Remove localmente se a API não estiver disponível
        _customMarkers.removeWhere((m) => m.id == id);
        notifyListeners();
        debugPrint('Aviso: Marcador $id removido localmente');
      }
    } catch (e) {
      _customMarkers.removeWhere((m) => m.id == id);
      notifyListeners();
      debugPrint('Erro ao deletar marcador: $e (removido localmente)');
    }
  }

  Future<bool> fetchRoute(LatLng start) async {
    if (_deliveryStops.isEmpty) return false;

    _isRouting = true;
    notifyListeners();

    try {
      // Prepara os parâmetros de exclude (se o backend OSRM suportar custom profiles)
      final excludes = <String>[];
      if (_avoidTolls) excludes.add('toll');
      if (_avoidFerries) excludes.add('ferry');
      if (_avoidUnpaved) excludes.add('unpaved');
      
      final excludeParam = excludes.isNotEmpty ? '&exclude=${excludes.join(',')}' : '';

      String coordinates = '${start.longitude},${start.latitude}';
      for (var stop in _deliveryStops) {
        coordinates += ';${stop.lng},${stop.lat}';
      }

      final url = 'https://router.project-osrm.org/route/v1/driving/$coordinates'
          '?overview=full&geometries=geojson&alternatives=true&steps=true$excludeParam';

      final response = await http
          .get(Uri.parse(url))
          .timeout(_httpTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List routesData = data['routes'] as List;
        
        final tempRoutes = <TruckRoute>[];
        for (final routeData in routesData) {
          final distance = routeData['distance'].toDouble();
          final duration = routeData['duration'].toDouble();
          final geometry = routeData['geometry']['coordinates'] as List;
          final points = geometry.map((coord) => LatLng(coord[1], coord[0])).toList();
          
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
            slopeSegments: [],
            findings: [],
            riskLevel: RoadHazardLevel.safe,
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
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Erro ao buscar rotas: $e');
      return false;
    } finally {
      _isRouting = false;
      notifyListeners();
      
      if (_availableRoutes.isNotEmpty) {
        _runBackgroundAnalysis();
      }
    }
  }

  Future<void> _runBackgroundAnalysis() async {
    try {
      final reanalyzedRoutes = <TruckRoute>[];
      for (final r in _availableRoutes) {
        final slopeSegments = await RoadAnalysisService.instance.analyzeSlopeSegments(r.points, truckProfile);
        final findings = await RoadAnalysisService.instance.analyzeOsmRestrictions(r.points, truckProfile);
        final riskLevel = RoadAnalysisService.instance.getMaxSeverity(slopeSegments, findings);
        
        reanalyzedRoutes.add(TruckRoute(
          points: r.points,
          distance: r.distance,
          duration: r.duration,
          slopeSegments: slopeSegments,
          findings: findings,
          riskLevel: riskLevel,
          steps: r.steps,
        ));
      }
      
      // Re-ordena as rotas agora com base no risco real calculado
      reanalyzedRoutes.sort((a, b) {
        final riskComparison = a.riskLevel.index.compareTo(b.riskLevel.index);
        if (riskComparison != 0) return riskComparison;
        return a.duration.compareTo(b.duration);
      });
      
      _availableRoutes = reanalyzedRoutes;
      _updateActiveRouteFields();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro na análise de background: $e');
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

  Future<void> endRoute() async {
    // Encerra no banco antes de limpar o estado local
    await ApiService.instance.clearActiveRoute();
    clearRoute();
  }

  void clearRoute() {
    _deliveryStops.clear();
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
    _fatigueStartedAt = null;
    _isFatigueAlertTriggered = false;
    // Desliga o serviço em segundo plano
    FlutterBackgroundService().invoke('stopService');
    // Limpa o estado persistido ao encerrar a rota conscientemente
    PreferencesService.instance.clearFatigueState();
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

  Future<void> findNearbyPOIs(LatLng currentPos) async {
    _isLoadingPOIs = true;
    notifyListeners();

    try {
      final pois = await PoiService.fetchPOIsAround(currentPos, radius: 5000); // 5km raio
      if (pois != null) {
        _automaticPOIs.clear();
        _automaticPOIs.addAll(pois);
      }
    } catch (e) {
      debugPrint('Erro ao buscar POIs automáticos: \$e');
    } finally {
      _isLoadingPOIs = false;
      notifyListeners();
    }
  }

  /// Busca POIs de um tipo específico e mescla com os já exibidos no mapa.
  Future<void> findNearbyPOIsByType(LatLng currentPos, MarkerType type) async {
    _isLoadingPOIs = true;
    notifyListeners();

    try {
      final pois = await PoiService.fetchPOIsByType(currentPos, type, radius: 8000);
      if (pois != null) {
        // Remove POIs do mesmo tipo para evitar duplicatas e depois re-adiciona
        _automaticPOIs.removeWhere((m) => m.type == type && m.id.startsWith('osm_'));
        _automaticPOIs.addAll(pois);
      }
    } catch (e) {
      debugPrint('Erro ao buscar POIs por tipo: $e');
    } finally {
      _isLoadingPOIs = false;
      notifyListeners();
    }
  }

  void clearAutomaticPOIs() {
    _automaticPOIs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _drivingTimer?.cancel();
    super.dispose();
  }
}
