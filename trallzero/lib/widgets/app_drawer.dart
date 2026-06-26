import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../controllers/truck_controller.dart';
import '../widgets/recent_destinations.dart';
import '../features/route/models/delivery_stop.dart';


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




    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgDeep,
          border: Border(
            right: BorderSide(
              color: AppColors.amber,
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
                        color: AppColors.amberSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.amberBorder,
                        ),
                      ),
                      child: const Text(
                        'TRALL',
                        style: TextStyle(
                          color: AppColors.amber,
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
                    Navigator.pushNamed(context, '/profile');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.bgGradientTop, AppColors.bgAmber],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.amberBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: 0.06),
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
                                        AppColors.amber,
                                        AppColors.attention,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.amber.withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.bgAmber,
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
                                                ? AppColors.amber
                                                : Colors.white38,
                                          ),
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.amber,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.bgAmber,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '1',
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
                                          color: AppColors.amberMuted,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: AppColors.amberBorder,
                                          ),
                                        ),
                                        child: const Text(
                                          '⭐ Motorista',
                                          style: TextStyle(
                                            color: AppColors.amber,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '0 / 100 XP',
                                        style: TextStyle(
                                          color: Colors.white38,
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
                        // Linha de XP / Em breve
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sistema de progresso em breve',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.amberSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.amberBorder,
                                ),
                              ),
                              child: const Text(
                                'EM BREVE',
                                style: TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
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
                                color: AppColors.amber,
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
                  color: AppColors.blue,
                  onTap: () async {
                    Navigator.pop(context);
                    final result =
                        await Navigator.pushNamed<List<DeliveryStop>>(
                      context,
                      '/route_manager',
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
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              _DrawerNavItem(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
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
