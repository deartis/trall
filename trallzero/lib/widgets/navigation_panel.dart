import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../controllers/truck_controller.dart';
import 'avoid_options_sheet.dart';
import '../screens/settings_screen.dart';
import 'route_risk_bar.dart';
import '../models/road_analysis.dart';


// ─────────────────────────────────────────────────────────────
//  NavigationPanel — DraggableScrollableSheet com 3 snap points
//
//  Snap points:
//    peek  (~0.13) → handle + tempo + distância + GO
//    mid   (~0.30) → + chips + risco + próxima manobra
//    max   (~0.60) → + turn-by-turn completo + findings
// ─────────────────────────────────────────────────────────────

class NavigationPanel extends StatefulWidget {
  const NavigationPanel({
    super.key,
    required this.heading,
    required this.speed,
    required this.onGo,
    required this.onStop,
    this.onPanelSizeChanged,
    this.onProfileTap,
    this.onRoutesTap,
    this.onStopsTap,
    this.onEndRoute,
    this.onAddMarkerAtCurrentPosition,
    this.mapRepaintKey,
  });

  final double heading;
  final double speed;
  final VoidCallback onGo;
  final VoidCallback onStop;
  /// Callback chamado sempre que o tamanho do painel muda (0.0 – 1.0).
  /// Permite que a tela pai posicione botões acima do painel.
  final ValueChanged<double>? onPanelSizeChanged;
  final VoidCallback? onProfileTap;
  final VoidCallback? onRoutesTap;
  final VoidCallback? onStopsTap;
  final VoidCallback? onEndRoute;
  final VoidCallback? onAddMarkerAtCurrentPosition;
  final GlobalKey? mapRepaintKey;

  @override
  State<NavigationPanel> createState() => _NavigationPanelState();
}

