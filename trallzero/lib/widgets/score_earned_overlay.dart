import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_score_service.dart';

/// Feedback visual e tátil imediato ao ganhar pontos ou subir de nível
class ScoreEarnedOverlay {
  static void show(BuildContext context, ScoreEvent event) {
    if (event.leveledUp) {
      HapticFeedback.heavyImpact();
      _showLevelUpDialog(context, event);
    } else {
      HapticFeedback.mediumImpact();
      _showScoreSnackBar(context, event);
    }
  }

  static void _showScoreSnackBar(BuildContext context, ScoreEvent event) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF111318),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: event.currentRank.color.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        content: Row(
          children: [
            // Badge com XP ganho
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    event.currentRank.color,
                    event.currentRank.color.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: event.currentRank.color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '+${event.points} XP',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.reason,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.currentRank.emoji} ${event.currentRank.title} (Nível ${event.currentRank.level})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.stars_rounded,
              color: Color(0xFFFFD700),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  static void _showLevelUpDialog(BuildContext context, ScoreEvent event) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111318),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: event.currentRank.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: event.currentRank.color.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone da nova patente com glow
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: event.currentRank.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: event.currentRank.color,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    event.currentRank.emoji,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'NOVA PATENTE ALCANÇADA!',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                event.currentRank.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Parabéns! Suas validações e reportes na rodovia agora têm maior peso e credibilidade na comunidade.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: event.currentRank.color,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Continuar na Pista',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
