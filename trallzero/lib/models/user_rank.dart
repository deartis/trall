import 'package:flutter/material.dart';

/// Patente e nível do motorista baseado no XP acumulado (estilo Waze Ranks)
class UserRank {
  final int level;
  final String title;
  final String emoji;
  final Color color;
  final int minXp;
  final int maxXp; // Se int.maxFinite, é o nível máximo

  const UserRank({
    required this.level,
    required this.title,
    required this.emoji,
    required this.color,
    required this.minXp,
    required this.maxXp,
  });

  static const List<UserRank> ranks = [
    UserRank(
      level: 1,
      title: 'Novato da Estrada',
      emoji: '🥉',
      color: Color(0xFFCD7F32), // Bronze
      minXp: 0,
      maxXp: 50,
    ),
    UserRank(
      level: 2,
      title: 'Chofer Parceiro',
      emoji: '🥈',
      color: Color(0xFFC0C0C0), // Prata
      minXp: 51,
      maxXp: 200,
    ),
    UserRank(
      level: 3,
      title: 'Rei da Pista',
      emoji: '🥇',
      color: Color(0xFFFFD700), // Ouro
      minXp: 201,
      maxXp: 600,
    ),
    UserRank(
      level: 4,
      title: 'Mestre da Boleia',
      emoji: '💎',
      color: Color(0xFF00C7FF), // Diamante / Ciano
      minXp: 601,
      maxXp: 1500,
    ),
    UserRank(
      level: 5,
      title: 'Lenda da Rodovia',
      emoji: '👑',
      color: Color(0xFFFF9500), // Âmbar Real
      minXp: 1501,
      maxXp: 99999999,
    ),
  ];

  /// Obtém a patente correspondente para uma quantidade de XP
  static UserRank getRank(int xp) {
    if (xp < 0) xp = 0;
    for (final rank in ranks) {
      if (xp <= rank.maxXp) {
        return rank;
      }
    }
    return ranks.last;
  }

  /// Calcula o progresso de 0.0 a 1.0 dentro do nível atual
  double getProgress(int xp) {
    if (level == ranks.last.level) return 1.0;
    final clampedXp = xp.clamp(minXp, maxXp);
    final range = (maxXp - minXp) + 1;
    if (range <= 0) return 1.0;
    final currentInLevel = clampedXp - minXp;
    return (currentInLevel / range).clamp(0.0, 1.0);
  }

  /// Quantidade de XP restante para alcançar o próximo nível
  int getRemainingXp(int xp) {
    if (level == ranks.last.level) return 0;
    final remaining = (maxXp + 1) - xp;
    return remaining > 0 ? remaining : 0;
  }

  /// Próxima patente ou null se já estiver no nível máximo
  UserRank? get nextRank {
    if (level >= ranks.length) return null;
    return ranks[level]; // 0-indexed, level 1 -> index 1 (rank 2)
  }
}
