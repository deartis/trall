import 'package:flutter/material.dart';
import '../models/marker_model.dart';
import '../services/marker_deduplication_service.dart';

/// Modal para confirmação de alerta existente ou resolução de conflito de marcação (estilo Waze)
class MarkerConflictSheet extends StatelessWidget {
  final DeduplicationResult result;
  final MarkerType proposedType;
  final VoidCallback onConfirmExisting;
  final VoidCallback onReplaceExisting;
  final VoidCallback onKeepBoth;
  final VoidCallback? onNotThereAnymore;

  const MarkerConflictSheet({
    super.key,
    required this.result,
    required this.proposedType,
    required this.onConfirmExisting,
    required this.onReplaceExisting,
    required this.onKeepBoth,
    this.onNotThereAnymore,
  });

  static Color colorFor(MarkerType t) => switch (t) {
    MarkerType.loading => const Color(0xFF34C759),
    MarkerType.restriction => const Color(0xFFFF3B30),
    MarkerType.weighStation => const Color(0xFFFF9500),
    MarkerType.parking => const Color(0xFFAF52DE),
    MarkerType.police => const Color(0xFF1E90FF),
    MarkerType.danger => const Color(0xFFFF0000),
    MarkerType.gasStation => const Color(0xFFF59E0B),
    MarkerType.mechanic => const Color(0xFF6B7280),
    MarkerType.restaurant => const Color(0xFFEC4899),
    MarkerType.speedCamera => const Color(0xFF00C7FF),
    MarkerType.other => const Color(0xFF8E8E93),
  };

  static IconData iconFor(MarkerType t) => switch (t) {
    MarkerType.loading => Icons.import_export_rounded,
    MarkerType.restriction => Icons.block_rounded,
    MarkerType.weighStation => Icons.scale_rounded,
    MarkerType.parking => Icons.local_parking_rounded,
    MarkerType.police => Icons.local_police_rounded,
    MarkerType.danger => Icons.warning_rounded,
    MarkerType.gasStation => Icons.local_gas_station_rounded,
    MarkerType.mechanic => Icons.build_circle_rounded,
    MarkerType.restaurant => Icons.restaurant_rounded,
    MarkerType.speedCamera => Icons.camera_alt_rounded,
    MarkerType.other => Icons.info_rounded,
  };

  static String labelFor(MarkerType t) => switch (t) {
    MarkerType.loading => 'Carga/Descarga',
    MarkerType.restriction => 'Restrição',
    MarkerType.weighStation => 'Balança',
    MarkerType.parking => 'Pátio de Descanso',
    MarkerType.police => 'Polícia Rodoviária',
    MarkerType.danger => 'Área de Perigo',
    MarkerType.gasStation => 'Posto de Combustível',
    MarkerType.mechanic => 'Oficina Mecânica',
    MarkerType.restaurant => 'Ponto de Parada',
    MarkerType.speedCamera => 'Radar de Velocidade',
    MarkerType.other => 'Outros',
  };

  @override
  Widget build(BuildContext context) {
    final existing = result.existingMarker;
    final isConfirmation = result.canConfirm;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111318),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pílula superior
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (isConfirmation && existing != null)
            _buildConfirmationContent(context, existing)
          else if (existing != null)
            _buildConflictContent(context, existing),
        ],
      ),
    );
  }

  /// Layout para quando já existe um alerta do MESMO tipo
  Widget _buildConfirmationContent(BuildContext context, TruckerMarker existing) {
    final color = colorFor(existing.type);
    final distText = MarkerDeduplicationService.formatDistance(
      result.distanceMeters ?? 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge de Alerta Detectado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'ALERTA JÁ REGISTRADO A $distText',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Este ${labelFor(existing.type).toLowerCase()} já foi marcado!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Para não poluir o mapa com pins duplicados, confirme se ele continua no local.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),

        // Contador de confirmações
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_alt_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Confirmado por ${existing.confirmations} motorista${existing.confirmations > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Botão Principal: Confirmar Presença (Upvote)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
            ),
            icon: const Icon(Icons.thumb_up_rounded, size: 20),
            label: const Text(
              'Sim, ainda está lá! (Confirmar)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirmExisting();
            },
          ),
        ),
        const SizedBox(height: 10),

        // Botão Secundário: Não está mais lá
        if (onNotThereAnymore != null) ...[
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF453A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.thumb_down_rounded, size: 18),
              label: const Text(
                'Não está mais lá (remover alerta)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                Navigator.pop(context);
                onNotThereAnymore?.call();
              },
            ),
          ),
        ],

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Voltar',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Layout para quando há um CONFLITO (tipos diferentes no mesmo ponto)
  Widget _buildConflictContent(BuildContext context, TruckerMarker existing) {
    final existColor = colorFor(existing.type);
    final proposedColor = colorFor(proposedType);
    final distText = MarkerDeduplicationService.formatDistance(
      result.distanceMeters ?? 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge de Conflito
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF9500).withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500), size: 18),
              SizedBox(width: 8),
              Text(
                'ALERTA JÁ EXISTENTE NESTE LOCAL',
                style: TextStyle(
                  color: Color(0xFFFF9500),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Já existe outra marcação neste trecho',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A $distText à frente há um alerta registrado. O que você deseja fazer?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),

        // Comparação Visual (Existente vs Novo)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Existente
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'ATUAL NO MAPA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: existColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: existColor, width: 1.5),
                      ),
                      child: Icon(iconFor(existing.type), color: existColor, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labelFor(existing.type),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: existColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.3),
              ),

              // Novo
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'SEU REPORTE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: proposedColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: proposedColor, width: 1.5),
                      ),
                      child: Icon(iconFor(proposedType), color: proposedColor, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labelFor(proposedType),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: proposedColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Opção 1: Corrigir / Substituir
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.sync_rounded, size: 20),
            label: Text(
              'Corrigir para ${labelFor(proposedType)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              Navigator.pop(context);
              onReplaceExisting();
            },
          ),
        ),
        const SizedBox(height: 10),

        // Opção 2: Manter ambos
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'Manter ambos (são eventos distintos)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              Navigator.pop(context);
              onKeepBoth();
            },
          ),
        ),
        const SizedBox(height: 6),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
