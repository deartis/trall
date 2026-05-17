import 'package:flutter/material.dart';

class NavigationMarker extends StatelessWidget {
  final double size;
  final Color color;

  const NavigationMarker({
    super.key,
    this.size = 40,
    this.color = Colors.blueAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
    path.lineTo(size.width / 2, size.height * 0.7); // Recuo central (o que dá o visual moderno)
    path.lineTo(0, size.height); // Canto inferior esquerdo
    path.close();

    // Adiciona uma linha de detalhe interna para dar profundidade
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
