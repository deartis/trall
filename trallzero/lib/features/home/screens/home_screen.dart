import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../screens/map_screen.dart';
import '../../../controllers/truck_controller.dart';
import '../../../widgets/app_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O drawer abre com swipe da esquerda ou pelo botão ☰
      drawer: const AppDrawer(),
      // O mapa ocupa toda a tela — sem bottom sheet, sem Positioned extras
      body: Builder(
        builder: (ctx) => Stack(
          children: [
            // ── Mapa (tela cheia) ───────────────────────────────────────
            const MapScreen(),

            // ── Botão Hamburguer (☰) ────────────────────────────────────
            _HamburgerButton(
              onTap: () => Scaffold.of(ctx).openDrawer(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Botão Hamburguer flutuante
// ─────────────────────────────────────────────────────────────
class _HamburgerButton extends StatelessWidget {
  const _HamburgerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Esconde durante navegação ativa (para não distrair o motorista)
    final tc = context.watch<TruckController>();
    final isNavigating = tc.isNavigating;
    // A barra de busca fica em padding.top + 12.
    // Com ~54px de altura do field + 8px de gap = padding.top + 74.
    final topPos = MediaQuery.of(context).padding.top + 74.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      top: isNavigating ? -80 : topPos,
      left: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isNavigating ? 0.0 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D26).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

