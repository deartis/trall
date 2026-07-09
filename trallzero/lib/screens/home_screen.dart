import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'map_screen.dart';
import '../controllers/truck_controller.dart';
import '../services/location_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/recent_destinations.dart';
import '../models/delivery_stop.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  void _onTabTapped(int index) {
    if (index == _tabIndex) return;

    // Tab "Paradas" abre o RouteManagerScreen como modal/push
    if (index == 1) {
      _openRouteManager();
      return;
    }

    // Tab "Perfil" navega para ProfileScreen
    if (index == 2) {
      Navigator.pushNamed(context, '/profile');
      return;
    }

    // Tab "Mapa" — volta para a tela principal
    setState(() => _tabIndex = 0);
  }

  Future<void> _openRouteManager() async {
    final truckCtrl = context.read<TruckController>();
    final resultObj = await Navigator.pushNamed(
      context,
      '/route_manager',
    );

    if (resultObj is List<DeliveryStop> && mounted) {
      final result = resultObj;
      LatLng startLoc = const LatLng(-22.9068, -43.1729);
      try {
        if (await LocationService.handlePermission()) {
          final pos = await LocationService.getCurrentPosition();
          startLoc = LatLng(pos.latitude, pos.longitude);
        }
      } catch (_) {}

      if (mounted) {
        truckCtrl.setDeliveryStops(result, startLoc);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    final isNavigating = tc.isNavigating;

    return Scaffold(
      // Drawer mantido para configurações e itens secundários
      drawer: const AppDrawer(),
      body: Builder(
        builder: (ctx) => Stack(
          children: [
            // ── Mapa (tela cheia, sempre presente) ─────────────────
            const MapScreen(),

            // ── Atalhos rápidos (recentes) ──────────────────────────
            // Aparecem abaixo da barra de busca quando sem rota ativa
            if (!isNavigating && !tc.isRouting && tc.suggestions.isEmpty)
              _QuickAccessBar(
                onAddressTap: (address) async {
                  Navigator.of(ctx); // mantém contexto
                  final truckCtrl = context.read<TruckController>();
                  LatLng startLoc = const LatLng(-22.9068, -43.1729);
                  try {
                    if (await LocationService.handlePermission()) {
                      final pos = await LocationService.getCurrentPosition();
                      startLoc = LatLng(pos.latitude, pos.longitude);
                    }
                  } catch (_) {}
                  await truckCtrl.searchAddress(address, startLoc);
                },
              ),

            // ── Botão Hamburguer (☰) — mantido para drawer ─────────
            _HamburgerButton(
              onTap: () => Scaffold.of(ctx).openDrawer(),
            ),
          ],
        ),
      ),
      // ── Bottom Navigation Bar ────────────────────────────────────
      bottomNavigationBar: TrallBottomNav(
        currentIndex: _tabIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Barra de atalhos rápidos (destinos recentes)
//  Posicionada abaixo da barra de busca do MapScreen
// ─────────────────────────────────────────────────────────────
class _QuickAccessBar extends StatelessWidget {
  const _QuickAccessBar({required this.onAddressTap});

  final Future<void> Function(String address) onAddressTap;

  @override
  Widget build(BuildContext context) {
    // Fica abaixo da search bar: top + 12 (safe area) + ~54px (search field height) + 8px gap
    final topOffset = MediaQuery.of(context).padding.top + 74.0;

    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: _RecentDestinationsCard(onAddressTap: onAddressTap),
    );
  }
}

class _RecentDestinationsCard extends StatelessWidget {
  const _RecentDestinationsCard({required this.onAddressTap});
  final Future<void> Function(String) onAddressTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label seção ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'RECENTES',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        // ── Lista horizontal de chips de destinos recentes ──────────
        SizedBox(
          height: 40,
          child: RecentDestinations(
            onTap: onAddressTap,
            horizontal: true,
          ),
        ),
      ],
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
    final tc = context.watch<TruckController>();
    final isNavigating = tc.isNavigating;
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
