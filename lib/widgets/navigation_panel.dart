import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/truck_controller.dart';
import 'avoid_options_sheet.dart';
import '../screens/settings_screen.dart';

// ─────────────────────────────────────────────────────────────
//  NavigationPanel
//
//  Substitui o painel inline do MapScreen. Uso:
//
//    if (tc.routePoints.isNotEmpty && tc.suggestions.isEmpty)
//      Positioned(
//        left: 0, right: 0, bottom: 0,
//        child: NavigationPanel(
//          heading: _heading,
//          speed: _lastKnownSpeed,
//          onGo: () { ... },
//          onStop: () { ... },
//        ),
//      ),
// ─────────────────────────────────────────────────────────────

class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.heading,
    required this.speed,
    required this.onGo,
    required this.onStop,
    this.onProfileTap,
    this.onRoutesTap,
  });

  final double heading;
  final double speed;
  final VoidCallback onGo;
  final VoidCallback onStop;
  final VoidCallback? onProfileTap;
  final VoidCallback? onRoutesTap;

  // Converte m/s para km/h
  double get _kmh => speed * 3.6;

  // Converte heading em texto cardinal
  String get _cardinal {
    const dirs = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    return dirs[((heading + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    final isNavigating = tc.isNavigating;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1017),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isNavigating
                ? const Color(0xFF34C759).withValues(alpha: 0.3)
                : const Color(0xFF2563EB).withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Linha principal: tempo + distância + velocidade ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Ícone de status
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isNavigating
                        ? const Color(0xFF34C759).withValues(alpha: 0.12)
                        : const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isNavigating
                        ? Icons.navigation_rounded
                        : Icons.route_rounded,
                    color: isNavigating
                        ? const Color(0xFF34C759)
                        : const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Tempo
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
                      style: TextStyle(
                        color: isNavigating
                            ? const Color(0xFF34C759)
                            : const Color(0xFF2563EB),
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
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            tc.formattedETA,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (tc.drivingSeconds > 0) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.timer_rounded,
                              size: 11,
                              color: tc.hasFatigueAlert
                                  ? const Color(0xFFFF3B30)
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tc.formattedDrivingTime,
                              style: TextStyle(
                                color: tc.hasFatigueAlert
                                    ? const Color(0xFFFF3B30)
                                    : Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),

                const Spacer(),

                // Velocímetro (só aparece em navegação)
                if (isNavigating) ...[
                  _Speedometer(kmh: _kmh, cardinal: _cardinal),
                  const SizedBox(width: 12),
                ],

                // Botão GO / PARAR
                _GoButton(
                  isNavigating: isNavigating,
                  onTap: isNavigating ? onStop : onGo,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Chips de perfil / ações ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                _Chip(
                  icon: Icons.settings_rounded,
                  label: 'Ajustes',
                  color: Colors.white.withValues(alpha: 0.5),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _Chip(
                  icon: Icons.block_rounded,
                  label: 'Evitar',
                  color: tc.avoidTolls || tc.avoidFerries || tc.avoidUnpaved
                      ? const Color(0xFFFF3B30)
                      : Colors.white.withValues(alpha: 0.5),
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
                  color: Colors.white.withValues(alpha: 0.5),
                  onTap: onRoutesTap ?? () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Divisor com label ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'PRÓXIMA PARADA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Próxima instrução de manobra ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Builder(builder: (context) {
              final step = tc.nextStep;
              final icon = step != null
                  ? _maneuverIcon(step.type, step.modifier)
                  : Icons.flag_rounded;
              final mainText = step != null
                  ? _maneuverLabel(step.type, step.modifier)
                  : (isNavigating ? 'Continue em frente' : 'Toque em GO para iniciar');
              final subText = step != null
                  ? '${step.formattedDistance}${step.streetName.isNotEmpty ? ' — ${step.streetName}' : ''}'
                  : (isNavigating ? '' : 'A rota está calculada e pronta');

              return Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.8),
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
                        if (subText.isNotEmpty)
                          Text(
                            subText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
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
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              );
            }),
          ),

          // Safe area bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
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
    'left'          => Icons.turn_left_rounded,
    'sharp left'    => Icons.turn_sharp_left_rounded,
    'slight left'   => Icons.turn_slight_left_rounded,
    'right'         => Icons.turn_right_rounded,
    'sharp right'   => Icons.turn_sharp_right_rounded,
    'slight right'  => Icons.turn_slight_right_rounded,
    'uturn'         => Icons.u_turn_left_rounded,
    _               => Icons.straight_rounded,
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
    'left'          => 'Vire à esquerda',
    'sharp left'    => 'Vire acentuadamente à esquerda',
    'slight left'   => 'Vire levemente à esquerda',
    'right'         => 'Vire à direita',
    'sharp right'   => 'Vire acentuadamente à direita',
    'slight right'  => 'Vire levemente à direita',
    'uturn'         => 'Faça o retorno',
    _               => 'Continue em frente',
  };
}

// ─────────────────────────────────────────────────────────────
//  Velocímetro compacto
// ─────────────────────────────────────────────────────────────
class _Speedometer extends StatelessWidget {
  const _Speedometer({required this.kmh, required this.cardinal});

  final double kmh;
  final String cardinal;

  Color get _speedColor {
    if (kmh > 90) return const Color(0xFFFF3B30);
    if (kmh > 60) return const Color(0xFFFF9500);
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
            color: const Color(0xFF2563EB).withValues(alpha: 0.8),
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
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 76,
        height: 52,
        decoration: BoxDecoration(
          color: isNavigating
              ? const Color(0xFFFF3B30)
              : const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (isNavigating
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF2563EB))
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
              fontSize: 16,
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
