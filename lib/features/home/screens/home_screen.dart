import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../screens/map_screen.dart';
import '../../../controllers/truck_controller.dart';
import '../../../services/location_service.dart';
import '../../route/models/delivery_stop.dart';
import '../../route/screens/route_manager_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    // Mostra o botão sempre que não há navegação ativa em andamento
    final bool showStopsButton = !tc.isNavigating;

    return Scaffold(
      body: Stack(
        children: [
          const MapScreen(),

          // Botão flutuante de paradas — visível quando não está navegando
          if (showStopsButton)
            Positioned(
              bottom: 32,
              left: 16,
              right: 80,
              child: _StopsButton(
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
            ),
        ],
      ),
    );

  }
}

/// Botão grande e acessível para uso com luvas, estilo GPS truck
class _StopsButton extends StatelessWidget {
  const _StopsButton({required this.onPressed, this.hasActiveRoute = false});

  final VoidCallback onPressed;
  final bool hasActiveRoute;

  @override
  Widget build(BuildContext context) {
    final color1 = hasActiveRoute ? const Color(0xFF1E40AF) : const Color(0xFFE07B1A);
    final color2 = hasActiveRoute ? const Color(0xFF2563EB) : const Color(0xFFFF9F00);
    final icon =
        hasActiveRoute ? Icons.list_alt_rounded : Icons.local_shipping_rounded;
    final label = hasActiveRoute ? 'Ver / Reorganizar Paradas' : 'Paradas da Rota';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color1.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

