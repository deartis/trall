import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../widgets/navigation_marker.dart';
import '../controllers/truck_controller.dart';
import '../models/marker_model.dart';

// ============================================================
// COMO FUNCIONA A ROTAÃ‡ÃƒO:
//
//   1. O MAPA rotaciona para que a direÃ§Ã£o do aparelho fique
//      apontando para o TOPO da tela (idÃªntico ao Waze).
//
//   2. A SETA (NavigationMarker) fica sempre fixa apontando
//      para o TOPO (rotate: true no Marker).
//
//   3. Fonte do heading:
//      - BÃšSSOLA: fonte principal. Funciona parado.
//      - GPS: fallback quando sem bÃºssola ou em movimento >1.5m/s.
//
//   4. Follow mode:
//      - true  â†’ cÃ¢mera segue o veÃ­culo e o mapa rotaciona.
//      - false â†’ cÃ¢mera livre (usuÃ¡rio arrastou o mapa).
// ============================================================

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
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Timer? _debounce;

  // --- AnimaÃ§Ã£o da cÃ¢mera (180ms â€” responsivo sem ser brusco) ---
  AnimationController? _cameraAnimationController;
  LatLngTween? _latLngTween;
  Tween<double>? _rotationTween;
  Tween<double>? _zoomTween;

  // --- Heading ---
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0.0);
  double _heading = 0;
  double _lastKnownSpeed = 0;
  Timer? _compassCheckTimer;

  // --- DetecÃ§Ã£o de bÃºssola dummy (ex: Moto G30) ---
  int _compassEventCount = 0;
  double? _firstCompassValue;
  double? _lastCompassRawValue;
  bool _isCompassDummy = false;
  bool _compassAvailable = false;

  // --- Follow mode ---
  bool _isFollowMode = true;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CICLO DE VIDA
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    // 180ms: rÃ¡pido o suficiente para parecer em tempo real, suave o suficiente
    // para nÃ£o ser brusco numa curva.
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _cameraAnimationController!.addListener(() {
      if (!mounted ||
          _latLngTween == null ||
          _rotationTween == null ||
          _zoomTween == null)
        return;

      final t = _cameraAnimationController!;
      final currentPos = _latLngTween!.evaluate(t);
      final currentZoom = _zoomTween!.evaluate(t);

      final isMoving = _lastKnownSpeed > 1.5;
      if (isMoving || _isCompassDummy || !_compassAvailable) {
        final currentRot = _rotationTween!.evaluate(t);
        _mapController.moveAndRotate(currentPos, currentZoom, currentRot);
      } else {
        // Parado com bÃºssola: posiÃ§Ã£o animada, rotaÃ§Ã£o em tempo real
        _mapController.moveAndRotate(currentPos, currentZoom, -_heading);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.rotate(0);
      _startCompassUpdates();
    });

    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _compassCheckTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _cameraAnimationController?.dispose();
    _headingNotifier.dispose();
    super.dispose();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  LOCALIZAÃ‡ÃƒO (GPS)
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      debugPrint('[GPS] Erro na posiÃ§Ã£o inicial: $e');
    }
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = LocationService.getPositionStream().listen((position) {
      if (!mounted) return;

      var newPos = LatLng(position.latitude, position.longitude);
      final truckController = context.read<TruckController>();

      if (truckController.isNavigating &&
          truckController.routePoints.isNotEmpty) {
        newPos = _snapToRoute(newPos, truckController.routePoints);
      }

      final speed = _safeSpeed(position);

      setState(() {
        _currentPosition = newPos;
        _lastKnownSpeed = speed;
      });

      final gpsHeading = _safeGpsHeading(position);
      final bool useGpsHeading =
          gpsHeading != null && (speed > 1.5 || _isCompassDummy);

      if (useGpsHeading) {
        // Fator alto (0.95): reage rÃ¡pido ao GPS em movimento, sem lag acumulado
        _heading = _smoothAngle(_heading, gpsHeading, factor: 0.95);
        _headingNotifier.value = _heading;
      }

      if (_isFollowMode) {
        final double targetZoom;
        final LatLng targetCenter;

        if (truckController.isNavigating) {
          if (speed > 22) {
            targetZoom = 15.5;
          } else if (speed > 13) {
            targetZoom = 16.5;
          } else {
            targetZoom = 17.0;
          }

          final double lookAheadMeters = (180 * math.pow(2, 17 - targetZoom))
              .toDouble();
          targetCenter = _projectPosition(newPos, _heading, lookAheadMeters);
        } else {
          double tempZoom = 16.0;
          try {
            tempZoom = _mapController.camera.zoom;
          } catch (_) {}
          targetZoom = tempZoom;
          targetCenter = newPos;
        }

        _animateMapCamera(targetCenter, -_heading, targetZoom);
      }
    });
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  BÃšSSOLA
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _startCompassUpdates() {
    _compassStream?.cancel();
    final events = FlutterCompass.events;

    if (events == null) {
      debugPrint('[Sensor] BÃºssola nÃ£o encontrada no hardware.');
      setState(() {
        _isCompassDummy = true;
        _compassAvailable = false;
      });
      return;
    }

    _compassCheckTimer = Timer(const Duration(seconds: 4), () {
      if ((!_compassAvailable || _isCompassDummy) && mounted) {
        debugPrint(
          '[Sensor] BÃºssola nÃ£o funcional â€” usando GPS como fallback.',
        );
      }
    });

    _compassStream = events.listen((CompassEvent event) {
      final h = event.heading;
      if (!mounted || h == null || h.isNaN) return;

      // DetecÃ§Ã£o de sensor dummy (valor constante apÃ³s 15 eventos)
      _compassEventCount++;
      _firstCompassValue ??= h;
      if (!_isCompassDummy && _compassEventCount > 15) {
        if (h == _firstCompassValue) {
          setState(() {
            _isCompassDummy = true;
            _compassAvailable = false;
          });
          _compassCheckTimer?.cancel();
          debugPrint('[Sensor] BÃºssola DUMMY detectada (valor constante).');
          return;
        }
      }

      if (_isCompassDummy) return;

      if (!_compassAvailable) {
        setState(() => _compassAvailable = true);
        _compassCheckTimer?.cancel();
      }

      // BÃºssola sÃ³ controla heading quando parado (GPS assume em movimento)
      if (_lastKnownSpeed > 1.5) return;
 
      // Filtro de histerese (deadband): se o aparelho estÃ¡ parado, ignoramos
      // variaÃ§Ãµes menores que 1.5Â° para eliminar ruÃ­dos e evitar que o mapa gire sozinho.
      if (_lastCompassRawValue != null) {
        final double rawDiff = ((h - _lastCompassRawValue! + 540) % 360) - 180;
        if (rawDiff.abs() < 1.5) return;
      }
      _lastCompassRawValue = h;
 
      // Fator alto (0.85): resposta quase imediata, filtra apenas tremores de mÃ£o
      _heading = _smoothAngle(_heading, h, factor: 0.85);
      _headingNotifier.value = _heading;

      if (!_isFollowMode) return;

      // Se animaÃ§Ã£o estÃ¡ rodando, ela aplica o heading atualizado no prÃ³ximo tick
      if (_cameraAnimationController == null ||
          !_cameraAnimationController!.isAnimating) {
        try {
          final center = _currentPosition ?? _mapController.camera.center;
          final zoom = _mapController.camera.zoom;
          _mapController.moveAndRotate(center, zoom, -_heading);
        } catch (e) {
          debugPrint('[Compass] MapController nÃ£o pronto: $e');
        }
      }
    });
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  CÃ‚MERA
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _moveNavigationCamera(LatLng position, {bool instant = false}) {
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
    } else {
      _animateMapCamera(lookAheadCenter, -_heading, zoom);
    }
  }

  void _animateMapCamera(
    LatLng destCenter,
    double destRotation,
    double destZoom,
  ) {
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

    // Threshold aumentado: 1.5Â° ignora micro-tremores mas deixa rotaÃ§Ãµes reais passarem
    if (distance < 0.5 &&
        (destRotation - startRotation).abs() < 1.5 &&
        (destZoom - startZoom).abs() < 0.05) {
      return;
    }

    // Salto grande (ex: primeiro fix GPS): move instantaneamente, sem efeito slingshot
    if (distance > 500) {
      _cameraAnimationController?.stop();
      _mapController.moveAndRotate(destCenter, destZoom, destRotation);
      return;
    }

    // Resolve wraparound 360Â° para interpolaÃ§Ã£o linear sem giros bruscos
    final double diff = destRotation - startRotation;
    final double shortestDiff = ((diff + 180) % 360) - 180;
    final double adjustedDestRotation = startRotation + shortestDiff;

    _latLngTween = LatLngTween(begin: startCenter, end: destCenter);
    _rotationTween = Tween<double>(
      begin: startRotation,
      end: adjustedDestRotation,
    );
    _zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    _cameraAnimationController?.stop();
    _cameraAnimationController?.reset();
    _cameraAnimationController?.forward();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  HELPERS MATEMÃTICOS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  double _smoothAngle(double current, double target, {required double factor}) {
    final delta = ((target - current + 540) % 360) - 180;
    final result = current + delta * factor;
    return ((result % 360) + 360) % 360;
  }

  double? _safeGpsHeading(Position p) {
    if (p.heading.isNaN || p.heading < 0) return null;
    return p.heading;
  }

  double _safeSpeed(Position p) {
    if (p.speed.isNaN || p.speed < 0) return 0;
    return p.speed;
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

  LatLng _snapToRoute(LatLng pos, List<LatLng> route) {
    LatLng closest = route.first;
    double minDist = double.infinity;
    for (final point in route) {
      final d = const Distance().as(LengthUnit.Meter, pos, point);
      if (d < minDist) {
        minDist = d;
        closest = point;
      }
    }
    return minDist < 30 ? closest : pos;
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  BUSCA
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final text = _searchController.text;
      final tc = context.read<TruckController>();
      if (text.isNotEmpty) {
        tc.fetchSuggestions(text);
      } else {
        tc.clearSuggestions();
      }
    });
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  MARCADORES COLABORATIVOS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showAddMarkerDialog(LatLng point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
            const Text(
              'MARCAR LOCAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: MarkerType.values.map((type) {
                return GestureDetector(
                  onTap: () {
                    context.read<TruckController>().addMarker(
                      point,
                      type,
                      'Adicionado por motorista',
                    );
                    Navigator.pop(context);
                  },
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _markerColor(type).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _markerColor(type).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _markerIcon(type),
                            color: _markerColor(type),
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _markerLabel(type),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
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

  void _showMarkerDetailSheet(TruckerMarker marker) {
    final color = _markerColor(marker.type);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20,
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
            // Ãcone + Tipo
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
                Column(
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
                      marker.description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            // BotÃ£o deletar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(
                    color: Color(0xFFFF3B30),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.delete_rounded, size: 20),
                label: const Text(
                  'Remover Marcador',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
    MarkerType.unloading => const Color(0xFF007AFF),
    MarkerType.restriction => const Color(0xFFFF3B30),
    MarkerType.weighStation => const Color(0xFFFF9500),
    MarkerType.parking => const Color(0xFFAF52DE),
  };

  IconData _markerIcon(MarkerType t) => switch (t) {
    MarkerType.loading => Icons.file_download_rounded,
    MarkerType.unloading => Icons.file_upload_rounded,
    MarkerType.restriction => Icons.block_rounded,
    MarkerType.weighStation => Icons.scale_rounded,
    MarkerType.parking => Icons.local_parking_rounded,
  };

  String _markerLabel(MarkerType t) => switch (t) {
    MarkerType.loading => 'Carga',
    MarkerType.unloading => 'Descarga',
    MarkerType.restriction => 'RestriÃ§Ã£o',
    MarkerType.weighStation => 'BalanÃ§a',
    MarkerType.parking => 'PÃ¡tio',
  };

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //  BUILD
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // â”€â”€ MAPA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapEvent: (event) {
                // SÃ³ desativa follow quando o USUÃRIO arrasta â€” nÃ£o eventos programÃ¡ticos
                if (_isFollowMode && event.source == MapEventSource.dragStart) {
                  setState(() => _isFollowMode = false);
                  _cameraAnimationController?.stop();
                }
              },
              onTap: (_, point) {
                if (_currentPosition != null) {
                  tc.setDestination(point, _currentPosition!);
                }
                FocusScope.of(context).unfocus();
              },
              onLongPress: (_, point) => _showAddMarkerDialog(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.trallzero.app',
              ),
              if (tc.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Sombra da rota
                    Polyline(
                      points: tc.routePoints,
                      color: Colors.blueAccent.withValues(alpha: 0.25),
                      strokeWidth: 10,
                    ),
                    // Rota principal
                    Polyline(
                      points: tc.routePoints,
                      color: Colors.blueAccent,
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 50,
                      height: 50,
                      rotate: true,
                      child: const NavigationMarker(),
                    ),
                  if (tc.destination != null)
                    Marker(
                      point: tc.destination!,
                      width: 40,
                      height: 40,
                      rotate: true,
                      child: const Icon(
                        Icons.flag_rounded,
                        color: Color(0xFF34C759),
                        size: 35,
                      ),
                    ),
              ...tc.customMarkers.map(
                    (m) => Marker(
                      point: m.position,
                      width: 44,
                      height: 44,
                      rotate: true,
                      child: GestureDetector(
                        onTap: () => _showMarkerDetailSheet(m),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _markerColor(m.type).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _markerColor(m.type).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            _markerIcon(m.type),
                            color: _markerColor(m.type),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // â”€â”€ BARRA DE BUSCA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111318).withValues(alpha: 0.95),
                    borderRadius: tc.suggestions.isNotEmpty
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Para onde vamos, motorista?',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      icon: const Icon(
                        Icons.search_rounded,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      suffixIcon:
                          tc.destination != null ||
                              _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white38,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                tc.clearRoute();
                                _mapController.rotate(0);
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) async {
                      if (value.isNotEmpty && _currentPosition != null) {
                        final dest = await tc.searchAddress(
                          value,
                          _currentPosition!,
                        );
                        if (dest != null) _mapController.move(dest, 16);
                      }
                    },
                  ),
                ),
                if (tc.suggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111318).withValues(alpha: 0.97),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
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
                      separatorBuilder: (_, __) => Divider(
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
                            color: Colors.blueAccent,
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
                              if (dest != null) _mapController.move(dest, 16);
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // â”€â”€ PAINEL DE ROTA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            left: 16,
            right: 80,
            bottom: 32,
            child: AnimatedSlide(
              offset: (tc.routePoints.isNotEmpty && tc.suggestions.isEmpty)
                  ? Offset.zero
                  : const Offset(0, 1.5),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: (tc.routePoints.isNotEmpty && tc.suggestions.isEmpty) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1D26).withValues(alpha: 0.97),
                      const Color(0xFF0D0F14).withValues(alpha: 0.97),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: tc.isNavigating
                        ? const Color(0xFF34C759).withValues(alpha: 0.4)
                        : Colors.blueAccent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (tc.isNavigating
                                  ? const Color(0xFF34C759)
                                  : Colors.blueAccent)
                              .withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: tc.isNavigating
                          ? const Color(0xFF34C759)
                          : Colors.blueAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tc.formattedDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          tc.formattedDistance,
                          style: TextStyle(
                            color: tc.isNavigating
                                ? const Color(0xFF34C759)
                                : Colors.blueAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // BotÃ£o GO/PARAR â€” 72Ã—52 para uso com luva
                    GestureDetector(
                      onTap: () {
                        tc.toggleNavigation();
                        if (tc.isNavigating) {
                          setState(() => _isFollowMode = true);
                          if (_currentPosition != null) {
                            _moveNavigationCamera(_currentPosition!);
                          }
                        } else {
                          _mapController.rotate(0);
                        }
                      },
                      child: Container(
                        width: 72,
                        height: 52,
                        decoration: BoxDecoration(
                          color: tc.isNavigating
                              ? const Color(0xFFFF3B30)
                              : Colors.blueAccent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (tc.isNavigating
                                          ? const Color(0xFFFF3B30)
                                          : Colors.blueAccent)
                                      .withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            tc.isNavigating ? 'PARAR' : 'GO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),


          // â”€â”€ VELOCÃMETRO (durante navegaÃ§Ã£o ativa) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            left: 16,
            bottom: 136, // acima do painel de rota (32 + 80 + 24)
            child: AnimatedSlide(
              offset: (tc.isNavigating && _lastKnownSpeed > 0)
                  ? Offset.zero
                  : const Offset(-1.5, 0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: (tc.isNavigating && _lastKnownSpeed > 0) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111318).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_lastKnownSpeed * 3.6).round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'km/h',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // â”€â”€ BOTÃ•ES LATERAIS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            right: 16,
            bottom: 32,
            child: Column(
              children: [
                _MapIconButton(
                  icon: Icons.add_rounded,
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 8),
                _MapIconButton(
                  icon: Icons.remove_rounded,
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 16),
                _MapIconButton(
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

          // â”€â”€ LOADING ROTA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (tc.isRouting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.blueAccent,
                  strokeWidth: 2.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  WIDGETS AUXILIARES
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// BotÃ£o do mapa â€” 52Ã—52, tÃ¡til para uso com luva
class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
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
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.blueAccent
                : const Color(0xFF111318).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.blueAccent.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              if (isPrimary)
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}


// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  TWEEN DE COORDENADAS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
