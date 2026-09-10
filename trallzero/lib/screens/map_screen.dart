import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_snackbar.dart';
import '../services/location_service.dart';
import '../services/ocr_service.dart';
import '../widgets/navigation_marker.dart';
import '../widgets/proactive_alert_hud.dart';
import '../widgets/restriction_alert_hud.dart';
import '../widgets/highway_corridor_timeline.dart';
import '../widgets/slope_and_roll_warning_hud.dart';
import '../widgets/docking_arrival_card.dart';
import '../controllers/truck_controller.dart';
import '../models/marker_model.dart';
import '../models/truck_profile.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/maneuver_hud.dart';
import '../widgets/map_ui_extras.dart';
import '../models/delivery_stop.dart';
import '../services/preferences_service.dart';
import '../services/marker_deduplication_service.dart';
import '../widgets/marker_conflict_sheet.dart';
import '../services/user_score_service.dart';
import '../widgets/score_earned_overlay.dart';
import '../models/user_rank.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

// ============================================================
// COMO FUNCIONA A ROTAÇÃO:
//
//   1. O MAPA rotaciona para que a direção do aparelho fique
//      apontando para o TOPO da tela (idêntico ao Waze).
//
//   2. A SETA (NavigationMarker) fica sempre fixa apontando
//      para o TOPO (rotate: true no Marker).
//
//   3. Fonte do heading:
//      - BÚSSOLA: fonte principal. Funciona parado.
//      - GPS: fallback quando sem bússola ou em movimento >1.5m/s.
//
//   4. Follow mode:
//      - true  → câmera segue o veículo e o mapa rotaciona.
//      - false → câmera livre (usuário arrastou o mapa).
// ============================================================

