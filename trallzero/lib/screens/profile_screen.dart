import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../controllers/truck_controller.dart';
import '../models/truck_profile.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D26),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFFF3B30),
                  size: 26,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sair da conta?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Seus dados locais serão mantidos, mas você precisará entrar novamente para sincronizar com a nuvem.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sair',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tc = context.watch<TruckController>();
    final isSignedIn = auth.isSignedIn;
    final user = auth.currentUser;
    final currentProfile = tc.truckProfile;

    // Gamificação — placeholder (sem variáveis desnecessárias)

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: CustomScrollView(
        slivers: [
          // ── AppBar com Hero Header ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF0B0E17),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradiente de fundo
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A2035), Color(0xFF0B0E17)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Brilho laranja suave atrás do avatar
                  Positioned(
                    top: -30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFE07B1A).withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Conteúdo do header
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Avatar
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
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
                                        .withValues(alpha: 0.45),
                                    blurRadius: 24,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(3),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: const Color(0xFF0E1320),
                                backgroundImage:
                                    (isSignedIn && user?.photoUrl != null)
                                        ? NetworkImage(user!.photoUrl!)
                                        : null,
                                child: (isSignedIn && user?.photoUrl != null)
                                    ? null
                                    : Icon(
                                        isSignedIn
                                            ? Icons.person_rounded
                                            : Icons.person_outline_rounded,
                                        size: 40,
                                        color: isSignedIn
                                            ? const Color(0xFFE07B1A)
                                            : Colors.white30,
                                      ),
                              ),
                            ),
                            // Badge de nível
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE07B1A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF0E1320),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE07B1A)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '1',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Nome
                        Text(
                          isSignedIn
                              ? (user?.displayName ?? 'Motorista')
                              : 'Conta Anônima',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Email ou aviso
                        Text(
                          isSignedIn
                              ? (user?.email ?? '')
                              : 'Entre para sincronizar na nuvem',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Badge de nível
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE07B1A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE07B1A).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '⭐  Motorista',
                            style: const TextStyle(
                              color: Color(0xFFE07B1A),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo scrollável ────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Card de XP (Em breve) ───────────────────────────────────
                _SectionCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE07B1A).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          color: Color(0xFFE07B1A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sistema de Progresso',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Em breve — ganhe XP e suba de nível ao usar o Trall.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE07B1A).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE07B1A).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Text(
                          'EM BREVE',
                          style: TextStyle(
                            color: Color(0xFFE07B1A),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── CONTA ──────────────────────────────────────────
                _SectionLabel(label: isSignedIn ? 'CONTA GOOGLE' : 'CONTA'),
                const SizedBox(height: 10),
                _SectionCard(
                  child: isSignedIn
                      ? Column(
                          children: [
                            _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Nome',
                              value: user?.displayName ?? '—',
                            ),
                            _Divider(),
                            _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'E-mail',
                              value: user?.email ?? '—',
                            ),
                            _Divider(),
                            _InfoRow(
                              icon: Icons.verified_user_outlined,
                              label: 'Status',
                              value: 'Conta verificada',
                              valueColor: const Color(0xFF34C759),
                            ),
                            const SizedBox(height: 16),
                            // Botão Sair
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.logout_rounded,
                                    size: 18, color: Color(0xFFFF3B30)),
                                label: const Text(
                                  'Sair da conta',
                                  style: TextStyle(
                                    color: Color(0xFFFF3B30),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: const Color(0xFFFF3B30)
                                        .withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => _confirmSignOut(context),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      color: Colors.white.withValues(alpha: 0.3),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Você está usando o TRALL sem conta. Entre com Google para salvar seus dados na nuvem.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.login_rounded, size: 18),
                                label: const Text(
                                  'Entrar com Google',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                          ],
                        ),
                ),

                const SizedBox(height: 24),

                // ── PERFIL DO CAMINHÃO ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _SectionLabel(label: 'PERFIL DO CAMINHÃO'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07B1A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE07B1A).withValues(alpha: 0.25),
                        ),
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

                // Lista de perfis
                ...TruckProfilePresets.all.map((profile) {
                  final isSelected = profile.type == currentProfile.type;
                  return GestureDetector(
                    onTap: () => tc.setTruckProfile(profile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE07B1A).withValues(alpha: 0.08)
                            : const Color(0xFF131720),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE07B1A).withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.06),
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
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _truckProfileIcon(profile.type),
                              color: isSelected
                                  ? const Color(0xFFE07B1A)
                                  : Colors.white.withValues(alpha: 0.4),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.65),
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${profile.maxWeightKg.toInt()} kg · ${profile.maxHeightMeters} m · ${profile.axles} eixos',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFE07B1A),
                              size: 20,
                            )
                          else
                            Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: Colors.white.withValues(alpha: 0.15),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),

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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  Ícone distinto por tipo de perfil de veículo
// ───────────────────────────────────────────────────────────────
IconData _truckProfileIcon(TruckProfileType type) => switch (type) {
  TruckProfileType.lightTruck => Icons.local_shipping_rounded,      // Caminhão Leve
  TruckProfileType.truck      => Icons.fire_truck_rounded,           // Truck (3 eixos)
  TruckProfileType.carreta    => Icons.rv_hookup_rounded,            // Carreta
  TruckProfileType.bitrem     => Icons.directions_bus_filled_rounded, // Bitrem
  TruckProfileType.rodotrem   => Icons.train_rounded,                // Rodotrem (trem de estrada)
};
