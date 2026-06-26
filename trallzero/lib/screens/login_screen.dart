import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_snackbar.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / ícone
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE07B1A), Color(0xFFFF9A3C)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE07B1A).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Trall',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sua rota, seu caminho.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 56),

                  // Botão Google Sign-In
                  _GoogleSignInButton(
                    isLoading: auth.isLoading,
                    onPressed: () async {
                      final success =
                          await auth.signInWithGoogle();
                      if (success && context.mounted) {
                        Navigator.pop(context);
                      } else if (!success && context.mounted) {
                        showStyledSnackBar(
                          context: context,
                          message: 'Login cancelado ou falhou.',
                          isError: true,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // Continuar sem conta
                  TextButton(
                    onPressed: auth.isLoading
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Continuar sem conta',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: Colors.black38,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFFE07B1A)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo G do Google em SVG/Paint simples
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Entrar com Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width * 0.17; // espessura do traço
    final rect = Rect.fromLTWH(
      sw / 2, sw / 2,
      size.width - sw,
      size.height - sw,
    );
    final r = (size.width - sw) / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Arco vermelho (topo → direita, ~330° a 90°) ──
    _arc(canvas, rect, sw, const Color(0xFFEA4335), -0.35, 1.25);
    // ── Arco amarelo (direita → baixo-direita, ~90° a 180°) ──
    _arc(canvas, rect, sw, const Color(0xFFFBBC05), 0.9, 0.55);
    // ── Arco verde (baixo-direita → esquerda, ~180° a 270°) ──
    _arc(canvas, rect, sw, const Color(0xFF34A853), 1.45, 0.65);
    // ── Arco azul (esquerda → topo, ~270° a ~330°) ──
    _arc(canvas, rect, sw, const Color(0xFF4285F4), 2.1, 1.45);

    // ── Barra horizontal + vertical direita (azul) ──
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Linha horizontal: do centro até a borda direita
    canvas.drawLine(
      Offset(cx, cy),
      Offset(size.width - sw / 2, cy),
      barPaint,
    );
    // Linha vertical: do centro para baixo (metade do raio)
    canvas.drawLine(
      Offset(size.width - sw / 2, cy),
      Offset(size.width - sw / 2, cy + r * 0.55),
      barPaint,
    );
  }

  void _arc(Canvas canvas, Rect rect, double sw, Color color,
      double startAngle, double sweepAngle) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      rect,
      startAngle * 3.14159,
      sweepAngle * 3.14159,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
