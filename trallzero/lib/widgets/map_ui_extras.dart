import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  Indicador de sinal GPS — bolinha colorida discreta
//  Posicionada no sufixo da barra de busca
// ─────────────────────────────────────────────────────────────
class GpsSignalDot extends StatelessWidget {
  const GpsSignalDot({super.key, required this.accuracy});
  final double accuracy; // metros

  Color get _color {
    if (accuracy <= 10) return const Color(0xFF4CAF50);  // 🟢 ótimo
    if (accuracy <= 25) return const Color(0xFFFFB300);  // 🟡 bom
    if (accuracy <= 50) return const Color(0xFFFF7043);  // 🟠 fraco
    return const Color(0xFFEF5350);                       // 🔴 sem sinal
  }

  String get _tooltip {
    if (accuracy <= 10) return 'GPS ótimo (±${accuracy.toStringAsFixed(0)}m)';
    if (accuracy <= 25) return 'GPS bom (±${accuracy.toStringAsFixed(0)}m)';
    if (accuracy <= 50) return 'GPS fraco (±${accuracy.toStringAsFixed(0)}m)';
    return 'GPS sem sinal';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          boxShadow: [
            BoxShadow(
              color: _color.withValues(alpha: 0.60),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Banner animado — confirmação de início de navegação
//  Aparece no centro da tela por ~2.5s ao apertar GO
// ─────────────────────────────────────────────────────────────
class NavStartBanner extends StatefulWidget {
  const NavStartBanner({super.key});

  @override
  State<NavStartBanner> createState() => _NavStartBannerState();
}

class _NavStartBannerState extends State<NavStartBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2A1F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.40),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.20),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.navigation_rounded,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Navegação iniciada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
