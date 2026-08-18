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
import '../core/app_snackbar.dart';

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

            // ── Atalhos rápidos (Locais Próximos + Recentes) ─────────
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
//  Barra de atalhos rápidos (Locais Próximos + Destinos Recentes)
//  Posicionada abaixo da barra de busca integrada do MapScreen
// ─────────────────────────────────────────────────────────────
class _QuickAccessBar extends StatelessWidget {
  const _QuickAccessBar({required this.onAddressTap});

  final Future<void> Function(String address) onAddressTap;

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).padding.top + 74.0;
    final tc = context.watch<TruckController>();

    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Chip: Locais Próximos ─────────────────────────────────
            _ActionChip(
              icon: tc.isLoadingPOIs
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.place_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
              label: tc.isLoadingPOIs ? 'Buscando...' : 'Locais Próximos',
              isPrimary: true,
              onTap: tc.isLoadingPOIs
                  ? null
                  : () async {
                      try {
                        if (await LocationService.handlePermission()) {
                          final pos = await LocationService.getCurrentPosition();
                          tc.findNearbyPOIs(LatLng(pos.latitude, pos.longitude));
                        } else {
                          if (!context.mounted) return;
                          showStyledSnackBar(
                            context: context,
                            message: 'Permissão de GPS necessária.',
                            icon: Icons.gps_off_rounded,
                          );
                        }
                      } catch (_) {
                        if (!context.mounted) return;
                        showStyledSnackBar(
                          context: context,
                          message: 'Aguardando sinal de GPS...',
                          icon: Icons.gps_off_rounded,
                        );
                      }
                    },
            ),
            const SizedBox(width: 8),

            // ── Chip: Limpar POIs (exibido apenas quando houver POIs) ─
            if (tc.automaticPOIs.isNotEmpty) ...[
              _ActionChip(
                icon: const Icon(
                  Icons.clear_all_rounded,
                  color: Colors.white70,
                  size: 15,
                ),
                label: 'Limpar POIs',
                isPrimary: false,
                onTap: tc.clearAutomaticPOIs,
              ),
              const SizedBox(width: 8),
            ],

            // ── Chips de Destinos Recentes ────────────────────────────
            RecentDestinations(
              onTap: onAddressTap,
              horizontal: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFFE07B1A)
                : const Color(0xFF111318).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFFFF9D3B)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? const Color(0xFFE07B1A).withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
