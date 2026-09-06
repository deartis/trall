import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/truck_profile.dart';

/// Marcador de navegação do veículo no mapa.
///
/// Exibe uma seta elegante que se orienta automaticamente com a direção
/// do veículo/aparelho, sincronizada tanto no modo de rotação do mapa
/// quanto no modo livre (North-up).
///
/// O anel pulsante muda de velocidade e cor conforme a speed:
///   • parado  → âmbar, pulso lento
///   • normal  → verde, pulso médio
///   • rápido  → laranja, pulso rápido
///   • perigoso → vermelho, pulso muito rápido
class NavigationMarker extends StatefulWidget {
  final double size;
  final double speed; // em m/s
  final TruckProfileType profileType;
  final double heading; // em graus (0° = Norte)
  final double mapRotation; // rotação atual do mapa em graus

  const NavigationMarker({
    super.key,
    this.size = 40,
    this.speed = 0.0,
    this.profileType = TruckProfileType.truck,
    this.heading = 0.0,
    this.mapRotation = 0.0,
  });

  @override
  State<NavigationMarker> createState() => _NavigationMarkerState();
}

class _NavigationMarkerState extends State<NavigationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _getPulseDuration(widget.speed),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant NavigationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _pulseController.duration = _getPulseDuration(widget.speed);
      if (_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    }
  }

  Duration _getPulseDuration(double speed) {
    final kmh = speed * 3.6;
    if (kmh < 1.0) return const Duration(milliseconds: 3000);
    if (kmh <= 60.0) return const Duration(milliseconds: 1800);
    if (kmh <= 90.0) return const Duration(milliseconds: 1200);
    return const Duration(milliseconds: 800);
  }

  Color get _markerColor {
    final kmh = widget.speed * 3.6;
    if (kmh < 1.0) return AppColors.amber;
    if (kmh <= 60.0) return AppColors.safe;
    if (kmh <= 90.0) return AppColors.attention;
    return AppColors.danger;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = _markerColor;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Anel pulsante externo ─────────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  width: size * 0.52,
                  height: size * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ),
            ),
          ),

          // ── Aura/glow ao fundo ────────────────────────────────────
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // ── Seta de navegação ─────────────────────────────────────
          Transform.rotate(
            angle: (widget.heading + widget.mapRotation) * (math.pi / 180.0),
            child: CustomPaint(
              size: Size(size * 0.60, size * 0.72),
              painter: _ArrowPainter(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Seta de navegação estilo "teardrop/chevron"
//  A PONTA aponta sempre para CIMA (y=0). O Marker pai com rotate:true
//  e o mapa rotacionado cuidam de apontar para a direção correta.
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // ── Sombra projetada (profundidade) ───────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final arrowPath = _buildArrowPath(w, h);
    canvas.save();
    canvas.translate(1.5, 2.5);
    canvas.drawPath(arrowPath, shadowPaint);
    canvas.restore();

    // ── Fill principal (gradiente linear vertical) ─────────────────
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);

    // ── Borda branca sutil (legibilidade sobre qualquer mapa) ─────
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(arrowPath, borderPaint);

    // ── Linha central de detalhe (percepção de direção) ───────────
    final detailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w / 2, h * 0.12),
      Offset(w / 2, h * 0.62),
      detailPaint,
    );
  }

  /// Constrói o path da seta: ponta no topo, base arredondada na baixo.
  Path _buildArrowPath(double w, double h) {
    final path = Path();

    // Ponta (topo — direção de movimento)
    path.moveTo(w / 2, 0);

    // Ombro direito — curva suave para o corpo
    path.cubicTo(
      w * 0.90, h * 0.28,
      w * 1.00, h * 0.45,
      w * 0.82, h * 0.58,
    );

    // Entalhe no centro da base (cria efeito de "V" invertido)
    path.lineTo(w * 0.62, h * 0.50);

    // Arco da base (direita → esquerda)
    path.arcToPoint(
      Offset(w * 0.38, h * 0.50),
      radius: Radius.circular(h * 0.15),
      clockwise: false,
    );

    // Ombro esquerdo
    path.lineTo(w * 0.18, h * 0.58);

    path.cubicTo(
      w * 0.00, h * 0.45,
      w * 0.10, h * 0.28,
      w / 2, 0,
    );

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