class _NavigationPanelState extends State<NavigationPanel> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _snapPeek = 0.13;
  static const double _snapMid = 0.30;
  static const double _snapMax = 0.60;

  bool _isSharingRoute = false;

  // Converte m/s para km/h
  double get _kmh => widget.speed * 3.6;

  // Converte heading em texto cardinal
  String get _cardinal {
    const dirs = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    return dirs[((widget.heading + 22.5) / 45).floor() % 8];
  }

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    // Reporta o tamanho inicial após o primeiro frame (sheet já attached)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sheetController.isAttached) {
        widget.onPanelSizeChanged?.call(_sheetController.size);
      }
    });
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    widget.onPanelSizeChanged?.call(_sheetController.size);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _shareRoute() async {
    final key = widget.mapRepaintKey;
    if (key == null) return;

    setState(() => _isSharingRoute = true);
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'image/png',
        name: 'rota_trall.png',
      );
      await Share.shareXFiles(
        [xFile],
        text: '🚛 Minha rota no TrallZero',
      );
    } catch (e) {
      debugPrint('Erro ao compartilhar rota: $e');
    } finally {
      if (mounted) setState(() => _isSharingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    final isNavigating = tc.isNavigating;

    // Em modo navegando, trava no peek — menos clutter
    final initialSize = isNavigating ? _snapPeek : _snapMid;
    final snapSizes = isNavigating
        ? [_snapPeek, _snapMid]
        : [_snapPeek, _snapMid, _snapMax];

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: initialSize,
      minChildSize: _snapPeek,
      maxChildSize: isNavigating ? _snapMid : _snapMax,
      snap: true,
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgBase,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isNavigating
                    ? AppColors.safeBorder
                    : AppColors.blueBorder,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              // ── Handle ────────────────────────────────────────────
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: isNavigating
                        ? AppColors.safeBorder
                        : AppColors.handle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // ════════════════════════════════════════════════════
              //  MODO NAVEGANDO: peek focado na manobra atual
              // ════════════════════════════════════════════════════
              if (isNavigating) ...[
                _NavigatingPeek(
                  tc: tc,
                  kmh: _kmh,
                  cardinal: _cardinal,
                  onStop: widget.onStop,
                ),

                // Risk Bar
                if (tc.routeAnalysisSegments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RouteRiskBar(
                    segments: tc.routeAnalysisSegments,
                    totalDistanceMeters:
                        tc.routePoints.isEmpty ? 1 : _totalRouteDistance(tc),
                    progressMeters: tc.progressOnRouteMeters,
                  ),
                ],

                // Quick-Add marker
                if (widget.onAddMarkerAtCurrentPosition != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      children: [
                        _Chip(
                          icon: Icons.add_location_alt_rounded,
                          label: 'Marcar aqui',
                          color: AppColors.amberWarm,
                          onTap: widget.onAddMarkerAtCurrentPosition!,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          icon: Icons.stop_circle_outlined,
                          label: 'Encerrar',
                          color: AppColors.danger,
                          onTap: widget.onEndRoute ?? () {},
                        ),
                      ],
                    ),
                  ),
                ],

                // Seção expandida: turn-by-turn em mid
                const SizedBox(height: 16),
                _SectionDivider(label: 'PERCURSO COMPLETO'),
                const SizedBox(height: 8),
                _TurnByTurnList(tc: tc),
                if (tc.routeAnalysisFindings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _FindingsList(tc: tc),
                ],
              ]

              // ════════════════════════════════════════════════════
              //  MODO ROTA CALCULADA (não navegando): layout original
              // ════════════════════════════════════════════════════
              else ...[
                // ── Linha principal: status + tempo + distância ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Ícone de rota calculada
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.blueSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: AppColors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tempo + distância + ETA
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tc.formattedDuration,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tc.formattedDistance,
                            style: const TextStyle(
                              color: AppColors.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (tc.formattedETA.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 11,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  tc.formattedETA,
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const Spacer(),

                      // Botão GO
                      _GoButton(
                        isNavigating: false,
                        onTap: widget.onGo,
                      ),
                    ],
                  ),
                ),

                // Risk Bar
                if (tc.routeAnalysisSegments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RouteRiskBar(
                    segments: tc.routeAnalysisSegments,
                    totalDistanceMeters:
                        tc.routePoints.isEmpty ? 1 : _totalRouteDistance(tc),
                    progressMeters: tc.progressOnRouteMeters,
                  ),
                ],

                // ── Chips de ação ────────────────────────────────
                const SizedBox(height: 14),
                Stack(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 0, 48, 0),
                      child: Row(
                        children: [
                          _Chip(
                            icon: Icons.settings_rounded,
                            label: 'Ajustes',
                            color: AppColors.textMuted,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            icon: Icons.block_rounded,
                            label: 'Evitar',
                            color: tc.avoidTolls ||
                                    tc.avoidFerries ||
                                    tc.avoidUnpaved
                                ? AppColors.danger
                                : AppColors.textMuted,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const AvoidOptionsSheet(),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Rotas',
                            color: AppColors.textMuted,
                            onTap: widget.onRoutesTap ?? () {},
                          ),
                          if (widget.onStopsTap != null) ...[
                            const SizedBox(width: 8),
                            _Chip(
                              icon: Icons.alt_route_rounded,
                              label: 'Paradas',
                              color: AppColors.textMuted,
                              onTap: widget.onStopsTap!,
                            ),
                          ],
                          if (widget.mapRepaintKey != null) ...[
                            const SizedBox(width: 8),
                            _Chip(
                              icon: _isSharingRoute
                                  ? Icons.hourglass_top_rounded
                                  : Icons.share_rounded,
                              label: 'Compartilhar',
                              color: AppColors.textMuted,
                              onTap: _isSharingRoute ? () {} : _shareRoute,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Fade-gradient indicando que há mais chips
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppColors.bgBase.withValues(alpha: 0),
                                AppColors.bgBase,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Encerrar Rota ─────────────────────────────────
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EndRouteButton(onTap: widget.onEndRoute ?? () {}),
                ),

                // ── Próxima instrução (modo não navegando) ────────
                const SizedBox(height: 10),
                _SectionDivider(label: 'PRÓXIMA MANOBRA'),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Builder(builder: (context) {
                    final step = tc.nextStep;
                    final icon = step != null
                        ? _maneuverIcon(step.type, step.modifier)
                        : Icons.flag_rounded;
                    final mainText = step != null
                        ? _maneuverLabel(step.type, step.modifier)
                        : 'Toque em GO para iniciar';
                    final subText = step != null
                        ? '${step.formattedDistance}${step.streetName.isNotEmpty ? ' — ${step.streetName}' : ''}'
                        : 'A rota está calculada e pronta';

                    return Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: AppColors.textContent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mainText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                subText,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    );
                  }),
                ),

                // ── Seção expandida: turn-by-turn + findings ──────
                if (tc.availableRoutes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionDivider(label: 'PERCURSO COMPLETO'),
                  const SizedBox(height: 8),
                  _TurnByTurnList(tc: tc),
                  if (tc.routeAnalysisFindings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FindingsList(tc: tc),
                  ],
                ],
              ],

              // Safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  double _totalRouteDistance(TruckController tc) {
    if (tc.routeAnalysisSegments.isEmpty) return tc.routePoints.length.toDouble();
    return tc.routeAnalysisSegments.fold(0.0, (sum, s) => sum + s.distanceMeters);
  }
}

