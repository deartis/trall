import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../controllers/truck_controller.dart';
import '../models/truck_profile.dart';
import '../core/app_colors.dart';
import '../services/tts_service.dart';

/// HUD de Alerta de Declive de Serra & Curva Fechada (Risco de Tombamento).
/// Avisa com antecedência quando há descidas fortes ou curvas muito fechadas.
class SlopeAndRollWarningHud extends StatefulWidget {
  const SlopeAndRollWarningHud({
    super.key,
    required this.currentPosition,
    required this.speedKmh,
  });

  final LatLng? currentPosition;
  final double speedKmh;

  @override
  State<SlopeAndRollWarningHud> createState() => _SlopeAndRollWarningHudState();
}

class _SlopeAndRollWarningHudState extends State<SlopeAndRollWarningHud>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String? _lastSpokenWarningId;
  bool _dismissed = false;
  String? _activeWarningKey;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.currentPosition;
    if (pos == null) return const SizedBox.shrink();

    final tc = context.watch<TruckController>();
    if (!tc.isNavigating || tc.routePoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final profile = tc.truckProfile;
    final warning = _detectUpcomingHazard(pos, tc, profile);

    if (warning == null) {
      _dismissed = false;
      _activeWarningKey = null;
      return const SizedBox.shrink();
    }

    if (_activeWarningKey != warning.id) {
      _activeWarningKey = warning.id;
      _dismissed = false;
    }

    if (_dismissed) return const SizedBox.shrink();

    // Dispara alerta de voz uma única vez por evento detectado
    if (_lastSpokenWarningId != warning.id) {
      _lastSpokenWarningId = warning.id;
      TtsService.instance.speak(warning.voiceText);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: AnimatedBuilder(
        key: ValueKey(warning.id),
        animation: _pulseAnim,
        builder: (context, child) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF160E08).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: warning.color.withValues(alpha: _pulseAnim.value * 0.8),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: warning.color.withValues(alpha: _pulseAnim.value * 0.25),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Ícone animado com gradiente
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: warning.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: warning.color.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    warning.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Textos de título e recomendação
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          warning.title,
                          style: TextStyle(
                            color: warning.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: warning.color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            warning.tag,
                            style: TextStyle(
                              color: warning.color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      warning.advice,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Botão dispensar
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _dismissed = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.50),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _HazardWarning? _detectUpcomingHazard(
    LatLng pos,
    TruckController tc,
    TruckProfile profile,
  ) {
    const distCalc = Distance();

    // 1. Verifica manobra de curva acentuada (sharp turn) próxima (< 500m)
    final step = tc.nextStep;
    if (step != null &&
        (step.modifier.contains('sharp') || step.modifier.contains('uturn'))) {
      final stepDist = tc.distanceToNextStepMeters ?? step.distance;
      if (stepDist > 15 && stepDist <= 450) {
        final distRounded = (stepDist / 10).round() * 10;
        final isSharpLeft = step.modifier.contains('left');
        return _HazardWarning(
          id: 'turn_${step.location.latitude}_${step.location.longitude}',
          title: isSharpLeft
              ? 'Curva Acentuada à Esquerda'
              : 'Curva Acentuada à Direita',
          tag: 'Em ${distRounded}m',
          advice: 'Reduza a velocidade. Risco de tombamento com carga pesada.',
          voiceText:
              'Atenção. Curva acentuada a $distRounded metros. Reduza a velocidade.',
          color: const Color(0xFFFF9500),
          emoji: isSharpLeft ? '↩️' : '↪️',
        );
      }
    }

    // 2. Verifica declives acentuados de serra nos segmentos da rota (< 800m)
    final maxSlopeAllowed = profile.recommendedMaxSlope;
    for (final seg in tc.routeAnalysisSegments) {
      final distToStart = distCalc.as(LengthUnit.Meter, pos, seg.start);
      // Se está a menos de 700m e o declive é forte (descida > maxSlopeAllowed ou > 7%)
      if (distToStart > 10 && distToStart <= 700 && seg.slopePercent < -6.5) {
        final slopeAbs = seg.slopePercent.abs().toStringAsFixed(1);
        final distRounded = (distToStart / 10).round() * 10;
        final isSevere = seg.slopePercent <= -10.0;

        return _HazardWarning(
          id: 'slope_${seg.start.latitude}_${seg.start.longitude}',
          title: isSevere ? 'Declive Severo de Serra' : 'Declive Acentuado',
          tag: 'Inclinação -$slopeAbs%',
          advice:
              'A $distRounded m: Engate marcha reduzida e acione o freio motor.',
          voiceText:
              'Atenção. Declive de serra a $distRounded metros com inclinação de $slopeAbs por cento. Use o freio motor.',
          color: isSevere ? AppColors.danger : const Color(0xFFFF9500),
          emoji: '📉',
        );
      }
    }

    return null;
  }
}

class _HazardWarning {
  final String id;
  final String title;
  final String tag;
  final String advice;
  final String voiceText;
  final Color color;
  final String emoji;

  _HazardWarning({
    required this.id,
    required this.title,
    required this.tag,
    required this.advice,
    required this.voiceText,
    required this.color,
    required this.emoji,
  });
}
