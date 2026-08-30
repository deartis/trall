import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/truck_controller.dart';

/// Modal para opções de evitar rotas (Pedágios, Balsas, Terra)
class AvoidOptionsSheet extends StatelessWidget {
  const AvoidOptionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Evitar na Rota',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O aplicativo irá recalcular a rota para evitar as opções abaixo quando possível.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSwitch(
              icon: Icons.toll_rounded,
              title: 'Evitar Pedágios',
              value: tc.avoidTolls,
              onChanged: (val) => context.read<TruckController>().toggleAvoidTolls(),
            ),
            const SizedBox(height: 16),
            _buildSwitch(
              icon: Icons.directions_boat_rounded,
              title: 'Evitar Balsas',
              value: tc.avoidFerries,
              onChanged: (val) => context.read<TruckController>().toggleAvoidFerries(),
            ),
            const SizedBox(height: 16),
            _buildSwitch(
              icon: Icons.landscape_rounded,
              title: 'Evitar Estradas de Terra',
              value: tc.avoidUnpaved,
              onChanged: (val) => context.read<TruckController>().toggleAvoidUnpaved(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? const Color(0xFFFF3B30).withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: value ? const Color(0xFFFF3B30) : Colors.white70,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFFFF3B30).withValues(alpha: 0.5),
        activeThumbColor: const Color(0xFFFF3B30),
      ),
    );
  }
}
