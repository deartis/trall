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
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text(
          'Configurações',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          // ── Título da Seção ──
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'Navegação & Rota',
              style: TextStyle(
                color: Colors.blueAccent.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),

          // ── Perfil Padrão ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.local_shipping_rounded, color: Colors.white70),
                  title: const Text('Perfil de Caminhão Padrão', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Carregado automaticamente ao abrir o app',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  trailing: DropdownButton<String>(
                    value: prefs.defaultProfileId,
                    dropdownColor: const Color(0xFF2A2E39),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    items: TruckProfilePresets.all.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.type.name,
                        child: Text(p.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        prefs.setDefaultProfileId(val);
                        // Também já altera para a sessão atual para refletir imediatamente
                        final newProfile = TruckProfilePresets.all.firstWhere((p) => p.type.name == val);
                        TruckProfileService.instance.selectProfile(newProfile);
                      }
                    },
                  ),
                ),
                
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 56),

                // ── Voz TTS ──
                SwitchListTile(
                  activeTrackColor: Colors.blueAccent.withValues(alpha: 0.5),
                  activeThumbColor: Colors.blueAccent,
                  secondary: const Icon(Icons.record_voice_over_rounded, color: Colors.white70),
                  title: const Text('Guia por Voz (TTS)', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Anuncia as manobras e alertas em voz alta',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                  value: prefs.ttsEnabled,
                  onChanged: (val) => prefs.setTtsEnabled(val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
