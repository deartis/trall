import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/truck_controller.dart';
import '../core/app_colors.dart';

/// HUD de manobra fixo no topo da tela — exibido apenas durante navegação ativa.
///
/// Mostra a próxima instrução de forma grande e clara, sem precisar
/// que o usuário interaja com o NavigationPanel.
///
/// Layout:
///   ┌─────────────────────────────────────────┐
///   │  [ícone]  Em X metros  |  Rua da...     │
///   │           Vire à esquerda               │
///   └─────────────────────────────────────────┘
class ManeuverHud extends StatelessWidget {
  const ManeuverHud({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    if (!tc.isNavigating || tc.routePoints.isEmpty) return const SizedBox.shrink();

    final step = tc.nextStep;
    final icon = step != null
        ? _maneuverIcon(step.type, step.modifier)
        : Icons.navigation_rounded;
    final instruction = step != null
        ? _maneuverLabel(step.type, step.modifier)
        : 'Continue em frente';
    final distance = tc.formattedDistanceToNextStep;
    final street = step?.streetName ?? '';

    // Cor de destaque baseada no tipo de manobra
    final accentColor = _accentColor(step?.type ?? '', step?.modifier ?? '');

    // Calcula progresso do percurso (0.0 a 1.0)
    final double routeProgress = tc.routeProgressFraction.clamp(0.0, 1.0);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Bloco principal do HUD ──────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1017).withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.30),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Ícone de manobra — 72×72 para máxima legibilidade ──
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 34),
                ),

                const SizedBox(width: 14),

                // ── Texto da instrução ────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Distância em destaque — maior e mais visível
                      if (distance.isNotEmpty)
                        Text(
                          distance,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      // Instrução principal — 22px para leitura rápida
                      Text(
                        instruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Nome da rua — secundário
                      if (street.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          street,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Divisor + Resumo da viagem ────────────────────────
                if (tc.formattedDistance.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 44,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tc.formattedDistance,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          fontFeatures: [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tc.formattedDuration,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                      if (tc.formattedETA.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          tc.formattedETA,
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Barra de progresso do percurso ──────────────────────────
          if (routeProgress > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: routeProgress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    accentColor.withValues(alpha: 0.80),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Cor de acento baseada na urgência/tipo de manobra
  Color _accentColor(String type, String modifier) {
    if (type == 'arrive') return AppColors.safe;
    if (modifier.contains('sharp')) return AppColors.attention; // curva fechada
    if (modifier == 'uturn') return AppColors.danger;
    if (type == 'roundabout' || type == 'rotary') return AppColors.amber;
    return AppColors.safe;
  }
}

// ──────────────────────────────────────────────────────────────
//  Helpers locais (mesma lógica do navigation_panel.dart)
// ──────────────────────────────────────────────────────────────

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
