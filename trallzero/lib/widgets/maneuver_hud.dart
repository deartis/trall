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
    final distance = step?.formattedDistance ?? '';
    final street = step?.streetName ?? '';

    // Cor de destaque baseada no tipo de manobra
    final accentColor = _accentColor(step?.type ?? '', step?.modifier ?? '');

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // Glassmorphism sutil: fundo semi-transparente com blur
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
            // ── Ícone de manobra ─────────────────────────────────────
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),

            const SizedBox(width: 12),

            // ── Texto da instrução ────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Distância em destaque (cor de acento)
                  if (distance.isNotEmpty)
                    Text(
                      distance,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  // Instrução principal — grande e bold
                  Text(
                    instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Nome da rua — secundário
                  if (street.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      street,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── Divisor vertical + dados secundários ──────────────────
            if (tc.formattedDistance.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 36,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      fontFeatures: [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tc.formattedDuration,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
