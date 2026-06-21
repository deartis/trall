import 'package:flutter/material.dart';
import '../models/road_analysis.dart';

/// Barra horizontal que mostra os próximos quilômetros da rota
/// coloridos por nível de risco. Um triângulo branco indica a posição atual.
class RouteRiskBar extends StatelessWidget {
  const RouteRiskBar({
    super.key,
    required this.segments,
    required this.totalDistanceMeters,
    required this.progressMeters,
  });

  final List<RoadSegmentAnalysis> segments;
  final double totalDistanceMeters;
  final double progressMeters;

  Color _colorForLevel(RoadHazardLevel level) {
    switch (level) {
      case RoadHazardLevel.safe:
        return const Color(0xFF34C759);
      case RoadHazardLevel.attention:
        return const Color(0xFFFF9500);
      case RoadHazardLevel.heavy:
        return const Color(0xFFFF6B00);
      case RoadHazardLevel.avoid:
        return const Color(0xFFFF3B30);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty || totalDistanceMeters <= 0) {
      // Sem análise ainda: mostra barra neutra
      return Container(
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    final progressRatio = (progressMeters / totalDistanceMeters).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Text(
                'PERFIL DA ROTA',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                _riskSummary(),
                style: TextStyle(
                  color: _colorForLevel(_maxLevel()),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Barra de risco + indicador de posição
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final indicatorX = (progressRatio * barWidth).clamp(0.0, barWidth - 2);

              return SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Segmentos coloridos
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          children: segments.map((seg) {
                            final ratio =
                                (seg.distanceMeters / totalDistanceMeters)
                                    .clamp(0.0, 1.0);
                            return Flexible(
                              flex: (ratio * 10000).round(),
                              child: Tooltip(
                                message: seg.description,
                                child: Container(
                                  height: 8,
                                  color: _colorForLevel(seg.hazardLevel),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Indicador de posição (triângulo / linha)
                    Positioned(
                      left: indicatorX,
                      top: 0,
                      child: Container(
                        width: 2.5,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  RoadHazardLevel _maxLevel() {
    if (segments.isEmpty) return RoadHazardLevel.safe;
    return segments.map((s) => s.hazardLevel).reduce(
      (a, b) => a.index > b.index ? a : b,
    );
  }

  String _riskSummary() {
    switch (_maxLevel()) {
      case RoadHazardLevel.safe:
        return 'ROTA SEGURA';
      case RoadHazardLevel.attention:
        return 'ATENÇÃO';
      case RoadHazardLevel.heavy:
        return 'TRECHO PESADO';
      case RoadHazardLevel.avoid:
        return 'RISCO ALTO';
    }
  }
}
