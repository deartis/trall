import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/delivery_stop.dart';
import '../models/marker_model.dart';
import '../core/app_colors.dart';

/// Modelo interno para um item na timeline da rodovia
class HighwayEvent {
  final String title;
  final String subtitle;
  final double distanceMeters;
  final LatLng position;
  final IconData icon;
  final Color color;
  final String emoji;

  HighwayEvent({
    required this.title,
    required this.subtitle,
    required this.distanceMeters,
    required this.position,
    required this.icon,
    required this.color,
    required this.emoji,
  });
}

/// Timeline da Rodovia (Highway Corridor View):
/// Mostra os próximos eventos na rodovia em ordem de chegada ao longo da rota
/// (Balanças, Postos, Pátios, Paradas de Entrega, Radares).
class HighwayCorridorTimeline extends StatefulWidget {
  const HighwayCorridorTimeline({
    super.key,
    required this.currentPosition,
    required this.routePoints,
    required this.markers,
    required this.deliveryStops,
    this.onSelectPoint,
  });

  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final List<TruckerMarker> markers;
  final List<DeliveryStop> deliveryStops;
  final void Function(LatLng point)? onSelectPoint;

  @override
  State<HighwayCorridorTimeline> createState() => _HighwayCorridorTimelineState();
}

class _HighwayCorridorTimelineState extends State<HighwayCorridorTimeline> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final pos = widget.currentPosition;
    if (pos == null || widget.routePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final events = _computeUpcomingEvents(pos);
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Botão toggle (recolher / expandir)
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF111318).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  color: AppColors.amber,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  _isExpanded ? 'RODOVIA' : 'NA ROTA (${events.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_left_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),

        // Lista de eventos da timeline
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 260),
          crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          secondChild: const SizedBox.shrink(),
          firstChild: Container(
            width: 175,
            constraints: const BoxConstraints(maxHeight: 260),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1017).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: events.take(4).length,
              separatorBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(left: 13, top: 3, bottom: 3),
                height: 8,
                width: 1.5,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              itemBuilder: (context, i) {
                final ev = events[i];
                final distText = ev.distanceMeters >= 1000
                    ? '${(ev.distanceMeters / 1000).toStringAsFixed(1)} km'
                    : '${ev.distanceMeters.toInt()} m';

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSelectPoint?.call(ev.position);
                  },
                  child: Row(
                    children: [
                      // Círculo com ícone temático
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ev.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ev.color.withValues(alpha: 0.40),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            ev.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Textos do evento
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    ev.title,
                                    style: TextStyle(
                                      color: ev.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  distText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [ui.FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                            if (ev.subtitle.isNotEmpty)
                              Text(
                                ev.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
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
          ),
        ),
      ],
    );
  }

  List<HighwayEvent> _computeUpcomingEvents(LatLng pos) {
    final list = <HighwayEvent>[];
    const distanceCalc = Distance();

    // 1. Processa marcadores de interesse ao longo da rota
    for (final m in widget.markers) {
      final dist = distanceCalc.as(LengthUnit.Meter, pos, m.position);
      if (dist < 100 || dist > 120000) continue; // até 120 km à frente
      if (!_isAheadOnRoute(pos, m.position)) continue;

      final (title, emoji, color) = _markerInfo(m.type);
      list.add(HighwayEvent(
        title: title,
        subtitle: m.description,
        distanceMeters: dist,
        position: m.position,
        icon: Icons.place_rounded,
        color: color,
        emoji: emoji,
      ));
    }

    // 2. Processa paradas de entrega ativas
    for (int i = 0; i < widget.deliveryStops.length; i++) {
      final stop = widget.deliveryStops[i];
      if (stop.isCompleted) continue;
      final stopPos = LatLng(stop.lat, stop.lng);
      final dist = distanceCalc.as(LengthUnit.Meter, pos, stopPos);
      if (dist < 100) continue;

      list.add(HighwayEvent(
        title: 'Parada ${i + 1}',
        subtitle: stop.recipientName.isNotEmpty ? stop.recipientName : stop.address,
        distanceMeters: dist,
        position: stopPos,
        icon: Icons.flag_rounded,
        color: const Color(0xFF34C759),
        emoji: '📍',
      ));
    }

    // Ordena pelo mais próximo
    list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return list;
  }

  (String, String, Color) _markerInfo(MarkerType type) => switch (type) {
    MarkerType.weighStation => ('Balança', '⚖️', const Color(0xFFFF9500)),
    MarkerType.gasStation   => ('Posto', '⛽', const Color(0xFFF59E0B)),
    MarkerType.parking      => ('Pátio', '🅿️', const Color(0xFFAF52DE)),
    MarkerType.mechanic     => ('Oficina', '🔧', const Color(0xFF6B7280)),
    MarkerType.restriction  => ('Restrição', '🚫', const Color(0xFFFF3B30)),
    MarkerType.danger       => ('Perigo', '⚠️', const Color(0xFFFF3B30)),
    MarkerType.police       => ('Polícia', '🚔', const Color(0xFF1E90FF)),
    MarkerType.speedCamera  => ('Radar', '📸', const Color(0xFF00C7FF)),
    MarkerType.restaurant   => ('Parada', '🍽️', const Color(0xFFEC4899)),
    _                       => ('Ponto', '📍', const Color(0xFF8E8E93)),
  };

  bool _isAheadOnRoute(LatLng pos, LatLng target) {
    if (widget.routePoints.length < 2) return true;
    const distanceCalc = Distance();
    int userIdx = 0;
    double minUserDist = double.infinity;
    for (int i = 0; i < widget.routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, pos, widget.routePoints[i]);
      if (d < minUserDist) {
        minUserDist = d;
        userIdx = i;
      }
    }
    int targetIdx = 0;
    double minTargetDist = double.infinity;
    for (int i = 0; i < widget.routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, target, widget.routePoints[i]);
      if (d < minTargetDist) {
        minTargetDist = d;
        targetIdx = i;
      }
    }
    return targetIdx >= userIdx;
  }
}
