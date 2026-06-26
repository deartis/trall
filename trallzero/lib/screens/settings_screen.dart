import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../models/truck_profile.dart';
import '../services/truck_profile_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar com identidade visual do app ──────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF0B0E17),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A2035), Color(0xFF0B0E17)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Brilho laranja sutil
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFE07B1A).withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE07B1A).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE07B1A).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.settings_rounded,
                                color: Color(0xFFE07B1A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Configurações',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                Text(
                                  'Navegação, rota e preferências',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── SEÇÃO: VEÍCULO ─────────────────────────────────────
                _SectionLabel(label: 'VEÍCULO'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _DropdownTile(
                      icon: Icons.local_shipping_rounded,
                      iconColor: const Color(0xFFE07B1A),
                      title: 'Perfil Padrão',
                      subtitle: 'Carregado automaticamente ao abrir o app',
                      value: prefs.defaultProfileId,
                      items: TruckProfilePresets.all.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.type.name,
                          child: Text(p.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          prefs.setDefaultProfileId(val);
                          final newProfile = TruckProfilePresets.all
                              .firstWhere((p) => p.type.name == val);
                          TruckProfileService.instance.selectProfile(newProfile);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── SEÇÃO: NAVEGAÇÃO ────────────────────────────────────
                _SectionLabel(label: 'NAVEGAÇÃO'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SwitchTile(
                      icon: Icons.record_voice_over_rounded,
                      iconColor: const Color(0xFF34C759),
                      title: 'Guia por Voz (TTS)',
                      subtitle: 'Anuncia manobras e alertas em voz alta',
                      value: prefs.ttsEnabled,
                      onChanged: (val) => prefs.setTtsEnabled(val),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── SEÇÃO: INFORMAÇÕES ─────────────────────────────────
                _SectionLabel(label: 'SOBRE O APP'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _InfoTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Versão',
                      value: '0.1.0-beta',
                    ),
                    _Divider(),
                    _InfoTile(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF8E8E93),
                      title: 'Licença',
                      value: 'Privado',
                    ),
                  ],
                ),

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFE07B1A),
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF1E2535),
            underline: const SizedBox(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFE07B1A).withValues(alpha: 0.5),
            activeThumbColor: const Color(0xFFE07B1A),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: 0.05),
      height: 1,
      indent: 68,
    );
  }
}
