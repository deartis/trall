import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/truck_profile.dart';

class NavigationMarker extends StatefulWidget {
  final double size;
  final double speed; // em m/s
  final TruckProfileType profileType;

  const NavigationMarker({
    super.key,
    this.size = 40,
    this.speed = 0.0,
    this.profileType = TruckProfileType.truck,
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

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
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
    if (kmh < 1.0) return const Duration(milliseconds: 3000); // parado (lento)
    if (kmh <= 60.0) return const Duration(milliseconds: 1800); // normal
    if (kmh <= 90.0) return const Duration(milliseconds: 1200); // rápido
    return const Duration(milliseconds: 800); // muito rápido/perigo
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
          // Anel pulsante externo
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  width: size * 0.55,
                  height: size * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Efeito de brilho/aura ao fundo
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // O Veículo Estilizado (Custom Painter)
          CustomPaint(
            size: Size(size * 0.6, size * 0.8),
            painter: _VehiclePainter(
              color: color,
              profileType: widget.profileType,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePainter extends CustomPainter {
  final Color color;
  final TruckProfileType profileType;

  _VehiclePainter({required this.color, required this.profileType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Linha de detalhe interna/borda para profundidade
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final detailPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double w = size.width;
    final double h = size.height;

    switch (profileType) {
      case TruckProfileType.lightTruck:
        _drawLightTruck(canvas, w, h, paint, borderPaint, detailPaint);
        break;
      case TruckProfileType.truck:
        _drawRigidTruck(canvas, w, h, paint, borderPaint, detailPaint);
        break;
      case TruckProfileType.carreta:
        _drawCarreta(canvas, w, h, paint, borderPaint, detailPaint);
        break;
      case TruckProfileType.bitrem:
        _drawBitrem(canvas, w, h, paint, borderPaint, detailPaint);
        break;
      case TruckProfileType.rodotrem:
        _drawRodotrem(canvas, w, h, paint, borderPaint, detailPaint);
        break;
    }
  }

  void _drawLightTruck(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    final path = Path();
    path.moveTo(w / 2, 0); // Ponta superior
    path.lineTo(w * 0.8, h * 0.3); // Canto direito cabine
    path.lineTo(w * 0.7, h * 0.3);
    path.lineTo(w * 0.7, h * 0.85); // Traseira direita
    path.lineTo(w * 0.3, h * 0.85); // Traseira esquerda
    path.lineTo(w * 0.3, h * 0.3);
    path.lineTo(w * 0.2, h * 0.3);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Divisor cabine/caçamba
    canvas.drawLine(Offset(w * 0.3, h * 0.36), Offset(w * 0.7, h * 0.36), detailPaint);
  }

  void _drawRigidTruck(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    final path = Path();
    path.moveTo(w / 2, 0);
    path.lineTo(w * 0.85, h * 0.25);
    path.lineTo(w * 0.75, h * 0.25);
    path.lineTo(w * 0.75, h * 0.92);
    path.lineTo(w * 0.25, h * 0.92);
    path.lineTo(w * 0.25, h * 0.25);
    path.lineTo(w * 0.15, h * 0.25);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Divisor cabine/baú
    canvas.drawLine(Offset(w * 0.25, h * 0.32), Offset(w * 0.75, h * 0.32), detailPaint);
  }

  void _drawCarreta(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    // Cabine (Cavalo Mecânico)
    final cabPath = Path();
    cabPath.moveTo(w / 2, 0);
    cabPath.lineTo(w * 0.85, h * 0.22);
    cabPath.lineTo(w * 0.7, h * 0.22);
    cabPath.lineTo(w * 0.7, h * 0.28);
    cabPath.lineTo(w * 0.3, h * 0.28);
    cabPath.lineTo(w * 0.3, h * 0.22);
    cabPath.lineTo(w * 0.15, h * 0.22);
    cabPath.close();

    canvas.drawPath(cabPath, paint);
    canvas.drawPath(cabPath, borderPaint);

    // Pino de engate (quinta roda)
    final pinPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(w / 2, h * 0.28), Offset(w / 2, h * 0.38), pinPaint);

    // Semirreboque longo
    final RRect trailer = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.20, h * 0.38, w * 0.80, h * 0.95),
      const Radius.circular(3),
    );
    canvas.drawRRect(trailer, paint);
    canvas.drawRRect(trailer, borderPaint);
  }

  void _drawBitrem(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    // Cabine
    final cabPath = Path();
    cabPath.moveTo(w / 2, 0);
    cabPath.lineTo(w * 0.8, h * 0.18);
    cabPath.lineTo(w * 0.7, h * 0.18);
    cabPath.lineTo(w * 0.7, h * 0.23);
    cabPath.lineTo(w * 0.3, h * 0.23);
    cabPath.lineTo(w * 0.3, h * 0.18);
    cabPath.lineTo(w * 0.2, h * 0.18);
    cabPath.close();
    canvas.drawPath(cabPath, paint);
    canvas.drawPath(cabPath, borderPaint);

    // Pino 1
    final pinPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawLine(Offset(w / 2, h * 0.23), Offset(w / 2, h * 0.30), pinPaint);

    // Semirreboque 1
    final RRect trailer1 = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.22, h * 0.30, w * 0.78, h * 0.58),
      const Radius.circular(2),
    );
    canvas.drawRRect(trailer1, paint);
    canvas.drawRRect(trailer1, borderPaint);

    // Pino 2
    canvas.drawLine(Offset(w / 2, h * 0.58), Offset(w / 2, h * 0.65), pinPaint);

    // Semirreboque 2
    final RRect trailer2 = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.22, h * 0.65, w * 0.78, h * 0.95),
      const Radius.circular(2),
    );
    canvas.drawRRect(trailer2, paint);
    canvas.drawRRect(trailer2, borderPaint);
  }

  void _drawRodotrem(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    // Cabine
    final cabPath = Path();
    cabPath.moveTo(w / 2, 0);
    cabPath.lineTo(w * 0.8, h * 0.15);
    cabPath.lineTo(w * 0.7, h * 0.15);
    cabPath.lineTo(w * 0.7, h * 0.19);
    cabPath.lineTo(w * 0.3, h * 0.19);
    cabPath.lineTo(w * 0.3, h * 0.15);
    cabPath.lineTo(w * 0.2, h * 0.15);
    cabPath.close();
    canvas.drawPath(cabPath, paint);
    canvas.drawPath(cabPath, borderPaint);

    final pinPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Pino 1
    canvas.drawLine(Offset(w / 2, h * 0.19), Offset(w / 2, h * 0.24), pinPaint);

    // Reboque 1
    final RRect trailer1 = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.24, h * 0.24, w * 0.76, h * 0.45),
      const Radius.circular(2),
    );
    canvas.drawRRect(trailer1, paint);
    canvas.drawRRect(trailer1, borderPaint);

    // Pino 2
    canvas.drawLine(Offset(w / 2, h * 0.45), Offset(w / 2, h * 0.49), pinPaint);

    // Reboque 2
    final RRect trailer2 = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.24, h * 0.49, w * 0.76, h * 0.70),
      const Radius.circular(2),
    );
    canvas.drawRRect(trailer2, paint);
    canvas.drawRRect(trailer2, borderPaint);

    // Pino 3
    canvas.drawLine(Offset(w / 2, h * 0.70), Offset(w / 2, h * 0.74), pinPaint);

    // Reboque 3
    final RRect trailer3 = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.24, h * 0.74, w * 0.76, h * 0.95),
      const Radius.circular(2),
    );
    canvas.drawRRect(trailer3, paint);
    canvas.drawRRect(trailer3, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.profileType != profileType;
  }
}
