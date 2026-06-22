import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../controllers/truck_controller.dart';
import '../screens/profile_screen.dart';
import '../widgets/recent_destinations.dart';
import '../features/route/models/delivery_stop.dart';
import '../features/route/screens/route_manager_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _searchAndGo(BuildContext context, String address) async {
    Navigator.pop(context); // Fecha o drawer
    if (address.trim().isEmpty) return;

    LatLng startLoc = const LatLng(-22.9068, -43.1729);
    final truckCtrl = context.read<TruckController>();
    try {
      if (await LocationService.handlePermission()) {
        final pos = await LocationService.getCurrentPosition();
        startLoc = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    await truckCtrl.searchAddress(address, startLoc);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tc = context.watch<TruckController>();
    final isSignedIn = auth.isSignedIn;
    final user = auth.currentUser;
    final currentProfile = tc.truckProfile;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // Gamificação — placeholder
    const int level = 1;
    const int xp = 0;
    const double xpProgress = 0.0;
    const String levelLabel = 'Novato';
    const String xpLabel = '$xp / 100 XP';


    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B0E17),
          border: Border(
            right: BorderSide(
              color: Color(0xFFE07B1A),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header com logo ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    // Logo/Marca
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07B1A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE07B1A).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'TRALL',
                        style: TextStyle(
                          color: Color(0xFFE07B1A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Card de Gamificação ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2035), Color(0xFF0E1320)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE07B1A).withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE07B1A).withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Avatar com borda
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE07B1A),
                                        Color(0xFFFF9500)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE07B1A)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF0E1320),
                                    backgroundImage: (isSignedIn &&
                                            user?.photoUrl != null)
                                        ? NetworkImage(user!.photoUrl!)
                                        : null,
                                    child: (isSignedIn &&
                                            user?.photoUrl != null)
                                        ? null
                                        : Icon(
                                            isSignedIn
                                                ? Icons.person_rounded
                                                : Icons
                                                    .person_outline_rounded,
                                            size: 24,
                                            color: isSignedIn
                                                ? const Color(0xFFE07B1A)
                                                : Colors.white38,
                                          ),
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE07B1A),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF0E1320),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '$level',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSignedIn
                                        ? (user?.displayName ?? 'Motorista')
                                        : 'Motorista',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE07B1A)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFE07B1A)
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          '⭐ $levelLabel',
                                          style: TextStyle(
                                            color: Color(0xFFE07B1A),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        xpLabel,
                                        style: TextStyle(
                                          color:
                                              Colors.white.withValues(alpha: 0.35),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.2),
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Barra de XP
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: xpProgress,
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.07),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE07B1A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Info veículo
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_shipping_rounded,
                                color: Color(0xFFE07B1A),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Veículo: ${currentProfile.label}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Botão Criar Rota ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DrawerActionButton(
                  icon: tc.deliveryStops.isNotEmpty
                      ? Icons.list_alt_rounded
                      : Icons.add_road_rounded,
                  label: tc.deliveryStops.isNotEmpty
                      ? 'Ver / Reorganizar Paradas'
                      : 'Criar Rota com Paradas',
                  color: const Color(0xFF2563EB),
                  onTap: () async {
                    Navigator.pop(context);
                    final result =
                        await Navigator.push<List<DeliveryStop>>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RouteManagerScreen()),
                    );

                    if (result != null && context.mounted) {
                      LatLng startLoc = const LatLng(-22.9068, -43.1729);
                      try {
                        if (await LocationService.handlePermission()) {
                          final pos =
                              await LocationService.getCurrentPosition();
                          startLoc = LatLng(pos.latitude, pos.longitude);
                        }
                      } catch (_) {}
                      if (context.mounted) {
                        context
                            .read<TruckController>()
                            .setDeliveryStops(result, startLoc);
                      }
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Destinos Recentes ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'DESTINOS RECENTES',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RecentDestinations(
                    onTap: (address) =>
                        _searchAndGo(context, address),
                  ),
                ),
              ),

              // ── Divisor + links de rodapé ────────────────────────────
              Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              _DrawerNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Meu Perfil',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              _DrawerNavItem(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () => Navigator.pop(context),
              ),
              SizedBox(height: safeBottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Botão de ação do Drawer
// ─────────────────────────────────────────────────────────────
class _DrawerActionButton extends StatelessWidget {
  const _DrawerActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.15),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
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

// ─────────────────────────────────────────────────────────────
//  Item de navegação do rodapé do Drawer
// ─────────────────────────────────────────────────────────────
class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      minVerticalPadding: 0,
      leading: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.45),
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.65),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
