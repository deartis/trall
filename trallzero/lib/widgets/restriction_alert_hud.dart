import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/marker_model.dart';
import '../controllers/truck_controller.dart';
import '../core/app_colors.dart';

/// HUD de alta prioridade: exibe um banner vermelho pulsante quando
/// ha uma restricao de altura ou peso INCOMPATIVEL com o veiculo a frente.
class RestrictionAlertHud extends StatefulWidget {
  const RestrictionAlertHud({
    super.key,
    required this.markers,
    required this.currentPosition,
    required this.routePoints,
    this.onRecalculate,
  });

  final List<TruckerMarker> markers;
  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final VoidCallback? onRecalculate;

  @override
  State<RestrictionAlertHud> createState() => _RestrictionAlertHudState();
}

class _RestrictionAlertHudState extends State<RestrictionAlertHud>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  static const _warningRangeMeters = 3000.0;
  static const _dismissRangeMeters = 80.0;

  @override
  Widget build(BuildContext context) {
    final pos = widget.currentPosition;
    if (pos == null || widget.routePoints.isEmpty || _dismissed) {
      return const SizedBox.shrink();
    }

    final tc = context.watch<TruckController>();
    final profile = tc.truckProfile;

    final restriction = _findRestrictionAhead(pos);
    if (restriction == null) return const SizedBox.shrink();

    final dist = _distanceTo(pos, restriction.position);
    final distLabel = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(1)} km'
        : '${dist.toInt()} m';

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0808).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.danger.withValues(alpha: _pulseAnim.value * 0.85),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: _pulseAnim.value * 0.30),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.report_rounded,
                      color: AppColors.danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESTRICAO A FRENTE — $distLabel',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          restriction.description.isNotEmpty
                              ? restriction.description
                              : 'Verifique a via a frente',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Badge(
                      icon: Icons.height_rounded,
                      label: 'Seu veiculo',
                      value: '${profile.maxHeightMeters.toStringAsFixed(1)} m',
                      color: AppColors.danger,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withValues(alpha: 0.25),
                      size: 14,
                    ),
                  ),
                  Expanded(
                    child: _Badge(
                      icon: Icons.scale_rounded,
                      label: 'Via',
                      value: '${profile.maxWeightKg ~/ 1000} t',
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onRecalculate?.call();
                      },
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withValues(alpha: 0.40),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.alt_route_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Recalcular Rota',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _dismissed = true);
                    },
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Center(
                        child: Text(
                          'Ignorar',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
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

  TruckerMarker? _findRestrictionAhead(LatLng pos) {
    for (final m in widget.markers) {
      if (m.type != MarkerType.restriction) continue;
      final dist = _distanceTo(pos, m.position);
      if (dist < _dismissRangeMeters || dist > _warningRangeMeters) continue;
      if (!_isAhead(pos, m.position)) continue;
      return m;
    }
    return null;
  }

  bool _isAhead(LatLng pos, LatLng markerPos) {
    if (widget.routePoints.length < 2) return true;
    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < widget.routePoints.length; i++) {
      final d = _distanceTo(pos, widget.routePoints[i]);
      if (d < minDist) { minDist = d; closestIdx = i; }
    }
    int markerIdx = 0;
    double markerMinDist = double.infinity;
    for (int i = 0; i < widget.routePoints.length; i++) {
      final d = _distanceTo(markerPos, widget.routePoints[i]);
      if (d < markerMinDist) { markerMinDist = d; markerIdx = i; }
    }
    return markerIdx > closestIdx;
  }

  double _distanceTo(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: color.withValues(alpha: 0.70), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, height: 1.0)),
            ],
          ),
        ],
      ),
    );
  }
}
