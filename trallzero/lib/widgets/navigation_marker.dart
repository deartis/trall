import 'package:flutter/material.dart';

class NavigationMarker extends StatefulWidget {
  final double size;
  final Color color;

  const NavigationMarker({
    super.key,
    this.size = 40,
    this.color = Colors.blueAccent,
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
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.color;

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

          // A Seta Estilizada (Custom Painter)
          CustomPaint(
            size: Size(size * 0.6, size * 0.8),
            painter: _ArrowPainter(color: color),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Desenha uma seta afiada e moderna (estilo ponta de lança)
    path.moveTo(size.width / 2, 0); // Ponta superior
    path.lineTo(size.width, size.height); // Canto inferior direito
    path.lineTo(size.width / 2, size.height * 0.7); // Recuo central
    path.lineTo(0, size.height); // Canto inferior esquerdo
    path.close();

    // Linha de detalhe interna para profundidade
    final detailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, detailPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
