import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/truck_profile.dart';

class NavigationMarker extends StatefulWidget {
  final double size;
  final double speed; // em m/s
  final TruckProfileType profileType;
  final double heading; // em graus

  const NavigationMarker({
    super.key,
    this.size = 40,
    this.speed = 0.0,
    this.profileType = TruckProfileType.truck,
    this.heading = 0.0,
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
    final headingRad = widget.heading * math.pi / 180.0;

    return SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
        angle: headingRad,
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
              size: Size(size * 0.65, size * 0.85),
              painter: _VehiclePainter(
                color: color,
                profileType: widget.profileType,
              ),
            ),
          ],
        ),
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
      ..strokeWidth = 1.5;

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

  void _drawCab(Canvas canvas, double x, double y, double w, double h, Paint paint, Paint borderPaint) {
    // A rounded rectangle representing the cabin
    final RRect cabRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(w * 0.25),
    );
    canvas.drawRRect(cabRRect, paint);
    canvas.drawRRect(cabRRect, borderPaint);

    // Windshield (Para-brisa)
    final glassPaint = Paint()
      ..color = const Color(0xFF8CE3FF)
      ..style = PaintingStyle.fill;
    final glassBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    
    // Windshield at the top/front of the cab
    final RRect glassRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + w * 0.15, y + h * 0.12, w * 0.7, h * 0.22),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(glassRRect, glassPaint);
    canvas.drawRRect(glassRRect, glassBorder);

    // Side mirrors (Retrovisores)
    final mirrorPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    
    // Left mirror
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w * 0.12, y + h * 0.25, w * 0.1, h * 0.22),
        const Radius.circular(1),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w * 0.12, y + h * 0.25, w * 0.1, h * 0.22),
        const Radius.circular(1),
      ),
      borderPaint,
    );

    // Right mirror
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + w * 1.02, y + h * 0.25, w * 0.1, h * 0.22),
        const Radius.circular(1),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + w * 1.02, y + h * 0.25, w * 0.1, h * 0.22),
        const Radius.circular(1),
      ),
      borderPaint,
    );
  }

  void _drawTrailer(Canvas canvas, double x, double y, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    final RRect trailerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(trailerRRect, paint);
    canvas.drawRRect(trailerRRect, borderPaint);

    // Corrugated container ridges (linhas horizontais de detalhe em vista superior)
    final double step = h / 5;
    for (double i = y + step; i < y + h - 1; i += step) {
      canvas.drawLine(Offset(x + 2, i), Offset(x + w - 2, i), detailPaint);
    }
  }

  void _drawLightTruck(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    _drawCab(canvas, w * 0.18, 0, w * 0.64, h * 0.38, paint, borderPaint);
    _drawTrailer(canvas, w * 0.18, h * 0.42, w * 0.64, h * 0.55, paint, borderPaint, detailPaint);
  }

  void _drawRigidTruck(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    _drawCab(canvas, w * 0.16, 0, w * 0.68, h * 0.34, paint, borderPaint);
    _drawTrailer(canvas, w * 0.16, h * 0.38, w * 0.68, h * 0.58, paint, borderPaint, detailPaint);
  }

  void _drawCarreta(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    // Cavalo mecânico
    _drawCab(canvas, w * 0.2, 0, w * 0.6, h * 0.28, paint, borderPaint);

    // Pino de engate (chassis)
    final chassisPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(w / 2, h * 0.28), Offset(w / 2, h * 0.38), chassisPaint);

    // Semirreboque
    _drawTrailer(canvas, w * 0.16, h * 0.38, w * 0.68, h * 0.58, paint, borderPaint, detailPaint);
  }

  void _drawBitrem(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    // Cavalo mecânico
    _drawCab(canvas, w * 0.22, 0, w * 0.56, h * 0.22, paint, borderPaint);

    // Pino 1 (chassis)
    final chassisPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawLine(Offset(w / 2, h * 0.22), Offset(w / 2, h * 0.28), chassisPaint);

    // Reboque 1
    _drawTrailer(canvas, w * 0.18, h * 0.28, w * 0.64, h * 0.31, paint, borderPaint, detailPaint);

    // Pino 2
    canvas.drawLine(Offset(w / 2, h * 0.59), Offset(w / 2, h * 0.64), chassisPaint);

    // Reboque 2
    _drawTrailer(canvas, w * 0.18, h * 0.64, w * 0.64, h * 0.32, paint, borderPaint, detailPaint);
  }

  void _drawRodotrem(Canvas canvas, double w, double h, Paint paint, Paint borderPaint, Paint detailPaint) {
    // Cavalo mecânico
    _drawCab(canvas, w * 0.24, 0, w * 0.52, h * 0.18, paint, borderPaint);

    // Pino 1 (chassis)
    final chassisPaint = Paint()
      ..color = borderPaint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w / 2, h * 0.18), Offset(w / 2, h * 0.23), chassisPaint);

    // Reboque 1
    _drawTrailer(canvas, w * 0.20, h * 0.23, w * 0.60, h * 0.22, paint, borderPaint, detailPaint);

    // Pino 2
    canvas.drawLine(Offset(w / 2, h * 0.45), Offset(w / 2, h * 0.49), chassisPaint);

    // Reboque 2
    _drawTrailer(canvas, w * 0.20, h * 0.49, w * 0.60, h * 0.22, paint, borderPaint, detailPaint);

    // Pino 3
    canvas.drawLine(Offset(w / 2, h * 0.71), Offset(w / 2, h * 0.75), chassisPaint);

    // Reboque 3
    _drawTrailer(canvas, w * 0.20, h * 0.75, w * 0.60, h * 0.21, paint, borderPaint, detailPaint);
  }

  @override
  bool shouldRepaint(covariant _VehiclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.profileType != profileType;
  }
}

