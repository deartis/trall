import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/ocr_service.dart';
import '../widgets/navigation_marker.dart';
import '../widgets/proactive_alert_hud.dart';
import '../controllers/truck_controller.dart';
import '../map_layers/road_analysis_layer.dart';
import '../models/marker_model.dart';
import '../models/truck_profile.dart';
import '../widgets/navigation_panel.dart';
import '../features/route/models/delivery_stop.dart';
import '../features/route/screens/route_manager_screen.dart';


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
  LatLng? _animatedCurrentPosition; // Posição suave renderizada no mapa
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  Timer? _debounce;

  // --- Animação da câmera (suavizada e adaptativa) ---
  AnimationController? _cameraAnimationController;
  LatLngTween? _latLngTween;
  Tween<double>? _rotationTween;
  Tween<double>? _zoomTween;
  LatLngTween? _vehicleLatLngTween; // Tween para transição suave do veículo
  Animation<double>? _activeAnimation; // Animação ativa com suporte a curvas
  DateTime? _lastGpsUpdateTime; // Timestamp para medir o intervalo real do GPS
  Duration _animationDuration = const Duration(
    milliseconds: 900,
  ); // Duração adaptativa

  // --- Heading ---
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0.0);
  double _heading = 0;
  double _lastKnownSpeed = 0;
  Timer? _compassCheckTimer;

  // --- Detecção de bússola dummy (ex: Moto G30) ---
  int _compassEventCount = 0;
  double? _firstCompassValue;
  double? _lastCompassRawValue;
  bool _isCompassDummy = false;
  bool _compassAvailable = false;

  // --- Follow mode e FullScreen ---
  bool _isFollowMode = true;
  bool _isFullScreen = false;

  // --- OCR ---
  bool _isOcrLoading = false;

  // --- RepaintBoundary key (compartilhar rota) ---
  final GlobalKey _mapRepaintKey = GlobalKey();

  // --- Recálculo de Rota Automático (Rerouting) ---
  int _offRouteCount = 0;
  bool _isRecalculating = false;
  bool _showReroutingBanner = false;

  // ─────────────────────────────────────────────────────────────────────────
  //  CICLO DE VIDA
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    // Duração inicial de 900ms para corresponder às atualizações do GPS (1s)
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _cameraAnimationController!.addListener(() {
      if (!mounted || _activeAnimation == null) return;

      final anim = _activeAnimation!;

      // Atualiza a posição suavizada do veículo
      if (_vehicleLatLngTween != null) {
        final animatedPos = _vehicleLatLngTween!.evaluate(anim);
        setState(() {
          _animatedCurrentPosition = animatedPos;
        });
      }

      // Se não há interpolação de câmera definida (ex: modo livre), interrompe aqui
      if (_latLngTween == null ||
          _rotationTween == null ||
          _zoomTween == null) {
        return;
      }

      final currentPos = _latLngTween!.evaluate(anim);
      final currentZoom = _zoomTween!.evaluate(anim);

      final isMoving = _lastKnownSpeed > 1.5;
      if (isMoving || _isCompassDummy || !_compassAvailable) {
        final currentRot = _rotationTween!.evaluate(anim);
        _mapController.moveAndRotate(currentPos, currentZoom, currentRot);
      } else {
        // Parado com bússola: posição animada, rotação em tempo real
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
        _animatedCurrentPosition = pos;
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

      if (truckController.isNavigating &&
          truckController.routePoints.isNotEmpty) {
        LatLng closest = truckController.routePoints.first;
        double minDist = double.infinity;
        for (final point in truckController.routePoints) {
          final d = const Distance().as(LengthUnit.Meter, rawPos, point);
          if (d < minDist) {
            minDist = d;
            closest = point;
          }
        }

        if (minDist < 30) {
          newPos = closest;
          _offRouteCount = 0;
          truckController.updateCurrentStep(newPos); // avança manobra
        } else if (minDist >= 40) {
          _offRouteCount++;
          if (_offRouteCount >= 3 && !_isRecalculating) {
            _triggerReroute(rawPos, truckController);
          }
        }
      }

      final speed = _safeSpeed(position);

      // --- Cálculo da Duração Dinâmica Adaptativa ---
      final now = DateTime.now();
      if (_lastGpsUpdateTime != null) {
        final elapsed = now.difference(_lastGpsUpdateTime!);
        if (elapsed.inMilliseconds >= 300 && elapsed.inMilliseconds <= 2000) {
          _animationDuration = Duration(
            milliseconds: (elapsed.inMilliseconds * 0.85).round(),
          );
        } else {
          _animationDuration = const Duration(milliseconds: 900);
        }
      }
      _lastGpsUpdateTime = now;

      final oldPos = _animatedCurrentPosition ?? _currentPosition ?? newPos;

      setState(() {
        _currentPosition = newPos;
        _lastKnownSpeed = speed;
      });

      final gpsHeading = _safeGpsHeading(position);
      final bool useGpsHeading =
          gpsHeading != null && (speed > 1.5 || _isCompassDummy);

      if (useGpsHeading) {
        _heading = _smoothAngle(_heading, gpsHeading, factor: 0.95);
        _headingNotifier.value = _heading;
      }

      // Prepara interpolação suave da posição do caminhão (marcador)
      _vehicleLatLngTween = LatLngTween(begin: oldPos, end: newPos);

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

        _animateMapCamera(
          targetCenter,
          -_heading,
          targetZoom,
          customCurve: Curves.linear,
        );
      } else {
        _latLngTween = null;
        _rotationTween = null;
        _zoomTween = null;
        _activeAnimation = _cameraAnimationController!;

        _cameraAnimationController?.stop();
        _cameraAnimationController?.duration = _animationDuration;
        _cameraAnimationController?.reset();
        _cameraAnimationController?.forward();
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
      await tc.fetchRoute(rawPos);
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
      debugPrint('[Sensor] Bússola não encontrada no hardware.');
      setState(() {
        _isCompassDummy = true;
        _compassAvailable = false;
      });
      return;
    }

    _compassCheckTimer = Timer(const Duration(seconds: 4), () {
      if ((!_compassAvailable || _isCompassDummy) && mounted) {
        debugPrint(
          '[Sensor] Bússola não funcional – usando GPS como fallback.',
        );
      }
    });

    _compassStream = events.listen((CompassEvent event) {
      final h = event.heading;
      if (!mounted || h == null || h.isNaN) return;

      // Detecção de sensor dummy (valor constante após 15 eventos)
      _compassEventCount++;
      _firstCompassValue ??= h;
      if (!_isCompassDummy && _compassEventCount > 15) {
        if (h == _firstCompassValue) {
          setState(() {
            _isCompassDummy = true;
            _compassAvailable = false;
          });
          _compassCheckTimer?.cancel();
          debugPrint('[Sensor] Bússola DUMMY detectada (valor constante).');
          return;
        }
      }

      if (_isCompassDummy) return;

      if (!_compassAvailable) {
        setState(() => _compassAvailable = true);
        _compassCheckTimer?.cancel();
      }

      // Bússola só controla heading quando parado (GPS assume em movimento)
      if (_lastKnownSpeed > 1.5) return;

      // Filtro de histerese (deadband): ignora variações menores que 1.5°
      if (_lastCompassRawValue != null) {
        final double rawDiff = ((h - _lastCompassRawValue! + 540) % 360) - 180;
        if (rawDiff.abs() < 1.5) return;
      }
      _lastCompassRawValue = h;

      _heading = _smoothAngle(_heading, h, factor: 0.85);
      _headingNotifier.value = _heading;

      if (!_isFollowMode) return;

      if (_cameraAnimationController == null ||
          !_cameraAnimationController!.isAnimating) {
        try {
          final center = _currentPosition ?? _mapController.camera.center;
          final zoom = _mapController.camera.zoom;
          _mapController.moveAndRotate(center, zoom, -_heading);
        } catch (e) {
          debugPrint('[Compass] MapController não pronto: $e');
        }
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  CÂMERA
  // ─────────────────────────────────────────────────────────────────────────

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
      setState(() {
        _animatedCurrentPosition = position;
      });
    } else {
      _animateMapCamera(lookAheadCenter, -_heading, zoom);
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

    if (distance < 0.5 &&
        (destRotation - startRotation).abs() < 1.5 &&
        (destZoom - startZoom).abs() < 0.05) {
      return;
    }

    if (distance > 500) {
      _cameraAnimationController?.stop();
      _mapController.moveAndRotate(destCenter, destZoom, destRotation);
      setState(() {
        if (_currentPosition != null) {
          _animatedCurrentPosition = _currentPosition;
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

    if (_currentPosition != null) {
      _vehicleLatLngTween = LatLngTween(
        begin: _animatedCurrentPosition ?? _currentPosition!,
        end: _currentPosition!,
      );
    }

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

  // _snapToRoute foi unificado diretamente no fluxo de atualizações do GPS em _startLocationUpdates

  // ─────────────────────────────────────────────────────────────────────────
  //  BUSCA
  // ─────────────────────────────────────────────────────────────────────────

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
                width: 36, height: 3,
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
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: const Text('Câmera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Fotografe a nota ou etiqueta', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF34C759)),
                ),
                title: const Text('Galeria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Selecione uma imagem salva', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
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
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;

      final rawText = await OcrService.instance.extractTextFromImage(picked.path);
      final address = OcrService.instance.parseAddressFromText(rawText);

      if (address.isNotEmpty && mounted) {
        _searchController.text = address;
        context.read<TruckController>().fetchSuggestions(address);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível extrair um endereço da imagem.'),
            backgroundColor: Color(0xFF1E2128),
          ),
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
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final tc = context.read<TruckController>();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecionar perfil de caminhão',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ...TruckProfilePresets.all.map((profile) {
                final selected = profile.type == tc.truckProfile.type;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.local_shipping_rounded,
                    color: selected ? const Color(0xFF34C759) : Colors.white70,
                  ),
                  title: Text(
                    profile.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${profile.maxWeightKg.toInt()} kg • ${profile.maxHeightMeters} m • ${profile.axles} eixos',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  onTap: () {
                    tc.setTruckProfile(profile);
                    Navigator.of(context).pop();
                  },
                );
              }),
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
            16, 12, 16, MediaQuery.of(context).padding.bottom + 24),
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
                    context.read<TruckController>().addMarker(
                      point,
                      type,
                      'Adicionado por motorista',
                    );
                    Navigator.pop(context);
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
            // Botão deletar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFFF3B30,
                  ).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(color: Color(0xFFFF3B30), width: 1),
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
    MarkerType.police => const Color(0xFF1E90FF),
    MarkerType.danger => const Color(0xFFFF0000),
    MarkerType.gasStation => const Color(0xFFF59E0B),
    MarkerType.mechanic => const Color(0xFF6B7280),
    MarkerType.restaurant => const Color(0xFFEC4899),
    MarkerType.other => const Color(0xFF8E8E93),
  };

  IconData _markerIcon(MarkerType t) => switch (t) {
    MarkerType.loading => Icons.file_download_rounded,
    MarkerType.unloading => Icons.file_upload_rounded,
    MarkerType.restriction => Icons.block_rounded,
    MarkerType.weighStation => Icons.scale_rounded,
    MarkerType.parking => Icons.local_parking_rounded,
    MarkerType.police => Icons.local_police_rounded,
    MarkerType.danger => Icons.warning_rounded,
    MarkerType.gasStation => Icons.local_gas_station_rounded,
    MarkerType.mechanic => Icons.build_circle_rounded,
    MarkerType.restaurant => Icons.restaurant_rounded,
    MarkerType.other => Icons.info_rounded,
  };

  String _markerLabel(MarkerType t) => switch (t) {
    MarkerType.loading => 'Carga',
    MarkerType.unloading => 'Descarga',
    MarkerType.restriction => 'Restrição',
    MarkerType.weighStation => 'Balança',
    MarkerType.parking => 'Pátio',
    MarkerType.police => 'Polícia',
    MarkerType.danger => 'Perigo',
    MarkerType.gasStation => 'Posto',
    MarkerType.mechanic => 'Mecânica',
    MarkerType.restaurant => 'Parada',
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
                  if (_isFollowMode && event.source == MapEventSource.dragStart) {
                    setState(() => _isFollowMode = false);
                    _cameraAnimationController?.stop();
                  }
                },
                onTap: (tapPosition, point) => FocusScope.of(context).unfocus(),
                onLongPress: (_, point) => _showAddMarkerDialog(point),
              ),
              children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  1.4, 0, 0, 0, 30, // Red: multiply by 1.4, add 30
                  0, 1.4, 0, 0, 30, // Green
                  0, 0, 1.4, 0, 30, // Blue
                  0, 0, 0, 1, 0,    // Alpha
                ]),
                child: TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.trallzero.app',
                ),
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
                    ...(tc.routeAnalysisSegments.isNotEmpty
                        ? buildRoadAnalysisPolylines(tc.routeAnalysisSegments)
                        : [
                            Polyline(
                              points: tc.routePoints,
                              color: Colors.blueAccent,
                              strokeWidth: 6.0,
                            ),
                          ]),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_animatedCurrentPosition != null)
                    Marker(
                      point: _animatedCurrentPosition!,
                      width: 50,
                      height: 50,
                      rotate: true,
                      child: const NavigationMarker(),
                    ),
                  ...tc.deliveryStops.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stop = entry.value;
                    return Marker(
                      point: LatLng(stop.lat, stop.lng),
                      width: 40,
                      height: 40,
                      rotate: true,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF34C759),
                            size: 40,
                          ),
                          Positioned(
                            top: 6,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ...[...tc.customMarkers, ...tc.automaticPOIs].map(
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
                              color: _markerColor(
                                m.type,
                              ).withValues(alpha: 0.5),
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
          ), // RepaintBoundary

          // ── BARRA DE BUSCA ────────────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            top: _isFullScreen ? -200 : MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _isFullScreen ? 0.0 : 1.0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111318).withValues(alpha: 0.95),
                      borderRadius: tc.suggestions.isNotEmpty
                          ? const BorderRadius.vertical(
                              top: Radius.circular(16),
                            )
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
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botão OCR / câmera
                            if (_isOcrLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.blueAccent, strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (tc.destination == null && _searchController.text.isEmpty)
                              IconButton(
                                icon: const Icon(Icons.document_scanner_rounded, color: Colors.blueAccent, size: 20),
                                tooltip: 'Escanear nota fiscal',
                                onPressed: _pickImageAndExtractAddress,
                              ),
                            // Botão limpar
                            if (tc.destination != null || _searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
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
                          ],
                        ),
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
                  const SizedBox(height: 8),
                  if (tc.suggestions.isEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (tc.automaticPOIs.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FloatingActionButton.small(
                              heroTag: 'clear_pois',
                              backgroundColor: const Color(0xFF111318),
                              onPressed: tc.clearAutomaticPOIs,
                              child: const Icon(Icons.clear_all_rounded, color: Colors.white70),
                            ),
                          ),
                        FloatingActionButton.extended(
                          heroTag: 'find_pois',
                          backgroundColor: const Color(0xFF2563EB),
                          icon: tc.isLoadingPOIs 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 20),
                          label: Text(tc.isLoadingPOIs ? 'Buscando...' : 'Locais Próximos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: tc.isLoadingPOIs ? null : () {
                            if (_currentPosition != null) {
                              tc.findNearbyPOIs(_currentPosition!);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Aguardando sinal de GPS...')),
                              );
                            }
                          },
                        ),
                      ],
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
          if (tc.routePoints.isNotEmpty && tc.suggestions.isEmpty)
            // NavigationPanel é um DraggableScrollableSheet — deve ser filho
            // direto do Stack (sem Positioned) para funcionar corretamente
            NavigationPanel(
              heading: _heading,
              speed: _lastKnownSpeed,
              onProfileTap: _showTruckProfileSheet,
              onRoutesTap: tc.cycleRoute,
              onStopsTap: () async {
                final truckCtrl = context.read<TruckController>();
                final result = await Navigator.push<List<DeliveryStop>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RouteManagerScreen(),
                  ),
                );

                if (result != null && mounted) {
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
                  });
                  if (_currentPosition != null) {
                    _moveNavigationCamera(_currentPosition!);
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

          // ── HUD DE ALERTAS PROATIVOS ──────────────────────────────────────
          if (tc.isNavigating && tc.routePoints.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 0,
              right: 0,
              child: ProactiveAlertHud(
                markers: [...tc.customMarkers, ...tc.automaticPOIs],
                currentPosition: _currentPosition,
                routePoints: tc.routePoints,
              ),
            ),

          // ── BOTÕES LATERAIS ───────────────────────────────────────────────
          // Botões de zoom: canto ESQUERDO inferior (não colide com nav panel)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 16,
            bottom: (tc.routePoints.isNotEmpty && tc.suggestions.isEmpty)
                ? (tc.isNavigating ? 160 : 260)
                : 32,
            child: Column(
              children: [
                _LargeMapButton(
                  icon: Icons.add_rounded,
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 10),
                _LargeMapButton(
                  icon: Icons.remove_rounded,
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
              ],
            ),
          ),

          // Botões de controle: canto DIREITO inferior
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: (tc.routePoints.isNotEmpty && tc.suggestions.isEmpty)
                ? (tc.isNavigating ? 160 : 260)
                : 32,
            child: Column(
              children: [
                _LargeMapButton(
                  icon: _isFullScreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  onPressed: () =>
                      setState(() => _isFullScreen = !_isFullScreen),
                ),
                const SizedBox(height: 10),
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

          // ── LOADING ROTA ──────────────────────────────────────────────────
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
        onTap: onPressed,
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
            color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.85),
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