// ─────────────────────────────────────────────────────────────
//  Timer de fadiga com cor gradual
// ─────────────────────────────────────────────────────────────
class _FatigueTimer extends StatefulWidget {
  const _FatigueTimer({required this.tc});
  final TruckController tc;

  @override
  State<_FatigueTimer> createState() => _FatigueTimerState();
}

class _FatigueTimerState extends State<_FatigueTimer>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseCtrl;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    _setupPulse();
  }

  void _setupPulse() {
    final sev = widget.tc.fatigueSeverity;
    if (sev == FatigueSeverity.none) return;

    final durationMs = sev == FatigueSeverity.critical ? 600 : 1000;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_FatigueTimer old) {
    super.didUpdateWidget(old);
    final newSev = widget.tc.fatigueSeverity;
    final oldSev = old.tc.fatigueSeverity;
    if (newSev != oldSev) {
      _pulseCtrl?.dispose();
      _pulseCtrl = null;
      _pulseAnim = null;
      _setupPulse();
    }
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.tc.fatigueSeverity) {
      case FatigueSeverity.none:
        return AppColors.textTertiary;
      case FatigueSeverity.warning:
        return AppColors.attention;
      case FatigueSeverity.danger:
        return AppColors.heavy;
      case FatigueSeverity.critical:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sev = widget.tc.fatigueSeverity;
    final color = _color;

    Widget inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_rounded, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          widget.tc.formattedDrivingTime,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (sev == FatigueSeverity.critical) ...[
          const SizedBox(width: 4),
          Icon(Icons.warning_amber_rounded, size: 11, color: color),
        ],
      ],
    );

    if (_pulseAnim != null) {
      inner = AnimatedBuilder(
        animation: _pulseAnim!,
        builder: (_, child) => Opacity(opacity: _pulseAnim!.value, child: child),
        child: inner,
      );
    }

    if (sev == FatigueSeverity.critical) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.dangerFaint,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.dangerBorderStrong,
            width: 1,
          ),
        ),
        child: inner,
      );
    }
    return inner;
  }
}

// ─────────────────────────────────────────────────────────────
//  Lista de turn-by-turn (painel expandido)
// ─────────────────────────────────────────────────────────────
class _TurnByTurnList extends StatelessWidget {
  const _TurnByTurnList({required this.tc});
  final TruckController tc;

