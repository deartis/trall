import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/marker_model.dart';

/// HUD de alerta proativo: exibe um banner sutil no topo do mapa
/// quando há marcadores críticos a menos de 5 km à frente na rota.
class ProactiveAlertHud extends StatelessWidget {
  const ProactiveAlertHud({
    super.key,
    required this.markers,
    required this.currentPosition,
    required this.routePoints,
    this.onTapMarker,
  });

  final List<TruckerMarker> markers;
  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final void Function(TruckerMarker)? onTapMarker;

  // Tipos que merecem alerta proativo (ordem de prioridade)
  static const _alertTypes = [
    MarkerType.weighStation,
    MarkerType.restriction,
    MarkerType.danger,
    MarkerType.police,
    MarkerType.speedCamera,
  ];

  static const _alertRangeMeters = 5000.0;
  static const _dismissRangeMeters = 100.0;

  @override
  Widget build(BuildContext context) {
    final pos = currentPosition;
    if (pos == null || routePoints.isEmpty || markers.isEmpty) {
      return const SizedBox.shrink();
    }

    final ahead = _findAheadAlerts(pos);
    if (ahead.isEmpty) return const SizedBox.shrink();

    // Pega o mais urgente (mais próximo de um tipo prioritário)
    final target = ahead.first;
    final dist = _distanceTo(pos, target.marker.position);
    final distLabel = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(1)} km'
        : '${dist.toInt()} m';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: GestureDetector(
        key: ValueKey(target.marker.id),
        onTap: () => onTapMarker?.call(target.marker),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111318).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: target.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: target.color.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone pulsante
              _PulsingIcon(icon: target.icon, color: target.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      target.label,
                      style: TextStyle(
                        color: target.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Em $distLabel — ${target.marker.description}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge de alertas adicionais
              if (ahead.length > 1)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    '+${ahead.length - 1}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Retorna TODOS os alertas à frente (para o badge de contagem)
  List<_AlertEntry> _findAheadAlerts(LatLng pos) {
    final results = <_AlertEntry>[];

    for (final type in _alertTypes) {
      final ofType = markers.where((m) => m.type == type).toList();
      for (final m in ofType) {
        final dist = _distanceTo(pos, m.position);
        if (dist < _dismissRangeMeters || dist > _alertRangeMeters) continue;
        if (!_isAhead(pos, m.position)) continue;

        results.add(_AlertEntry(
          marker: m,
          distance: dist,
          label: _labelFor(type),
          icon: _iconFor(type),
          color: _colorFor(type),
        ));
      }
    }

    results.sort((a, b) => a.distance.compareTo(b.distance));
    return results; // retorna TODOS (para o badge)
  }

  bool _isAhead(LatLng pos, LatLng markerPos) {
    if (routePoints.length < 2) return true;

    // Encontra o ponto mais próximo na rota à posição atual
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final d = _distanceTo(pos, routePoints[i]);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    // Encontra o ponto mais próximo na rota ao marcador
    int markerIdx = 0;
    double markerMinDist = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final d = _distanceTo(markerPos, routePoints[i]);
      if (d < markerMinDist) {
        markerMinDist = d;
        markerIdx = i;
      }
    }

    return markerIdx > closestIdx;
  }

  double _distanceTo(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  String _labelFor(MarkerType t) => switch (t) {
    MarkerType.weighStation => '⚖️  Balança à frente',
    MarkerType.restriction  => '🚫  Restrição à frente',
    MarkerType.danger       => '⚠️  Perigo à frente',
    MarkerType.police       => '🚔  Fiscalização à frente',
    MarkerType.speedCamera  => '📸  Radar à frente',
    _                       => 'Alerta à frente',
  };

  IconData _iconFor(MarkerType t) => switch (t) {
    MarkerType.weighStation => Icons.scale_rounded,
    MarkerType.restriction  => Icons.block_rounded,
    MarkerType.danger       => Icons.warning_rounded,
    MarkerType.police       => Icons.local_police_rounded,
    MarkerType.speedCamera  => Icons.camera_alt_rounded,
    _                       => Icons.info_rounded,
  };

  Color _colorFor(MarkerType t) => switch (t) {
    MarkerType.weighStation => const Color(0xFFFF9500),
    MarkerType.restriction  => const Color(0xFFFF3B30),
    MarkerType.danger       => const Color(0xFFFF3B30),
    MarkerType.police       => const Color(0xFF1E90FF),
    MarkerType.speedCamera  => const Color(0xFF00C7FF),
    _                       => const Color(0xFF8E8E93),
  };
}

class _AlertEntry {
  final TruckerMarker marker;
  final double distance;
  final String label;
  final IconData icon;
  final Color color;

  _AlertEntry({
    required this.marker,
    required this.distance,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Ícone com leve pulsação para chamar atenção
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, color: widget.color, size: 18),
        ),
      ),
    );
  }
}
