import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../screens/map_screen.dart';
import '../../../controllers/truck_controller.dart';
import '../../../services/location_service.dart';
import '../../../models/truck_profile.dart';
import '../../../services/truck_profile_service.dart';
import '../../../widgets/recent_destinations.dart';
import '../../route/models/delivery_stop.dart';
import '../../route/screens/route_manager_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();

    // Dashboard aparece apenas quando não há rota ativa (sem pontos na rota)
    // Quando há rota, o NavigationPanel dentro do MapScreen assume o controle
    final bool showDashboard = tc.routePoints.isEmpty && !tc.isNavigating;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa de fundo (tela cheia)
          const MapScreen(),

          // Dashboard pré-viagem — só quando não há rota calculada
          // DraggableScrollableSheet deve ser filho direto do Stack (sem Positioned)
          if (showDashboard)
            _DashboardSheet(tc: tc),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dashboard pré-viagem como DraggableScrollableSheet
// ─────────────────────────────────────────────────────────────
class _DashboardSheet extends StatefulWidget {
  const _DashboardSheet({required this.tc});
  final TruckController tc;

  @override
  State<_DashboardSheet> createState() => _DashboardSheetState();
}

class _DashboardSheetState extends State<_DashboardSheet> {

  Future<void> _searchAndGo(String address) async {
    if (address.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    LatLng startLoc = const LatLng(-22.9068, -43.1729);
    final truckCtrl = context.read<TruckController>();
    try {
      if (await LocationService.handlePermission()) {
        final pos = await LocationService.getCurrentPosition();
        startLoc = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    if (mounted) {
      await truckCtrl.searchAddress(address, startLoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final profile = TruckProfileService.instance.currentProfile;

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.12,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.12, 0.38, 0.75],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0E1017),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFE07B1A).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Card de perfil do caminhão ────────────────────────
              _ProfileCard(profile: profile),
              const SizedBox(height: 16),

              // ── Botão de paradas da rota ──────────────────────────
              _StopsButton(
                hasActiveRoute: tc.deliveryStops.isNotEmpty,
                onPressed: () async {
                  final result = await Navigator.push<List<DeliveryStop>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RouteManagerScreen(),
                    ),
                  );

                  if (result != null && context.mounted) {
                    LatLng startLoc = const LatLng(-22.9068, -43.1729);
                    try {
                      if (await LocationService.handlePermission()) {
                        final pos = await LocationService.getCurrentPosition();
                        startLoc = LatLng(pos.latitude, pos.longitude);
                      }
                    } catch (e) {
                      debugPrint('Erro ao buscar localização inicial: $e');
                    }

                    if (context.mounted) {
                      context
                          .read<TruckController>()
                          .setDeliveryStops(result, startLoc);
                    }
                  }
                },
              ),

              // ── Destinos recentes ─────────────────────────────────
              RecentDestinations(
                onTap: (address) {
                  _searchAndGo(address);
                },
              ),

              // ── Resumo de fadiga (se tiver dados) ────────────────
              if (tc.drivingSeconds > 0) ...[
                const SizedBox(height: 12),
                _FatigueSummaryCard(tc: tc),
              ],

              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Card do perfil do caminhão
// ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final TruckProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE07B1A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE07B1A).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE07B1A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Color(0xFFE07B1A),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${profile.maxWeightKg.toInt()} kg  ·  ${profile.maxHeightMeters} m  ·  ${profile.axles} eixos',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showProfileSheet(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE07B1A),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Trocar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final tc = context.read<TruckController>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecionar perfil de caminhão',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            ...TruckProfilePresets.all.map((p) {
              final selected = p.type == tc.truckProfile.type;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.local_shipping_rounded,
                  color: selected
                      ? const Color(0xFF34C759)
                      : Colors.white70,
                ),
                title: Text(
                  p.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${p.maxWeightKg.toInt()} kg · ${p.maxHeightMeters} m · ${p.axles} eixos',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
                onTap: () {
                  tc.setTruckProfile(p);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────
//  Card de resumo de fadiga
// ─────────────────────────────────────────────────────────────
class _FatigueSummaryCard extends StatelessWidget {
  const _FatigueSummaryCard({required this.tc});
  final TruckController tc;

  String get _timeUntilBreak {
    const limit = 5 * 3600 + 30 * 60;
    final remaining = limit - tc.drivingSeconds;
    if (remaining <= 0) return 'Descanse agora!';
    final h = (remaining / 3600).floor();
    final m = ((remaining % 3600) / 60).floor();
    if (h > 0) return 'Próxima pausa em ${h}h ${m}min';
    return 'Próxima pausa em ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final sev = tc.fatigueSeverity;
    final color = sev == FatigueSeverity.critical
        ? const Color(0xFFFF3B30)
        : sev == FatigueSeverity.danger
            ? const Color(0xFFFF6B00)
            : sev == FatigueSeverity.warning
                ? const Color(0xFFFF9500)
                : const Color(0xFF34C759);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tempo de direção: ${tc.formattedDrivingTime}',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _timeUntilBreak,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Botão de paradas da rota
// ─────────────────────────────────────────────────────────────
class _StopsButton extends StatelessWidget {
  const _StopsButton({required this.onPressed, this.hasActiveRoute = false});

  final VoidCallback onPressed;
  final bool hasActiveRoute;

  @override
  Widget build(BuildContext context) {
    final color1 = hasActiveRoute
        ? const Color(0xFF1E40AF)
        : const Color(0xFF1A2535);
    final color2 = hasActiveRoute
        ? const Color(0xFF2563EB)
        : const Color(0xFF1E2D45);
    final icon = hasActiveRoute
        ? Icons.list_alt_rounded
        : Icons.add_road_rounded;
    final label =
        hasActiveRoute ? 'Ver / Reorganizar Paradas' : 'Criar Rota com Paradas';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
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
