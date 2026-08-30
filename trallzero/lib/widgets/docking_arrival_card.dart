import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../controllers/truck_controller.dart';
import '../core/app_colors.dart';
import '../core/app_snackbar.dart';
import '../services/ocr_service.dart';

/// Card do Modo Chegada & Docagem de Carga.
/// Surge suavemente quando o caminhão está a menos de 450m do destino final.
class DockingArrivalCard extends StatefulWidget {
  const DockingArrivalCard({
    super.key,
    required this.currentPosition,
    required this.onZoomInDock,
    required this.onCompleteDelivery,
  });

  final LatLng? currentPosition;
  final VoidCallback onZoomInDock;
  final VoidCallback onCompleteDelivery;

  @override
  State<DockingArrivalCard> createState() => _DockingArrivalCardState();
}

class _DockingArrivalCardState extends State<DockingArrivalCard> {
  bool _isProcessingReceipt = false;
  String? _receiptImagePath;
  bool _dismissed = false;

  Future<void> _scanReceipt() async {
    setState(() => _isProcessingReceipt = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
      );

      if (picked != null) {
        _receiptImagePath = picked.path;
        final rawText = await OcrService.instance.extractTextFromImage(picked.path);
        
        if (mounted) {
          showStyledSnackBar(
            context: context,
            message: 'Comprovante / Canhoto capturado com sucesso!',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF34C759),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showStyledSnackBar(
          context: context,
          message: 'Erro ao abrir a câmera: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.currentPosition;
    if (pos == null) return const SizedBox.shrink();

    final tc = context.watch<TruckController>();
    if (!tc.isNavigating || tc.deliveryStops.isEmpty) return const SizedBox.shrink();

    final lastStop = tc.deliveryStops.lastWhere(
      (s) => !s.isCompleted,
      orElse: () => tc.deliveryStops.last,
    );

    final stopPos = LatLng(lastStop.lat, lastStop.lng);
    final dist = const Distance().as(LengthUnit.Meter, pos, stopPos);

    // Ativa quando a menos de 450m do destino
    final isNearDestination = dist <= 450;
    if (!isNearDestination || _dismissed) return const SizedBox.shrink();

    final distLabel = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(1)} km'
        : '${dist.toInt()} m';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E121B).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF34C759).withValues(alpha: 0.50),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34C759).withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Modo Docagem ──────────────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warehouse_rounded,
                  color: Color(0xFF34C759),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'MODO CHEGADA / DOCAGEM',
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            distLabel,
                            style: const TextStyle(
                              color: Color(0xFF34C759),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastStop.recipientName.isNotEmpty ? lastStop.recipientName : lastStop.address,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Botão fechar
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _dismissed = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Botões de Ação de Docagem ─────────────────────────────
          Row(
            children: [
              // 1. Zoom de Manobra
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onZoomInDock();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.zoom_in_map_rounded, size: 16),
                  label: const Text(
                    'Manobra',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Escanear Canhoto / NF
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessingReceipt ? null : _scanReceipt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _isProcessingReceipt
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          _receiptImagePath != null ? Icons.check_rounded : Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                  label: Text(
                    _receiptImagePath != null ? 'Canhoto OK' : 'Canhoto NF',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Concluir Entrega
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    widget.onCompleteDelivery();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text(
                    'Concluir',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
