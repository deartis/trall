import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../controllers/truck_controller.dart';
import '../models/truck_profile.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tc = context.watch<TruckController>();
    final isSignedIn = auth.isSignedIn;
    final user = auth.currentUser;
    final currentProfile = tc.truckProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text(
          'Perfil e Veículo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── SEÇÃO DA CONTA DO USUÁRIO ──
          const Text(
            'CONTA',
            style: TextStyle(
              color: Color(0xFFE07B1A),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isSignedIn
                          ? const Color(0xFF34C759).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      backgroundImage: (isSignedIn && user?.photoUrl != null)
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: (isSignedIn && user?.photoUrl != null)
                          ? null
                          : Icon(
                              isSignedIn
                                  ? Icons.person_rounded
                                  : Icons.person_outline_rounded,
                              size: 32,
                              color: isSignedIn
                                  ? const Color(0xFF34C759)
                                  : Colors.white30,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSignedIn
                                ? (user?.displayName ?? 'Usuário Google')
                                : 'Conta Anônima',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSignedIn
                                ? (user?.email ?? '')
                                : 'Os dados não estão sincronizados em nuvem',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!isSignedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Entrar com Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout_rounded,
                          color: Colors.redAccent),
                      label: const Text('Sair da conta',
                          style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await auth.signOut();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── SEÇÃO DO VEÍCULO ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PERFIL DO CAMINHÃO',
                style: TextStyle(
                  color: Color(0xFFE07B1A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE07B1A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentProfile.label,
                  style: const TextStyle(
                    color: Color(0xFFE07B1A),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista de Perfis Presets do Caminhão
          ...TruckProfilePresets.all.map((profile) {
            final isSelected = profile.type == currentProfile.type;
            return GestureDetector(
              onTap: () => tc.setTruckProfile(profile),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE07B1A).withValues(alpha: 0.08)
                      : const Color(0xFF1E2128),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFE07B1A).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.05),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE07B1A).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        color: isSelected
                            ? const Color(0xFFE07B1A)
                            : Colors.white70,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 15,
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${profile.maxWeightKg.toInt()} kg · ${profile.maxHeightMeters} m · ${profile.axles} eixos',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFE07B1A),
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