/// Chave de API opcional para tiles de alta resolução do CartoDB Dark Matter.
/// Obtenha uma chave gratuita (5 milhões reqs/mês) em: https://carto.com/basemaps/apikey
/// Deixe vazia para usar o OpenStreetMap oficial com Dark Mode sem exigir chave de API.
const String kCartoApiKey = '';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final LatLng _initialCenter = const LatLng(-22.9068, -43.1729);

  LatLng? _currentPosition;
  // Posição suave renderizada no mapa. ValueNotifier para que o marker do
  // veículo seja reconstruído SEM disparar rebuild de 60fps da tela inteira.
  final ValueNotifier<LatLng?> _animatedPositionNotifier = ValueNotifier<LatLng?>(null);
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Timer? _debounce;

  // --- Animação da câmera (suavizada e adaptativa) ---
  AnimationController? _cameraAnimationController;
  LatLngTween? _latLngTween;
  Tween<double>? _rotationTween;
  Tween<double>? _zoomTween;
  Animation<double>? _activeAnimation; // Animação ativa com suporte a curvas
  DateTime? _lastGpsUpdateTime; // Timestamp para medir o intervalo real do GPS
  Duration _animationDuration = const Duration(
    milliseconds: 900,
  ); // Duração adaptativa

  // Banda de zoom atual — histerese evita "respiração" (16.5↔17.0) quando a
  // velocidade oscila em torno dos limiares 13/22 km/h.
  double? _zoomBand;

  // --- Animação dedicada do marcador do veículo (independente da câmera) ---
  // Separada para que reset() da câmera não cause stuttering no ícone do truck.
  AnimationController? _vehicleAnimController;
  LatLngTween? _vehicleLatLngTween;

  // --- Heading ---
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0.0);
  double _heading = 0;
  double _lastKnownSpeed = 0;
  Timer? _compassCheckTimer;

  // --- Sensor de Bússola & Orientação ---
  double? _lastCompassRawValue;
  bool _compassAvailable = false;
  LatLng? _lastBearingGpsPosition;

  // --- Follow mode e FullScreen ---
  bool _isFollowMode = true;
  final bool _isFullScreen = false;

  // --- Zoom atual (para ocultar marcadores no zoom out) ---
  double _currentZoom = 13.0;
  static const double _markerVisibilityZoom = 12.0;

  // --- OCR ---
  bool _isOcrLoading = false;

  // --- Precisão GPS (para indicador de sinal) ---
  double _gpsAccuracy = 999.0; // metros; inicia alto ("sem sinal")

  // --- Banner de navegação iniciada ---
  bool _showNavBanner = false;
  Timer? _navBannerTimer;

  // --- RepaintBoundary key (compartilhar rota) ---
  final GlobalKey _mapRepaintKey = GlobalKey();

  // --- Recálculo de Rota Automático (Rerouting) ---
  int _offRouteCount = 0;
  bool _isRecalculating = false;
  bool _showReroutingBanner = false;

  // --- Alertas sonoros de marcadores (estilo Waze) ---
  // IDs de marcadores cujo aviso de voz já foi disparado nesta passagem
  final Set<String> _announcedMarkerIds = {};
  // IDs de marcadores que o usuário já passou (< 80 m) → permite reanunciar ao voltar
  final Set<String> _markerPassedIds = {};

  // --- Altura atual do NavigationPanel (para evitar sobreposição dos botões) ---
  // Vai de 0.0 (sem painel) ao fractal do DraggableScrollableSheet
  final ValueNotifier<double> _panelSizeNotifier = ValueNotifier<double>(0.0);

  // ─────────────────────────────────────────────────────────────────────────
  //  CICLO DE VIDA
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Mantém a tela acesa enquanto o GPS estiver ativo
    WakelockPlus.enable();

    _searchController.addListener(_onSearchChanged);

    // Duração inicial de 900ms para corresponder às atualizações do GPS (1s)
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Controller dedicado ao marcador do veículo — completamente independente
    // da câmera. Nunca sofre reset() abrupto, eliminando o efeito anda-e-para.
    _vehicleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _vehicleAnimController!.addListener(() {
      if (!mounted || _vehicleLatLngTween == null) return;
      final t = Curves.easeOutCubic.transform(_vehicleAnimController!.value);
      final pos = _vehicleLatLngTween!.transform(t);
      _animatedPositionNotifier.value = pos;
    });

    _cameraAnimationController!.addListener(() {
      if (!mounted || _activeAnimation == null) return;

      final anim = _activeAnimation!;

      if (_latLngTween == null || _zoomTween == null) {
        return;
      }

      final currentPos = _latLngTween!.evaluate(anim);
      final currentZoom = _zoomTween!.evaluate(anim);

      if (_rotationTween != null) {
        final currentRot = _rotationTween!.evaluate(anim);
        _mapController.moveAndRotate(currentPos, currentZoom, currentRot);
      } else if (_isFollowMode) {
        _mapController.moveAndRotate(currentPos, currentZoom, -_heading);
      }
    });

    _cameraAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _rotationTween = null;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _mapController.rotate(0);
      _startCompassUpdates();
    });

    _initLocation();
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Libera o wakelock ao sair da tela
    _positionStream?.cancel();
    _compassStream?.cancel();
    _compassCheckTimer?.cancel();
    _navBannerTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _cameraAnimationController?.dispose();
    _vehicleAnimController?.dispose();
    _headingNotifier.dispose();
    _animatedPositionNotifier.dispose();
    _panelSizeNotifier.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LOCALIZAÇÃO (GPS)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final hasPermission = await LocationService.handlePermission();
    if (!hasPermission) return;
    await _fetchInitialPosition();
    _startLocationUpdates();
  }

  Future<void> _fetchInitialPosition() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;

      final pos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = pos;
        _animatedPositionNotifier.value = pos;
        _lastKnownSpeed = _safeSpeed(position);
      });

      try {
        _mapController.move(pos, 16);
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(pos, 16);
            } catch (_) {}
          }
        });
      }
    } catch (e) {
      debugPrint('[GPS] Erro na posição inicial: $e');
    }
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = LocationService.getPositionStream().listen((position) {
      if (!mounted) return;

      final rawPos = LatLng(position.latitude, position.longitude);
      var newPos = rawPos;
      final truckController = context.read<TruckController>();
      final speed = _safeSpeed(position);

      if (truckController.isNavigating &&
          truckController.routePoints.isNotEmpty) {
        // Projeção no SEGMENTO mais próximo (em vez de vértice mais próximo).
        // Isso garante movimento suave em curvas, eliminando o efeito de parar/pular.
        final (snappedPos, minDist, segmentIndex) = _snapToRouteSegment(
          rawPos,
          truckController.routePoints,
        );
        const double snappingThreshold = 35.0;

        if (minDist < snappingThreshold) {
          newPos = snappedPos;
          _offRouteCount = 0;
          truckController.updateCurrentStep(
            newPos,
            speed: speed,
            segmentIndex: segmentIndex,
          ); // avança manobra e gerencia alertas de voz
        } else {
          if (position.accuracy <= 20.0) {
            _offRouteCount++;
            if (_offRouteCount >= 3 && !_isRecalculating) {
              _triggerReroute(rawPos, truckController);
            }
          } else {
            debugPrint(
              '[Rerouting] Desvio ignorado devido a baixa precisão do GPS: ${position.accuracy}m',
            );
          }
        }
      }

      // --- Cálculo da Duração Dinâmica Adaptativa ---
      // Cobre TODO o intervalo do GPS (fator ~1.05) para a animação terminar
      // exatamente quando o próximo update chegar — elimina a lacuna de freeze.
      final now = DateTime.now();
      if (_lastGpsUpdateTime != null) {
        final elapsed = now.difference(_lastGpsUpdateTime!);
        if (elapsed.inMilliseconds >= 150 && elapsed.inMilliseconds <= 2500) {
          _animationDuration = Duration(
            milliseconds: (elapsed.inMilliseconds * 1.05)
                .clamp(250, 900)
                .round(),
          );
        } else {
          _animationDuration = const Duration(milliseconds: 800);
        }
      }
      _lastGpsUpdateTime = now;

      // Captura PRIMEIRO a posição visualmente renderizada (antes de qualquer setState)
      // para que o novo tween comece exatamente onde a seta está na tela agora.
      final livePos = _animatedPositionNotifier.value ?? _currentPosition ?? newPos;

      setState(() {
        _currentPosition = newPos;
        _lastKnownSpeed = speed;
        _gpsAccuracy = position.accuracy;
      });

      // ── Alertas sonoros de marcadores (estilo Waze) ───────────────────────
      _checkMarkerProximityAlerts(
        newPos,
        [...truckController.customMarkers, ...truckController.automaticPOIs],
        speed,
      );

      final gpsHeading = _safeGpsHeading(position);
      final bool useGpsHeading =
          gpsHeading != null && (speed >= 1.0 || !_compassAvailable);

      if (useGpsHeading) {
        _heading = _smoothAngle(_heading, gpsHeading, factor: 0.85);
        _headingNotifier.value = _heading;
        _lastBearingGpsPosition = newPos;
      } else if (!_compassAvailable) {
        // Aparelhos sem magnetômetro: calcula direção pelo deslocamento ao caminhar
        if (_lastBearingGpsPosition != null) {
          final distMoved = const Distance().as(
            LengthUnit.Meter,
            _lastBearingGpsPosition!,
            newPos,
          );
          if (distMoved >= 1.5) {
            final walkBearing = const Distance().bearing(
              _lastBearingGpsPosition!,
              newPos,
            );
            _heading = _smoothAngle(_heading, walkBearing, factor: 0.85);
            _headingNotifier.value = _heading;
            _lastBearingGpsPosition = newPos;
          }
        } else {
          _lastBearingGpsPosition = newPos;
        }
      }

      // Animação contínua do marcador do veículo:
      // Usamos forward(from: 0) que interrompe internamente qualquer animação
      // anterior SEM chamar stop() antes — isso evita o frame de freeze que
      // acontecia quando stop() zerava a posição antes do novo tween ser definido.
      _vehicleLatLngTween = LatLngTween(begin: livePos, end: newPos);
      _vehicleAnimController?.duration = _animationDuration;
      _vehicleAnimController?.forward(from: 0.0);

      if (_isFollowMode) {
        final double targetZoom;
        final LatLng targetCenter;

        if (truckController.isNavigating) {
          // Histerese de ~2 km/h: mantém a banda atual até a velocidade cruzar
          // o limiar com margem, evitando o vai-e-vem de zoom (respiração).
          if (_zoomBand == null) {
            targetZoom = speed > 22 ? 15.5 : (speed > 13 ? 16.5 : 17.0);
          } else if (_zoomBand == 17.0) {
            targetZoom = speed > 15.0 ? 16.5 : 17.0;
          } else if (_zoomBand == 15.5) {
            targetZoom = speed < 15.0 ? 16.5 : 15.5;
          } else {
            targetZoom = speed > 22.0 ? 15.5 : (speed < 13.0 ? 17.0 : 16.5);
          }
          _zoomBand = targetZoom;

          final double lookAheadMeters = (180 * math.pow(2, 17 - targetZoom))
              .toDouble();
          targetCenter = _projectPosition(newPos, _heading, lookAheadMeters);
        } else {
          double tempZoom = 16.5;
          try {
            tempZoom = _mapController.camera.zoom;
          } catch (_) {}
          targetZoom = tempZoom;
          // Lookahead sutil para manter visão da rua à frente no sentido de deslocamento
          final double lookAheadMeters = speed > 1.2 ? 35.0 : 0.0;
          targetCenter = lookAheadMeters > 0
              ? _projectPosition(newPos, _heading, lookAheadMeters)
              : newPos;
        }

        _animateMapCamera(
          targetCenter,
          -_heading,
          targetZoom,
          customCurve: Curves.easeOutCubic,
        );
      } else {
        _latLngTween = null;
        _rotationTween = null;
        _zoomTween = null;
        // Sem follow mode o usuário controla o mapa — não resetamos a câmera
        // (o reset com tweens nulos só congelava o frame e criava a pausa).
        _activeAnimation = null;
      }
    });
  }

  Future<void> _triggerReroute(LatLng rawPos, TruckController tc) async {
    if (!mounted) return;
    setState(() {
      _isRecalculating = true;
      _showReroutingBanner = true;
    });

    try {
      final success = await tc.fetchRoute(rawPos);
      if (!success && mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Falha ao recalcular rota automática.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('[Rerouting] Erro no recálculo automático: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRecalculating = false;
          _showReroutingBanner = false;
          _offRouteCount = 0;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BÚSSOLA
  // ─────────────────────────────────────────────────────────────────────────

  void _startCompassUpdates() {
    _compassStream?.cancel();
    final events = FlutterCompass.events;

    if (events == null) {
      debugPrint('[Sensor] Bússola não suportada no hardware.');
      _compassAvailable = false;
      return;
    }

    _compassCheckTimer = Timer(const Duration(seconds: 4), () {
      if (!_compassAvailable && mounted) {
        debugPrint(
          '[Sensor] Bússola sem leitura – usando GPS como fallback.',
        );
      }
    });

    _compassStream = events.listen((CompassEvent event) {
      final h = event.heading;
      if (!mounted || h == null || h.isNaN) return;

      if (!_compassAvailable) {
        _compassAvailable = true;
        _compassCheckTimer?.cancel();
      }

      // Normaliza heading para [0, 360) (no Android o valor pode vir de -180 a 180)
      final double normalizedH = (h % 360.0 + 360.0) % 360.0;

      final bool isFirstReading = _lastCompassRawValue == null;

      // Filtro de histerese (deadband): ignora ruído insignificante (< 0.4°)
      if (!isFirstReading) {
        final double rawDiff =
            ((normalizedH - _lastCompassRawValue! + 540) % 360) - 180;
        if (rawDiff.abs() < 0.4) return;
      }
      _lastCompassRawValue = normalizedH;

      // Primeiro evento de bússola: captura direção real imediatamente sem delay de 0°
      if (isFirstReading) {
        _heading = normalizedH;
      } else if (_lastKnownSpeed < 1.0) {
        _heading = _smoothAngle(_heading, normalizedH, factor: 0.5);
      }
      _headingNotifier.value = _heading;

      // Se estiver em modo follow e não houver animação de câmera em curso, sincroniza rotação
      if (!_isFollowMode || _rotationTween != null) return;

      // Limiar angular: ignora variações de bússola abaixo de ~0.6° (ruído do
      // sensor), eliminando micro-saltos de rotação enquanto o veículo está parado.
      final double targetRot = -_heading;
      final double currentRot = _mapController.camera.rotation;
      final double delta = ((targetRot - currentRot + 540) % 360) - 180;
      if (delta.abs() < 0.6) return;

      try {
        final center = _animatedPositionNotifier.value ??
            _currentPosition ??
            _mapController.camera.center;
        final zoom = _mapController.camera.zoom;
        _mapController.moveAndRotate(center, zoom, targetRot);
      } catch (e) {
        debugPrint('[Compass] MapController não pronto: $e');
      }
    }, onError: (err) {
      debugPrint('[Sensor] Erro no stream da bússola: $err');
      _compassAvailable = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CÂMERA
  // ─────────────────────────────────────────────────────────────────────────

  void _moveNavigationCamera(
    LatLng position, {
    bool instant = false,
    Duration? customDuration,
    Curve? customCurve,
  }) {
    final double zoom;
    if (_lastKnownSpeed > 22) {
      zoom = 15.5;
    } else if (_lastKnownSpeed > 13) {
      zoom = 16.5;
    } else {
      zoom = 17.0;
    }

    final double lookAheadMeters = (180 * math.pow(2, 17 - zoom)).toDouble();
    final lookAheadCenter = _projectPosition(
      position,
      _heading,
      lookAheadMeters,
    );

    if (instant) {
      _cameraAnimationController?.stop();
      _mapController.moveAndRotate(lookAheadCenter, zoom, -_heading);
      setState(() {
        _animatedPositionNotifier.value = position;
      });
    } else {
      _animateMapCamera(
        lookAheadCenter,
        -_heading,
        zoom,
        customDuration: customDuration,
        customCurve: customCurve,
      );
    }
  }

  void _animateMapCamera(
    LatLng destCenter,
    double destRotation,
    double destZoom, {
    Duration? customDuration,
    Curve? customCurve,
  }) {
    if (!mounted) return;

    LatLng startCenter;
    double startRotation;
    double startZoom;

    try {
      startCenter = _mapController.camera.center;
      startRotation = _mapController.camera.rotation;
      startZoom = _mapController.camera.zoom;
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.moveAndRotate(destCenter, destZoom, destRotation);
          } catch (_) {}
        }
      });
      return;
    }

    final distance = const Distance().as(
      LengthUnit.Meter,
      startCenter,
      destCenter,
    );

    // Threshold reduzido para 0.1m para não bloquear movimento em baixa velocidade.
    if (distance < 0.1 &&
        (destRotation - startRotation).abs() < 0.5 &&
        (destZoom - startZoom).abs() < 0.02) {
      return;
    }

    if (distance > 3000) {
      _cameraAnimationController?.stop();
      _mapController.moveAndRotate(destCenter, destZoom, destRotation);
      setState(() {
        if (_currentPosition != null) {
          _animatedPositionNotifier.value = _currentPosition;
        }
      });
      return;
    }

    final double diff = destRotation - startRotation;
    final double shortestDiff = ((diff + 180) % 360) - 180;
    final double adjustedDestRotation = startRotation + shortestDiff;

    _latLngTween = LatLngTween(begin: startCenter, end: destCenter);
    _rotationTween = Tween<double>(
      begin: startRotation,
      end: adjustedDestRotation,
    );
    _zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    // Nota: veículo é animado pelo _vehicleAnimController — não tocamos aqui.

    _activeAnimation = customCurve != null
        ? _cameraAnimationController!.drive(CurveTween(curve: customCurve))
        : _cameraAnimationController!;

    _cameraAnimationController?.stop();
    _cameraAnimationController?.duration = customDuration ?? _animationDuration;
    _cameraAnimationController?.reset();
    _cameraAnimationController?.forward();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS MATEMÁTICOS
  // ─────────────────────────────────────────────────────────────────────────

  double _smoothAngle(double current, double target, {required double factor}) {
    final delta = ((target - current + 540) % 360) - 180;
    final result = current + delta * factor;
    return ((result % 360) + 360) % 360;
  }

  double? _safeGpsHeading(Position p) {
    if (p.heading.isNaN || p.heading < 0) return null;
    // No Android, heading 0.0 com velocidade < 0.5 m/s é o fallback de "sem direção"
    if (p.heading == 0.0 && p.speed < 0.5) return null;
    return p.heading;
  }

  double _safeSpeed(Position p) {
    if (p.speed.isNaN || p.speed < 0) return 0;
    return p.speed;
  }

  /// Calcula a direção inicial (bearing) do primeiro trecho da rota
  double? _getInitialRouteBearing(LatLng currentPos, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return null;
    const distanceCalc = Distance();
    for (int i = 0; i < routePoints.length; i++) {
      final dist = distanceCalc.as(LengthUnit.Meter, currentPos, routePoints[i]);
      if (dist >= 10.0) {
        return distanceCalc.bearing(currentPos, routePoints[i]);
      }
    }
    if (routePoints.length >= 2) {
      return distanceCalc.bearing(routePoints[0], routePoints[1]);
    }
    return null;
  }

  LatLng _projectPosition(LatLng origin, double bearing, double meters) {
    const earthRadius = 6378137.0;
    final bearingRad = bearing * math.pi / 180;
    final distRatio = meters / earthRadius;
    final latRad = origin.latitude * math.pi / 180;
    final lonRad = origin.longitude * math.pi / 180;

    final newLat = math.asin(
      math.sin(latRad) * math.cos(distRatio) +
          math.cos(latRad) * math.sin(distRatio) * math.cos(bearingRad),
    );
    final newLon =
        lonRad +
        math.atan2(
          math.sin(bearingRad) * math.sin(distRatio) * math.cos(latRad),
          math.cos(distRatio) - math.sin(latRad) * math.sin(newLat),
        );

    return LatLng(newLat * 180 / math.pi, newLon * 180 / math.pi);
  }

  /// Projeta [rawPos] no segmento de rota mais próximo e retorna
  /// (posição projetada, distância ao segmento em metros, índice do segmento).
  /// Produz movimento suave mesmo em curvas porque interpola entre vértices.
  (LatLng, double, int) _snapToRouteSegment(LatLng rawPos, List<LatLng> route) {
    LatLng bestProjection = route.first;
    double bestDist = double.infinity;
    int bestSegmentIndex = 0;

    for (int i = 0; i < route.length - 1; i++) {
      final a = route[i];
      final b = route[i + 1];

      // Vetores em graus (suficiente para pequenas distâncias)
      final ax = a.longitude;
      final ay = a.latitude;
      final bx = b.longitude;
      final by = b.latitude;
      final px = rawPos.longitude;
      final py = rawPos.latitude;

      final abx = bx - ax;
      final aby = by - ay;
      final len2 = abx * abx + aby * aby;

      double t = 0;
      if (len2 > 0) {
        t = ((px - ax) * abx + (py - ay) * aby) / len2;
        t = t.clamp(0.0, 1.0);
      }

      final projLat = ay + t * aby;
      final projLng = ax + t * abx;
      final proj = LatLng(projLat, projLng);

      final d = const Distance().as(LengthUnit.Meter, rawPos, proj);
      if (d < bestDist) {
        bestDist = d;
        bestProjection = proj;
        bestSegmentIndex = i;
      }
    }

    return (bestProjection, bestDist, bestSegmentIndex);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ALERTAS SONOROS DE MARCADORES (estilo Waze)
  // ─────────────────────────────────────────────────────────────────────────

  /// Tipos de marcadores que merecem alerta sonoro proativo.
  static const _ttsAlertTypes = {
    MarkerType.restriction,
    MarkerType.weighStation,
    MarkerType.police,
    MarkerType.danger,
    MarkerType.speedCamera,
    MarkerType.loading,
    MarkerType.parking,
    MarkerType.gasStation,
    MarkerType.mechanic,
    MarkerType.restaurant,
  };

  /// Distância a que o alerta é disparado, adaptada à velocidade do veículo.
  /// Mais rápido → raio maior para dar tempo de reação.
  double _alertRadius(double speedMs) {
    final kmh = speedMs * 3.6;
    if (kmh > 60) return 500.0;
    if (kmh > 20) return 350.0;
    return 200.0;
  }

  /// Verifica proximidade de todos os marcadores críticos e aciona o TTS
  /// quando o usuário entra no raio adaptativo de alerta.
  void _checkMarkerProximityAlerts(
    LatLng pos,
    List<TruckerMarker> markers,
    double speedMs,
  ) {
    if (markers.isEmpty) return;

    final dist = const Distance();
    final radius = _alertRadius(speedMs);
    const double passedThreshold = 80.0; // "já passou" — remove do set anunciado

    for (final marker in markers) {
      if (!_ttsAlertTypes.contains(marker.type)) continue;

      final d = dist.as(LengthUnit.Meter, pos, marker.position);

      // ── Passou pelo marcador → limpa flags para permitir reanunciar ──────
      if (d < passedThreshold) {
        if (_announcedMarkerIds.remove(marker.id)) {
          _markerPassedIds.add(marker.id);
        }
        continue;
      }

      // Se saiu da zona de "passou", limpa o flag de passagem
      if (d > passedThreshold * 2) {
        _markerPassedIds.remove(marker.id);
      }

      // ── Dentro do raio de alerta e ainda não anunciado ───────────────────
      if (d <= radius && !_announcedMarkerIds.contains(marker.id)) {
        _announcedMarkerIds.add(marker.id);

        // Monta o label de distância legível
        final distLabel = d >= 1000
            ? '${(d / 1000).toStringAsFixed(1).replaceAll('.', ',')} quilômetros'
            : '${d.toInt()} metros';

        TtsService.instance.speakMarkerAlert(
          marker.type,
          distanceLabel: distLabel,
        );

        // Só anuncia o marcador mais urgente por vez (respeita o cooldown do TtsService)
        break;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUSCA
  // ─────────────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final text = _searchController.text;
      final tc = context.read<TruckController>();
      if (text.isNotEmpty) {
        tc.fetchSuggestions(text, userLocation: _currentPosition);
      } else {
        tc.clearSuggestions();
      }
    });
  }

  // Abre câmera ou galeria, extrai endereço via OCR e preenche a busca
  Future<void> _pickImageAndExtractAddress() async {
    // Mostra menu de fonte de imagem
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'ESCANEAR ENDEREÇO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                title: const Text(
                  'Câmera',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Fotografe a nota ou etiqueta',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF34C759),
                  ),
                ),
                title: const Text(
                  'Galeria',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Selecione uma imagem salva',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    setState(() => _isOcrLoading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return;

      final rawText = await OcrService.instance.extractTextFromImage(
        picked.path,
      );
      final address = OcrService.parseAddressFromText(rawText);

      if (address.isNotEmpty && mounted) {
        _searchController.text = address;
        context.read<TruckController>().fetchSuggestions(
          address,
          userLocation: _currentPosition,
        );
      } else if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Não foi possível extrair um endereço da imagem.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('[OCR] Erro: $e');
    } finally {
      if (mounted) setState(() => _isOcrLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MARCADORES COLABORATIVOS
  // ─────────────────────────────────────────────────────────────────────────

  void _showTruckProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111318).withValues(alpha: 0.98),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final tc = context.watch<TruckController>();
        final safeBottom = MediaQuery.of(context).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, safeBottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior/indicador de arrastar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Perfil do Caminhão',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Defina as características do seu veículo para evitar pontes baixas, estradas estreitas e restrições de peso.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: TruckProfilePresets.all.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final profile = TruckProfilePresets.all[index];
                    final selected = profile.type == tc.truckProfile.type;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        tc.setTruckProfile(profile);
                        Navigator.of(context).pop();
                        showStyledSnackBar(
                          context: context,
                          message: 'Perfil alterado para: ${profile.label}',
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF4CAF50),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.amber.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppColors.amber.withValues(alpha: 0.40)
                                : Colors.white.withValues(alpha: 0.08),
                            width: selected ? 1.8 : 1.0,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.amber.withValues(
                                      alpha: 0.04,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Ícone visual e indicador de seleção
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.amber.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.local_shipping_rounded,
                                color: selected
                                    ? AppColors.amber
                                    : Colors.white38,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Nome e detalhes informativos
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.label,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white.withValues(
                                              alpha: 0.75,
                                            ),
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Linha de badges/tags informativas
                                  Row(
                                    children: [
                                      _ProfileTag(
                                        label:
                                            '${(profile.maxWeightKg / 1000).toStringAsFixed(0)} t',
                                        icon: Icons.scale_rounded,
                                      ),
                                      const SizedBox(width: 6),
                                      _ProfileTag(
                                        label:
                                            '${profile.maxHeightMeters.toStringAsFixed(1)}m Alt',
                                        icon: Icons.height_rounded,
                                      ),
                                      const SizedBox(width: 6),
                                      _ProfileTag(
                                        label: '${profile.axles} Eixos',
                                        icon: Icons.toll_rounded,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMarkerDialog(LatLng point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'O QUE É ESTE LOCAL?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'O alerta será salvo na sua localização atual no mapa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Grade 2 colunas — botões grandes para dedão com luva
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: MarkerType.values.map((type) {
                final color = _markerColor(type);
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _handleMarkerSelection(point, type);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_markerIcon(type), color: color, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          _markerLabel(type),
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMarkerSelection(LatLng point, MarkerType type) async {
    final tc = context.read<TruckController>();
    final allMarkers = [...tc.customMarkers, ...tc.automaticPOIs];

    final result = MarkerDeduplicationService.evaluate(
      point: point,
      proposedType: type,
      existingMarkers: allMarkers,
      heading: _heading,
    );

    if (result.isNew) {
      await tc.addMarker(
        point,
        type,
        'Adicionado por motorista',
        heading: _heading,
      );
      final scoreEvent = await UserScoreService.instance.addScoreForNewReport();
      if (mounted) {
        ScoreEarnedOverlay.show(context, scoreEvent);
      }
      return;
    }

    // Se já existir alerta no raio com mesmo sentido, abre o MarkerConflictSheet
    final existingMarker = result.existingMarker;
    final isAuthor = existingMarker != null && tc.isMarkerAuthor(existingMarker);
    final hasConfirmed = existingMarker != null && tc.hasConfirmedMarker(existingMarker);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MarkerConflictSheet(
        result: result,
        proposedType: type,
        isAuthor: isAuthor,
        hasConfirmed: hasConfirmed,
        onConfirmExisting: () async {
          if (existingMarker == null) return;
          final success = await tc.confirmMarker(existingMarker.id);
          if (!success) return;

          // Validação remota na API
          final alertId = int.tryParse(existingMarker.id);
          ScoreEvent? scoreEvent;
          bool apiHandled = false;

          if (alertId != null) {
            final apiRes = await ApiService.instance
                .validateAlert(alertId, isHelpful: true);
            if (apiRes != null) {
              apiHandled = true;
              if (apiRes['alreadyValidated'] == true || apiRes['isOwner'] == true) {
                return;
              }
              if (apiRes['userScore'] != null) {
                scoreEvent = await UserScoreService.instance.applyRemoteScore(
                  apiRes['userScore'] as Map<String, dynamic>,
                  pointsEarned:
                      (apiRes['xpEarned'] as num?)?.toInt() ??
                          UserScoreService.xpForConfirmation,
                  reason: 'Presença Confirmada!',
                );
              }
            }
          }

          if (!apiHandled) {
            scoreEvent = await UserScoreService.instance
                .addScoreForConfirmation();
          }

          if (mounted && scoreEvent != null) {
            ScoreEarnedOverlay.show(context, scoreEvent);
          }
        },
        onReplaceExisting: () async {
          await tc.replaceMarker(
            result.existingMarker!.id,
            point,
            type,
            'Corrigido por motorista',
            heading: _heading,
          );
          final scoreEvent =
              await UserScoreService.instance.addScoreForCorrection();
          if (mounted) {
            ScoreEarnedOverlay.show(context, scoreEvent);
          }
        },
        onKeepBoth: () async {
          await tc.addMarker(
            point,
            type,
            'Adicionado por motorista',
            heading: _heading,
          );
          final scoreEvent =
              await UserScoreService.instance.addScoreForNewReport();
          if (mounted) {
            ScoreEarnedOverlay.show(context, scoreEvent);
          }
        },
        onNotThereAnymore: () {
          tc.removeMarker(result.existingMarker!.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFFF9500), size: 20),
                  SizedBox(width: 10),
                  Text('Alerta removido do mapa.'),
                ],
              ),
              backgroundColor: Color(0xFF1E222B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showMarkerDetailSheet(TruckerMarker marker) {
    final color = _markerColor(marker.type);
    final tc = context.read<TruckController>();
    final isAuthor = tc.isMarkerAuthor(marker);
    final hasConfirmed = tc.hasConfirmedMarker(marker);
    final canConfirm = tc.canConfirmMarker(marker);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Ícone + Tipo
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(_markerIcon(marker.type), color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _markerLabel(marker.type),
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        marker.description.isNotEmpty
                            ? marker.description
                            : 'Alerta comunitário na via',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Autor do Alerta e Patente (Reputação Comunitária)
            if (marker.authorName != null && marker.authorName!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_pin_rounded,
                      color: UserRank.getRank(marker.authorXp ?? 0).color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reportado por',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            marker.authorName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: UserRank.getRank(marker.authorXp ?? 0)
                            .color
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: UserRank.getRank(marker.authorXp ?? 0)
                              .color
                              .withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            UserRank.getRank(marker.authorXp ?? 0).emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            UserRank.getRank(marker.authorXp ?? 0).title,
                            style: TextStyle(
                              color: UserRank.getRank(marker.authorXp ?? 0).color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Contador de confirmações da comunidade
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Confirmado por ${marker.confirmations} motorista${marker.confirmations > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (marker.heading != null) ...[
                    const Spacer(),
                    Text(
                      'Sentido ${marker.heading!.round()}°',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Se o usuário for o autor do alerta
            if (isAuthor) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_pin_circle_rounded,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Você reportou este alerta',
                      style: TextStyle(
                        color: Color(0xFF93C5FD),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (hasConfirmed) ...[
              // Se o usuário já confirmou presença anteriormente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF34C759).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF34C759),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Presença já confirmada por você',
                      style: TextStyle(
                        color: Color(0xFF34C759),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (canConfirm) ...[
              // Botão Confirmar Presença (Upvote) - Apenas motoristas que não são autores e não confirmaram
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.thumb_up_rounded, size: 18),
                  label: const Text(
                    'Confirmar Presença (Sim, continua lá)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: () async {
                    final success = await context
                        .read<TruckController>()
                        .confirmMarker(marker.id);
                    if (!context.mounted) return;
                    Navigator.pop(ctx);

                    if (!success) return;

                    // Validação remota na API
                    final alertId = int.tryParse(marker.id);
                    ScoreEvent? scoreEvent;
                    bool apiHandled = false;

                    if (alertId != null) {
                      final apiRes = await ApiService.instance
                          .validateAlert(alertId, isHelpful: true);
                      if (apiRes != null) {
                        apiHandled = true;
                        if (apiRes['alreadyValidated'] == true ||
                            apiRes['isOwner'] == true) {
                          return;
                        }
                        if (apiRes['userScore'] != null) {
                          scoreEvent = await UserScoreService.instance
                              .applyRemoteScore(
                            apiRes['userScore'] as Map<String, dynamic>,
                            pointsEarned:
                                (apiRes['xpEarned'] as num?)?.toInt() ??
                                    UserScoreService.xpForConfirmation,
                            reason: 'Presença Confirmada!',
                          );
                        }
                      }
                    }

                    // Fallback local se a API estiver offline
                    if (!apiHandled) {
                      scoreEvent = await UserScoreService.instance
                          .addScoreForConfirmation();
                    }

                    if (mounted && scoreEvent != null) {
                      ScoreEarnedOverlay.show(context, scoreEvent);
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Botão deletar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: BorderSide(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: const Text(
                  'Remover Marcador',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () {
                  context.read<TruckController>().removeMarker(marker.id);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _markerColor(MarkerType t) => switch (t) {
    MarkerType.loading => const Color(0xFF34C759),
    MarkerType.restriction => const Color(0xFFFF3B30),
    MarkerType.weighStation => const Color(0xFFFF9500),
    MarkerType.parking => const Color(0xFFAF52DE),
    MarkerType.police => const Color(0xFF1E90FF),
    MarkerType.danger => const Color(0xFFFF0000),
    MarkerType.gasStation => const Color(0xFFF59E0B),
    MarkerType.mechanic => const Color(0xFF6B7280),
    MarkerType.restaurant => const Color(0xFFEC4899),
    MarkerType.speedCamera => const Color(0xFF00C7FF),
    MarkerType.other => const Color(0xFF8E8E93),
  };

  IconData _markerIcon(MarkerType t) => switch (t) {
    MarkerType.loading => Icons.import_export_rounded,
    MarkerType.restriction => Icons.block_rounded,
    MarkerType.weighStation => Icons.scale_rounded,
    MarkerType.parking => Icons.local_parking_rounded,
    MarkerType.police => Icons.local_police_rounded,
    MarkerType.danger => Icons.warning_rounded,
    MarkerType.gasStation => Icons.local_gas_station_rounded,
    MarkerType.mechanic => Icons.build_circle_rounded,
    MarkerType.restaurant => Icons.restaurant_rounded,
    MarkerType.speedCamera => Icons.camera_alt_rounded,
    MarkerType.other => Icons.info_rounded,
  };

  String _markerLabel(MarkerType t) => switch (t) {
    MarkerType.loading => 'Carga/Descarga',
    MarkerType.restriction => 'Restrição',
    MarkerType.weighStation => 'Balança',
    MarkerType.parking => 'Pátio',
    MarkerType.police => 'Polícia',
    MarkerType.danger => 'Perigo',
    MarkerType.gasStation => 'Posto',
    MarkerType.mechanic => 'Mecânica',
    MarkerType.restaurant => 'Parada',
    MarkerType.speedCamera => 'Radar',
    MarkerType.other => 'Outros',
  };

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── MAPA ────────────────────────────────────────────────────────────
          RepaintBoundary(
            key: _mapRepaintKey,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapEvent: (event) {
                  if (_isFollowMode &&
                      event.source == MapEventSource.dragStart) {
                    setState(() => _isFollowMode = false);
                    _cameraAnimationController?.stop();
                  }
                  // Atualiza zoom para controlar visibilidade dos marcadores
                  final zoom = event.camera.zoom;
                  if ((zoom - _currentZoom).abs() > 0.15) {
                    setState(() => _currentZoom = zoom);
                  }
                },
                onTap: (tapPosition, point) => FocusScope.of(context).unfocus(),
              ),
              children: [
                // Se kCartoApiKey for preenchida, usa CartoDB Dark Matter (@2x retina).
                // Caso contrário, usa OpenStreetMap gratuito sem necessidade de chave de API.
                kCartoApiKey.isNotEmpty
                    ? TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png?key=$kCartoApiKey',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.trallzero.app',
                        maxZoom: 20,
                        retinaMode: true,
                      )
                    : TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.trallzero.app',
                        maxZoom: 19,
                        tileBuilder: darkModeTileBuilder,
                      ),
                if (tc.routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      ...tc.availableRoutes
                          .asMap()
                          .entries
                          .where((entry) => entry.key != tc.selectedRouteIndex)
                          .map((entry) {
                            final route = entry.value;
                            return Polyline(
                              points: route.points,
                              color: Colors.white.withValues(alpha: 0.18),
                              strokeWidth: 5.0,
                            );
                          }),
                      // Glow effect — halo under the main route
                      Polyline(
                        points: tc.routePoints,
                        color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                        strokeWidth: 16.0,
                      ),
                      // Linha principal da rota (azul limpa e cristalina)
                      Polyline(
                        points: tc.routePoints,
                        color: const Color(0xFF3B82F6),
                        strokeWidth: 5.5,
                      ),
                    ],
                  ),
                ValueListenableBuilder<LatLng?>(
                  valueListenable: _animatedPositionNotifier,
                  builder: (context, pos, _) => MarkerLayer(
                  markers: [
                    if (pos != null)
                      Marker(
                        point: pos,
                        width: 54,
                        height: 54,
                        // rotate: false mantém o marcador solidário ao plano do mapa.
                        // Com a seta rotacionada por heading dentro do NavigationMarker,
                        // em modo Follow (-heading) ela aponta sempre para o TOPO da tela.
                        rotate: false,
                        child: ValueListenableBuilder<double>(
                          valueListenable: _headingNotifier,
                          builder: (context, heading, _) {
                            return NavigationMarker(
                              speed: _lastKnownSpeed,
                              profileType: tc.truckProfile.type,
                              heading: heading,
                            );
                          },
                        ),
                      ),
                    ...tc.deliveryStops.asMap().entries.map((entry) {
                      final index = entry.key;
                      final stop = entry.value;
                      return Marker(
                        point: LatLng(stop.lat, stop.lng),
                        width: 48,
                        height: 60,
                        rotate: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF34C759).withValues(alpha: 0.55),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                            // Ponteiro triangular
                            CustomPaint(
                              size: const Size(12, 8),
                              painter: _PinPointerPainter(
                                color: const Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ...[...tc.customMarkers, ...tc.automaticPOIs].map((m) {
                      final color = _markerColor(m.type);
                      final label = _markerLabel(m.type);

                      final bool showLabel = _currentZoom >= 15.0;

                      return Marker(
                        point: m.position,
                        width: showLabel ? 52 : 42,
                        height: showLabel ? 72 : 48,
                        rotate: true,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _currentZoom >= _markerVisibilityZoom
                              ? 1.0
                              : 0.0,
                          child: IgnorePointer(
                            ignoring: _currentZoom < _markerVisibilityZoom,
                            child: GestureDetector(
                              onTap: () => _showMarkerDetailSheet(m),
                              // FittedBox participa do layout e escala o conteúdo
                              // para caber exatamente na caixa do Marker — sem overflow.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    // ── Pin circular compacto (estilo Waze) ──
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                color.withValues(alpha: 0.45),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 3),
                                          ),
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _markerIcon(m.type),
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    // ── Pontinha triangular ──
                                    CustomPaint(
                                      size: const Size(10, 7),
                                      painter:
                                          _PinPointerPainter(color: color),
                                    ),
                                    // ── Label só aparece em zoom ≥ 15 ──
                                    if (showLabel) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0B0E17)
                                              .withValues(alpha: 0.88),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          border: Border.all(
                                            color:
                                                color.withValues(alpha: 0.45),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                ),
              ],
            ),
          ), // RepaintBoundary
          // ── BARRA DE BUSCA ───────────────────────────────────────────────────────────────────
          // Oculta durante navegação ativa para não distrair o motorista
          if (!tc.isNavigating)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              top: _isFullScreen
                  ? -200
                  : MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isFullScreen ? 0.0 : 1.0,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111318).withValues(alpha: 0.95),
                        borderRadius: tc.suggestions.isNotEmpty
                            ? const BorderRadius.vertical(
                                top: Radius.circular(16),
                              )
                            : BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(
                            0xFFE07B1A,
                          ).withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Botão Hamburguer integrado no canto esquerdo da busca
                          IconButton(
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                            tooltip: 'Menu',
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Para onde vamos, motorista?',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFFE07B1A),
                                  size: 19,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botão OCR / câmera
                                    if (_isOcrLoading)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFE07B1A),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    else if (tc.destination == null &&
                                        _searchController.text.isEmpty)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.document_scanner_rounded,
                                          color: Color(0xFFE07B1A),
                                          size: 20,
                                        ),
                                        tooltip: 'Escanear nota fiscal',
                                        onPressed: _pickImageAndExtractAddress,
                                      ),
                                    // Botão limpar
                                    if (tc.destination != null ||
                                        _searchController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white38,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          tc.clearRoute();
                                          _mapController.rotate(0);
                                          setState(() {
                                            _offRouteCount = 0;
                                            _isRecalculating = false;
                                            _showReroutingBanner = false;
                                          });
                                        },
                                      ),
                                    // ── Indicador de sinal GPS ─────────────────
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GpsSignalDot(
                                        accuracy: _gpsAccuracy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onSubmitted: (value) async {
                                if (value.isNotEmpty &&
                                    _currentPosition != null) {
                                  final dest = await tc.searchAddress(
                                    value,
                                    _currentPosition!,
                                  );
                                  if (!context.mounted || dest == null) return;
                                  _mapController.move(dest, 16);
                                  if (tc.lastSearchPrecision ==
                                      GeocodePrecision.approximate) {
                                    showStyledSnackBar(
                                      context: context,
                                      message:
                                          'Número não encontrado nos dados do mapa — ponto aproximado na via. Confirme no local.',
                                      icon: Icons.warning_amber_rounded,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tc.suggestions.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF111318,
                          ).withValues(alpha: 0.97),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFFE07B1A,
                            ).withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: tc.suggestions.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.white.withValues(alpha: 0.06),
                            height: 1,
                            indent: 44,
                          ),
                          itemBuilder: (_, i) {
                            final s = tc.suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFE07B1A),
                                size: 18,
                              ),
                              title: Text(
                                s,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () async {
                                _searchController.text = s;
                                FocusScope.of(context).unfocus();
                                if (_currentPosition != null) {
                                  final dest = await tc.searchAddress(
                                    s,
                                    _currentPosition!,
                                  );
                                  if (!context.mounted || dest == null) return;
                                  _mapController.move(dest, 16);
                                  if (tc.lastSearchPrecision ==
                                      GeocodePrecision.approximate) {
                                    showStyledSnackBar(
                                      context: context,
                                      message:
                                          'Número não encontrado nos dados do mapa — ponto aproximado na via. Confirme no local.',
                                      icon: Icons.warning_amber_rounded,
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── BANNER DE RECÁLCULO DE ROTA ───────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 16,
            right: 16,
            child: AnimatedSlide(
              offset: _showReroutingBanner
                  ? Offset.zero
                  : const Offset(0, -0.3),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showReroutingBanner ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111318).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF9500),
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Recalculando rota...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── PAINEL DE NAVEGAÇÃO ───────────────────────────────────────────
          // Quando o painel some, zera o notifier para os botões descerem
          if (tc.routePoints.isEmpty ||
              tc.suggestions.isNotEmpty ||
              _isFullScreen)
            Builder(
              builder: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_panelSizeNotifier.value != 0) {
                    _panelSizeNotifier.value = 0;
                  }
                });
                return const SizedBox.shrink();
              },
            ),
          if (tc.routePoints.isNotEmpty &&
              tc.suggestions.isEmpty &&
              !_isFullScreen)
            // NavigationPanel é um DraggableScrollableSheet — deve ser filho
            // direto do Stack (sem Positioned) para funcionar corretamente
            NavigationPanel(
              heading: _heading,
              speed: _lastKnownSpeed,
              onProfileTap: _showTruckProfileSheet,
              onRoutesTap: tc.cycleRoute,
              onPanelSizeChanged: (size) {
                _panelSizeNotifier.value = size;
              },
              onStopsTap: () async {
                final truckCtrl = context.read<TruckController>();
                final resultObj = await Navigator.pushNamed(
                  context,
                  '/route_manager',
                );

                if (resultObj is List<DeliveryStop> && mounted) {
                  final result = resultObj;
                  LatLng startLoc = const LatLng(-22.9068, -43.1729);
                  try {
                    if (await LocationService.handlePermission()) {
                      final pos = await LocationService.getCurrentPosition();
                      startLoc = LatLng(pos.latitude, pos.longitude);
                    }
                  } catch (e) {
                    debugPrint('Erro ao buscar localização inicial: $e');
                  }

                  if (mounted) {
                    truckCtrl.setDeliveryStops(result, startLoc);
                  }
                }
              },
              mapRepaintKey: _mapRepaintKey,
              onEndRoute: () async {
                await context.read<TruckController>().endRoute();
                _mapController.rotate(0);
              },
              onAddMarkerAtCurrentPosition: _currentPosition == null
                  ? null
                  : () => _showAddMarkerDialog(_currentPosition!),
              onGo: () {
                tc.toggleNavigation();
                if (tc.isNavigating) {
                  setState(() {
                    _isFollowMode = true;
                    _offRouteCount = 0;
                    _isRecalculating = false;
                    _showReroutingBanner = false;
                    _showNavBanner = true;
                  });

                  // Alinha imediatamente a direção do veículo/mapa com o sentido da rota
                  if (_currentPosition != null && tc.routePoints.isNotEmpty) {
                    final routeBearing = _getInitialRouteBearing(_currentPosition!, tc.routePoints);
                    if (routeBearing != null) {
                      _heading = (routeBearing % 360.0 + 360.0) % 360.0;
                      _headingNotifier.value = _heading;
                    }
                  }

                  _navBannerTimer?.cancel();
                  _navBannerTimer = Timer(
                    const Duration(milliseconds: 2500),
                    () {
                      if (mounted) setState(() => _showNavBanner = false);
                    },
                  );
                  if (_currentPosition != null) {
                    _moveNavigationCamera(
                      _currentPosition!,
                      customDuration: const Duration(milliseconds: 700),
                      customCurve: Curves.easeOutCubic,
                    );
                  }
                } else {
                  _mapController.rotate(0);
                }
              },
              onStop: () {
                tc.toggleNavigation();
                _mapController.rotate(0);
              },
            ),

          // ── HUD DE MANOBRA FIXO (topo, visível durante navegação) ──────────
          if (tc.isNavigating && !_isFullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: const ManeuverHud(),
            ),

          // ── HUD DE RESTRIÇÃO — pulsante vermelho, alta prioridade ──
          if (tc.isNavigating && !_isFullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 128,
              left: 0,
              right: 0,
              child: RestrictionAlertHud(
                markers: [...tc.customMarkers, ...tc.automaticPOIs],
                currentPosition: _currentPosition,
                routePoints: tc.routePoints,
                onRecalculate: () async {
                  if (_currentPosition != null) {
                    await tc.fetchRoute(_currentPosition!);
                  }
                },
              ),
            ),

          // ── BANNER "NAVEGAÇÃO INICIADA" ────────────────────────────────────
          if (_showNavBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 32,
              right: 32,
              child: const NavStartBanner(),
            ),

          // ── HUD DE NAVEGAÇÃO FULLSCREEN ──────────────────────────────────
          if (_isFullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: _FullscreenHud(
                speedMs: _lastKnownSpeed,
                heading: _heading,
              ),
            ),

          // ── HUD DE ALERTAS PROATIVOS ──────────────────────────────────────
          // Posicionado abaixo do ManeuverHud quando navegando
          if (tc.isNavigating && tc.routePoints.isNotEmpty)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (tc.isNavigating ? 108 : 76),
              left: 0,
              right: 0,
              child: ProactiveAlertHud(
                markers: [...tc.customMarkers, ...tc.automaticPOIs],
                currentPosition: _currentPosition,
                routePoints: tc.routePoints,
              ),
            ),

          // ── HUD DE RISCO DE TOMBAMENTO & DECLIVE DE SERRA ─────────────────
          if (tc.isNavigating && !_isFullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 115,
              left: 0,
              right: 0,
              child: SlopeAndRollWarningHud(
                currentPosition: _currentPosition,
                speedKmh: _lastKnownSpeed * 3.6,
              ),
            ),

          // ── TIMELINE DA RODOVIA (Highway Corridor View) ───────────────────
          if (tc.isNavigating && !_isFullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 115,
              right: 12,
              child: HighwayCorridorTimeline(
                currentPosition: _currentPosition,
                routePoints: tc.routePoints,
                markers: [...tc.customMarkers, ...tc.automaticPOIs],
                deliveryStops: tc.deliveryStops,
                onSelectPoint: (point) {
                  _animateMapCamera(
                    point,
                    -_heading,
                    15.0,
                  );
                },
              ),
            ),

          // ── MODO CHEGADA / DOCAGEM DE CARGA ───────────────────────────────
          if (tc.isNavigating && !_isFullScreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 0,
              right: 0,
              child: DockingArrivalCard(
                currentPosition: _currentPosition,
                onZoomInDock: () {
                  if (_currentPosition != null) {
                    _animateMapCamera(
                      _currentPosition!,
                      -_heading,
                      18.0,
                    );
                  }
                },
                onCompleteDelivery: () async {
                  await tc.endRoute();
                  _mapController.rotate(0);
                  if (mounted) {
                    showStyledSnackBar(
                      context: context,
                      message: 'Entrega concluída com sucesso! Parabéns, motorista.',
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF34C759),
                    );
                  }
                },
              ),
            ),

          // ── BOTÕES LATERAIS ───────────────────────────────────────────────
          // Layout simplificado:
          //   Esquerdo: velocímetro (só ao navegar)
          //   Direito : follow mode (sempre) + marcar alerta (só com posição) + controle de áudio
          ValueListenableBuilder<double>(
            valueListenable: _panelSizeNotifier,
            builder: (context, panelSize, child) {
              final screenH = MediaQuery.of(context).size.height;
              final safeBottom = MediaQuery.of(context).padding.bottom;
              final hasRoute = tc.isNavigating || tc.routePoints.isNotEmpty;
              final double bottomBarOffset = hasRoute ? 0.0 : (64.0 + safeBottom);

              final double buttonBottom;
              if (_isFullScreen) {
                buttonBottom = safeBottom + 16;
              } else {
                final panelPixels = panelSize > 0
                    ? (panelSize * screenH).clamp(0.0, screenH * 0.65)
                    : 0.0;
                buttonBottom = panelPixels + bottomBarOffset + 16;
              }

              final prefs = context.watch<PreferencesService>();

              return Stack(
                children: [
                  // ── Esquerdo: velocímetro sempre visível com sinal ────────
                  if (_currentPosition != null && !_isFullScreen)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: 16,
                      bottom: buttonBottom,
                      child: _SpeedHud(speedMs: _lastKnownSpeed),
                    ),

                  // ── Direito: follow mode + add marker + volume ───────────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    right: 16,
                    bottom: buttonBottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botão de Mute/Unmute rápido para a Voz Guia
                        _LargeMapButton(
                          icon: prefs.ttsEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          isPrimary: !prefs
                              .ttsEnabled, // fica em destaque vermelho/tema se mutado
                          onPressed: () {
                            prefs.setTtsEnabled(!prefs.ttsEnabled);
                            showStyledSnackBar(
                              context: context,
                              message: prefs.ttsEnabled
                                  ? 'Voz guia ativada'
                                  : 'Voz guia silenciada',
                              icon: prefs.ttsEnabled
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              iconColor: prefs.ttsEnabled
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFEF5350),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // Adicionar alerta — visível quando há posição
                        if (_currentPosition != null) ...[
                          _LargeMapButton(
                            icon: Icons.add_location_alt_rounded,
                            onPressed: () {
                              _showAddMarkerDialog(_currentPosition!);
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        // Follow mode — botão principal, sempre visível
                        _LargeMapButton(
                          icon: _isFollowMode
                              ? Icons.navigation_rounded
                              : Icons.my_location_rounded,
                          isPrimary: _isFollowMode,
                          onPressed: () {
                            if (_currentPosition == null) {
                              _initLocation();
                              return;
                            }
                            setState(() => _isFollowMode = true);
                            if (tc.isNavigating) {
                              _moveNavigationCamera(_currentPosition!);
                            } else {
                              _animateMapCamera(
                                _currentPosition!,
                                -_heading,
                                _mapController.camera.zoom,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // ── LOADING ROTA ──────────────────────────────────────────────────
          if (tc.isRouting)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111318).withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Calculando rota...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTÃO GRANDE DO MAPA (acessível para uso com luvas)
// ─────────────────────────────────────────────────────────────────────────────

class _LargeMapButton extends StatelessWidget {
  const _LargeMapButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF2563EB)
                : const Color(0xFF1A1D26).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF2563EB)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.85),
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TWEEN DE COORDENADAS
// ─────────────────────────────────────────────────────────────────────────────

class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    if (begin == null || end == null) return begin ?? end ?? const LatLng(0, 0);
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PONTEIRO DO PIN DE ENTREGA (triângulo na base do círculo)
// ─────────────────────────────────────────────────────────────────────────────

class _PinPointerPainter extends CustomPainter {
  const _PinPointerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  VELOCÍMETRO HUD — exibe velocidade em km/h durante a navegação
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedHud extends StatelessWidget {
  const _SpeedHud({required this.speedMs});

  /// Velocidade em metros por segundo (vinda do GPS)
  final double speedMs;

  Color _speedColor(int kmh) {
    if (kmh > 80) return const Color(0xFFFF3B30); // perigo
    if (kmh > 60) return const Color(0xFFFF9500); // atenção
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final kmh = (speedMs * 3.6).round();
    final color = _speedColor(kmh);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF111318).withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: kmh > 80
              ? const Color(0xFFFF3B30).withValues(alpha: 0.40)
              : Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kmh > 80
                ? const Color(0xFFFF3B30).withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.40),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
            child: Text('$kmh'),
          ),
          const SizedBox(height: 3),
          Text(
            'km/h',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HUD DE VELOCIDADE EM FULLSCREEN (Glassmorphism + hora + bússola)
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenHud extends StatefulWidget {
  const _FullscreenHud({required this.speedMs, required this.heading});
  final double speedMs;
  final double heading;

  @override
  State<_FullscreenHud> createState() => _FullscreenHudState();
}

class _FullscreenHudState extends State<_FullscreenHud> {
  late Timer _clockTimer;
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    if (_timeString != timeStr) {
      setState(() => _timeString = timeStr);
    }
  }

  String _cardinal(double heading) {
    const dirs = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    return dirs[((heading + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    final kmh = (widget.speedMs * 3.6).round();
    final speedColor = kmh > 80
        ? AppColors.danger
        : kmh > 60
        ? AppColors.attention
        : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgPanel.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Linha superior: Hora + Direção cardinal
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 11,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timeString,
                    style: TextStyle(
                      color: AppColors.textContent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1.5, height: 12, color: AppColors.divider),
                  const SizedBox(width: 12),
                  Icon(Icons.explore_rounded, size: 11, color: AppColors.blue),
                  const SizedBox(width: 4),
                  Text(
                    _cardinal(widget.heading),
                    style: const TextStyle(
                      color: AppColors.blueMid,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Velocidade
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$kmh',
                    style: TextStyle(
                      color: speedColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'km/h',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Badge/Etiqueta do Perfil de Caminhão
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.35), size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