  @override
  Widget build(BuildContext context) {
    final route = tc.availableRoutes.isNotEmpty
        ? tc.availableRoutes[tc.selectedRouteIndex]
        : null;
    if (route == null || route.steps.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: route.steps.length,
      itemBuilder: (_, i) {
        final step = route.steps[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _maneuverIcon(step.type, step.modifier),
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _maneuverLabel(step.type, step.modifier),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (step.streetName.isNotEmpty)
                      Text(
                        step.streetName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                step.formattedDistance,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Lista de findings de risco (painel expandido)
// ─────────────────────────────────────────────────────────────
class _FindingsList extends StatelessWidget {
  const _FindingsList({required this.tc});
  final TruckController tc;

  Color _severityColor(RoadHazardLevel l) => switch (l) {
    RoadHazardLevel.safe      => AppColors.safe,
    RoadHazardLevel.attention => AppColors.attention,
    RoadHazardLevel.heavy     => AppColors.heavy,
    RoadHazardLevel.avoid     => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'ALERTAS DE RISCO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: tc.routeAnalysisFindings.length,
          itemBuilder: (_, i) {
            final f = tc.routeAnalysisFindings[i];
            final color = _severityColor(f.severity);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.title,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          f.detail,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helpers de manobra OSRM → ícone / texto PT-BR
// ─────────────────────────────────────────────────────────────

IconData _maneuverIcon(String type, String modifier) {
  if (type == 'depart') return Icons.navigation_rounded;
  if (type == 'arrive') return Icons.flag_rounded;
  if (type == 'roundabout' || type == 'rotary') return Icons.roundabout_right_rounded;
  if (type == 'fork') {
    return modifier.contains('right')
        ? Icons.fork_right_rounded
        : Icons.fork_left_rounded;
  }
  return switch (modifier) {
    'left'         => Icons.turn_left_rounded,
    'sharp left'   => Icons.turn_sharp_left_rounded,
    'slight left'  => Icons.turn_slight_left_rounded,
    'right'        => Icons.turn_right_rounded,
    'sharp right'  => Icons.turn_sharp_right_rounded,
    'slight right' => Icons.turn_slight_right_rounded,
    'uturn'        => Icons.u_turn_left_rounded,
    _              => Icons.straight_rounded,
  };
}

String _maneuverLabel(String type, String modifier) {
  if (type == 'depart') return 'Siga em frente';
  if (type == 'arrive') return 'Chegou ao destino';
  if (type == 'roundabout' || type == 'rotary') return 'Entre na rotatória';
  if (type == 'fork') {
    return modifier.contains('right') ? 'Mantenha à direita' : 'Mantenha à esquerda';
  }
  if (type == 'merge') return 'Entre na via';
  if (type == 'on ramp') return 'Acesse a rampa';
  if (type == 'off ramp') return 'Saída da rampa';
  return switch (modifier) {
    'left'         => 'Vire à esquerda',
    'sharp left'   => 'Vire acentuadamente à esquerda',
    'slight left'  => 'Vire levemente à esquerda',
    'right'        => 'Vire à direita',
    'sharp right'  => 'Vire acentuadamente à direita',
    'slight right' => 'Vire levemente à direita',
    'uturn'        => 'Faça o retorno',
    _              => 'Continue em frente',
  };
}

// ─────────────────────────────────────────────────────────────
//  Peek de navegação: foco total na próxima manobra
// ─────────────────────────────────────────────────────────────
class _NavigatingPeek extends StatelessWidget {
  const _NavigatingPeek({
    required this.tc,
    required this.kmh,
    required this.cardinal,
    required this.onStop,
  });

  final TruckController tc;
  final double kmh;
  final String cardinal;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final step = tc.nextStep;
    final maneuverIcon = step != null
        ? _maneuverIcon(step.type, step.modifier)
        : Icons.navigation_rounded;
    final instruction = step != null
        ? _maneuverLabel(step.type, step.modifier)
        : 'Continue em frente';
    final streetName = step?.streetName ?? '';
    final distanceText = step?.formattedDistance ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Ícone de manobra destacado ───────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.safeSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.safeBorder),
            ),
            child: Icon(
              maneuverIcon,
              color: AppColors.safe,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),

          // ── Instrução + rua ─────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Distância para a manobra (em destaque)
                if (distanceText.isNotEmpty)
                  Text(
                    distanceText,
                    style: const TextStyle(
                      color: AppColors.safe,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                // Instrução da manobra
                Text(
                  instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (streetName.isNotEmpty)
                  Text(
                    streetName,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                // Linha de ETA + fadiga
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (tc.formattedETA.isNotEmpty) ...[
                      Icon(
                        Icons.schedule_rounded,
                        size: 10,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        tc.formattedETA,
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (tc.drivingSeconds > 0) _FatigueTimer(tc: tc),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Velocidade + Botão PARAR ───────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Speedometer(kmh: kmh, cardinal: cardinal),
              const SizedBox(height: 6),
              _GoButton(
                isNavigating: true,
                onTap: onStop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Divisor de seção reutilizável
// ─────────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.divider,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Velocímetro compacto
// ─────────────────────────────────────────────────────────────
class _Speedometer extends StatelessWidget {
  const _Speedometer({required this.kmh, required this.cardinal});

  final double kmh;
  final String cardinal;

  Color get _speedColor {
    if (kmh > 90) return AppColors.danger;
    if (kmh > 60) return AppColors.attention;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kmh.toStringAsFixed(0),
          style: TextStyle(
            color: _speedColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'km/h',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          cardinal,
          style: TextStyle(
            color: AppColors.blue.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Botão GO / PARAR
// ─────────────────────────────────────────────────────────────
class _GoButton extends StatelessWidget {
  const _GoButton({required this.isNavigating, required this.onTap});

  final bool isNavigating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 68,
        height: 44,
        decoration: BoxDecoration(
          color: isNavigating ? AppColors.danger : AppColors.blue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isNavigating ? AppColors.danger : AppColors.blue)
                  .withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            isNavigating ? 'PARAR' : 'GO',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Chip de ação
// ─────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Botão de encerrar rota — destaque vermelho separado
// ─────────────────────────────────────────────────────────────
class _EndRouteButton extends StatelessWidget {
  const _EndRouteButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.dangerFaint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.dangerBorderStrong,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.stop_circle_outlined,
                color: AppColors.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Encerrar Rota',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
