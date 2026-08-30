import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_rank.dart';
import 'api_service.dart';

/// Evento disparado quando o motorista ganha pontos
class ScoreEvent {
  final int points;
  final String reason;
  final bool leveledUp;
  final UserRank currentRank;

  const ScoreEvent({
    required this.points,
    required this.reason,
    required this.leveledUp,
    required this.currentRank,
  });
}

/// Serviço de gerenciamento de pontos, XP e reputação de motoristas (Trucker Rank)
class UserScoreService extends ChangeNotifier {
  static final UserScoreService instance = UserScoreService._internal();

  UserScoreService._internal();

  // Valores de pontos padrão
  static const int xpForNewReport = 10;
  static const int xpForConfirmation = 5;
  static const int xpForCorrection = 15;

  // Chaves de persistência
  static const String _keyXp = 'user_xp';
  static const String _keyReports = 'user_reports_count';
  static const String _keyConfirmations = 'user_confirmations_count';
  static const String _keyCorrections = 'user_corrections_count';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  int _xp = 0;
  int _reportsCount = 0;
  int _confirmationsCount = 0;
  int _correctionsCount = 0;

  final StreamController<ScoreEvent> _scoreEventController =
      StreamController<ScoreEvent>.broadcast();

  // Getters
  int get xp => _xp;
  int get reportsCount => _reportsCount;
  int get confirmationsCount => _confirmationsCount;
  int get correctionsCount => _correctionsCount;
  UserRank get currentRank => UserRank.getRank(_xp);
  Stream<ScoreEvent> get onScoreEarned => _scoreEventController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    _xp = _prefs.getInt(_keyXp) ?? 0;
    _reportsCount = _prefs.getInt(_keyReports) ?? 0;
    _confirmationsCount = _prefs.getInt(_keyConfirmations) ?? 0;
    _correctionsCount = _prefs.getInt(_keyCorrections) ?? 0;

    _isInitialized = true;
    notifyListeners();
  }

  /// Sincroniza a pontuação com a API central
  Future<void> syncWithBackend({int? userId}) async {
    final uid = userId ?? _prefs.getInt('userId');
    if (uid == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final profile = await ApiService.instance.fetchUserProfile(uid);
      if (profile != null) {
        _xp = (profile['xp'] as num?)?.toInt() ?? _xp;
        _reportsCount = (profile['reportsCount'] as num?)?.toInt() ?? _reportsCount;
        _confirmationsCount =
            (profile['confirmationsCount'] as num?)?.toInt() ?? _confirmationsCount;
        _correctionsCount =
            (profile['correctionsCount'] as num?)?.toInt() ?? _correctionsCount;

        if (_isInitialized) {
          await _prefs.setInt(_keyXp, _xp);
          await _prefs.setInt(_keyReports, _reportsCount);
          await _prefs.setInt(_keyConfirmations, _confirmationsCount);
          await _prefs.setInt(_keyCorrections, _correctionsCount);
        }
      }
    } catch (e) {
      debugPrint('Erro ao sincronizar pontuação com a API: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Aplica dados de pontuação retornados diretamente por uma resposta da API
  Future<ScoreEvent?> applyRemoteScore(
    Map<String, dynamic> remoteData, {
    int? pointsEarned,
    String? reason,
  }) async {
    final oldRank = UserRank.getRank(_xp);

    if (remoteData['xp'] != null) {
      _xp = (remoteData['xp'] as num).toInt();
    }
    if (remoteData['reportsCount'] != null) {
      _reportsCount = (remoteData['reportsCount'] as num).toInt();
    }
    if (remoteData['confirmationsCount'] != null) {
      _confirmationsCount = (remoteData['confirmationsCount'] as num).toInt();
    }
    if (remoteData['correctionsCount'] != null) {
      _correctionsCount = (remoteData['correctionsCount'] as num).toInt();
    }

    if (_isInitialized) {
      await _prefs.setInt(_keyXp, _xp);
      await _prefs.setInt(_keyReports, _reportsCount);
      await _prefs.setInt(_keyConfirmations, _confirmationsCount);
      await _prefs.setInt(_keyCorrections, _correctionsCount);
    }

    final newRank = UserRank.getRank(_xp);
    final leveledUp = newRank.level > oldRank.level;

    notifyListeners();

    if (pointsEarned != null && pointsEarned > 0) {
      final event = ScoreEvent(
        points: pointsEarned,
        reason: reason ?? 'Pontos recebidos!',
        leveledUp: leveledUp,
        currentRank: newRank,
      );
      _scoreEventController.add(event);
      return event;
    }
    return null;
  }

  /// Adiciona pontuação para um novo alerta criado na via
  Future<ScoreEvent> addScoreForNewReport() async {
    _reportsCount++;
    if (_isInitialized) {
      await _prefs.setInt(_keyReports, _reportsCount);
    }
    return addScore(xpForNewReport, 'Novo Alerta Adicionado!');
  }

  /// Adiciona pontuação para a confirmação de presença de um alerta existente
  Future<ScoreEvent> addScoreForConfirmation() async {
    _confirmationsCount++;
    if (_isInitialized) {
      await _prefs.setInt(_keyConfirmations, _confirmationsCount);
    }
    return addScore(xpForConfirmation, 'Presença Confirmada!');
  }

  /// Adiciona pontuação para resolução de conflito ou correção de alerta
  Future<ScoreEvent> addScoreForCorrection() async {
    _correctionsCount++;
    if (_isInitialized) {
      await _prefs.setInt(_keyCorrections, _correctionsCount);
    }
    return addScore(xpForCorrection, 'Alerta Corrigido!');
  }

  /// Adiciona uma quantidade arbitrária de XP e dispara o evento
  Future<ScoreEvent> addScore(int points, String reason) async {
    final oldRank = UserRank.getRank(_xp);
    _xp += points;
    final newRank = UserRank.getRank(_xp);
    final leveledUp = newRank.level > oldRank.level;

    if (_isInitialized) {
      await _prefs.setInt(_keyXp, _xp);
    }

    final event = ScoreEvent(
      points: points,
      reason: reason,
      leveledUp: leveledUp,
      currentRank: newRank,
    );

    _scoreEventController.add(event);
    notifyListeners();
    return event;
  }

  /// Reseta todos os pontos e contadores (para testes ou logout completo)
  Future<void> reset() async {
    _xp = 0;
    _reportsCount = 0;
    _confirmationsCount = 0;
    _correctionsCount = 0;

    if (_isInitialized) {
      await _prefs.remove(_keyXp);
      await _prefs.remove(_keyReports);
      await _prefs.remove(_keyConfirmations);
      await _prefs.remove(_keyCorrections);
    }

    notifyListeners();
  }
}
