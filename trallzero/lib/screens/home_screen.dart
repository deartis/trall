import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'map_screen.dart';
import '../controllers/truck_controller.dart';
import '../models/marker_model.dart';
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
//  Barra de atalhos rápidos — Chips POI especializados para motoristas
//  Posicionada abaixo da barra de busca integrada do MapScreen
// ─────────────────────────────────────────────────────────────
class _QuickAccessBar extends StatelessWidget {
  const _QuickAccessBar({required this.onAddressTap});

  final Future<void> Function(String address) onAddressTap;

  Future<void> _fetchPOI(
    BuildContext context,
    TruckController tc,
    MarkerType type,
  ) async {
    try {
      if (await LocationService.handlePermission()) {
        final pos = await LocationService.getCurrentPosition();
        await tc.findNearbyPOIsByType(LatLng(pos.latitude, pos.longitude), type);
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
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).padding.top + 74.0;
    final tc = context.watch<TruckController>();
    final loading = tc.isLoadingPOIs;

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── ⛽ Postos ─────────────────────────────────────────────
            _PoiChip(
              emoji: '⛽',
              label: 'Postos',
              color: const Color(0xFFF59E0B),
              isLoading: loading,
              onTap: loading ? null : () => _fetchPOI(context, tc, MarkerType.gasStation),
            ),
            const SizedBox(width: 8),

            // ── ⚖️ Balanças ───────────────────────────────────────────
            _PoiChip(
              emoji: '⚖️',
              label: 'Balanças',
              color: const Color(0xFFFF9500),
              isLoading: loading,
              onTap: loading ? null : () => _fetchPOI(context, tc, MarkerType.weighStation),
            ),
            const SizedBox(width: 8),

            // ── 🅿️ Pátios ────────────────────────────────────────────
            _PoiChip(
              emoji: '🅿️',
              label: 'Pátios',
              color: const Color(0xFFAF52DE),
              isLoading: loading,
              onTap: loading ? null : () => _fetchPOI(context, tc, MarkerType.parking),
            ),
            const SizedBox(width: 8),

            // ── 🔧 Oficinas ───────────────────────────────────────────
            _PoiChip(
              emoji: '🔧',
              label: 'Oficinas',
              color: const Color(0xFF6B7280),
              isLoading: loading,
              onTap: loading ? null : () => _fetchPOI(context, tc, MarkerType.mechanic),
            ),
            const SizedBox(width: 8),

            // ── Limpar POIs (quando há resultados) ───────────────────
            if (tc.automaticPOIs.isNotEmpty) ...[
              _PoiChip(
                emoji: '✕',
                label: 'Limpar',
                color: Colors.white.withValues(alpha: 0.45),
                isLoading: false,
                onTap: tc.clearAutomaticPOIs,
              ),
              const SizedBox(width: 8),
            ],

            // ── Destinos Recentes ─────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────
//  Chip POI especializado — design premium com emoji + label
// ─────────────────────────────────────────────────────────────
class _PoiChip extends StatelessWidget {
  const _PoiChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: isLoading
                ? color.withValues(alpha: 0.06)
                : const Color(0xFF111318).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.30),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isLoading
                      ? color.withValues(alpha: 0.60)
                      : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
