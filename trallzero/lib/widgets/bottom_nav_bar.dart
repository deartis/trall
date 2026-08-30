import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/truck_controller.dart';
import '../core/app_colors.dart';

/// Bottom Navigation Bar premium do Trall.
///
/// Some automaticamente durante navegação ativa para não distrair.
/// Tabs: Mapa | Paradas | Perfil
///
/// [currentIndex] : tab ativa (0=Mapa, 1=Paradas, 2=Perfil)
/// [onTap]        : callback com o índice tocado
class TrallBottomNav extends StatelessWidget {
  const TrallBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  static const _tabs = [
    _TabData(icon: Icons.map_rounded, label: 'Mapa'),
    _TabData(icon: Icons.alt_route_rounded, label: 'Paradas'),
    _TabData(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final tc = context.watch<TruckController>();
    final isNavigating = tc.isNavigating;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      offset: isNavigating ? const Offset(0, 1.5) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isNavigating ? 0.0 : 1.0,
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12, safeBottom + 10),
          decoration: BoxDecoration(
            color: AppColors.bgPanel,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final selected = i == currentIndex;
              return Expanded(
                child: _TabItem(
                  icon: tab.icon,
                  label: tab.label,
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  final IconData icon;
  final String label;
  const _TabData({required this.icon, required this.label});
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.amber.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 36 : 28,
              height: selected ? 36 : 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.amber.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: selected ? 22 : 20,
                color: selected
                    ? AppColors.amber
                    : Colors.white.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: selected
                    ? AppColors.amber
                    : Colors.white.withValues(alpha: 0.35),
                fontSize: selected ? 10.5 : 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
