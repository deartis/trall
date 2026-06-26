import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  static final PreferencesService instance = PreferencesService._internal();

  PreferencesService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  SharedPreferences get prefs => _prefs;

  // --- Chaves ---
  static const String _keyTtsEnabled = 'ttsEnabled';
  static const String _keyDefaultProfileId = 'defaultProfileId';

  // Fadiga (Lei 13.103): persiste segundos acumulados e o timestamp em que a
  // navegação foi iniciada para recalcular o tempo decorrido ao reabrir o app.
  static const String _keyFatigueSeconds = 'fatigueSeconds';
  static const String _keyFatigueStartMs = 'fatigueStartMs';

  // --- Valores em memória ---
  bool _ttsEnabled = true;
  String _defaultProfileId = 'truck';

  bool get ttsEnabled => _ttsEnabled;
  String get defaultProfileId => _defaultProfileId;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    
    _ttsEnabled = _prefs.getBool(_keyTtsEnabled) ?? true;
    _defaultProfileId = _prefs.getString(_keyDefaultProfileId) ?? 'truck';
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setTtsEnabled(bool value) async {
    _ttsEnabled = value;
    await _prefs.setBool(_keyTtsEnabled, value);
    notifyListeners();
  }

  Future<void> setDefaultProfileId(String id) async {
    _defaultProfileId = id;
    await _prefs.setString(_keyDefaultProfileId, id);
    notifyListeners();
  }

  // ── Fadiga ────────────────────────────────────────────────────────────────

  /// Salva o estado atual do timer de fadiga.
  ///
  /// [seconds] = segundos acumulados de direção contínua.
  /// [startedAt] = momento em que a navegação foi iniciada (para calcular
  /// o tempo decorrido caso o app seja fechado e reaberto enquanto dirigindo).
  Future<void> saveFatigueState({
    required int seconds,
    required DateTime startedAt,
  }) async {
    await _prefs.setInt(_keyFatigueSeconds, seconds);
    await _prefs.setInt(_keyFatigueStartMs, startedAt.millisecondsSinceEpoch);
  }

  /// Restaura o estado de fadiga.
  ///
  /// Retorna os segundos já decorridos ajustados pelo tempo real que
  /// o app ficou fechado (máximo: 8 horas — janela de descanso obrigatório).
  ///
  /// Retorna 0 se não houver estado salvo ou se o estado for muito antigo.
  int restoreFatigueSeconds() {
    final savedSeconds = _prefs.getInt(_keyFatigueSeconds) ?? 0;
    final startMs = _prefs.getInt(_keyFatigueStartMs) ?? 0;

    if (savedSeconds == 0 || startMs == 0) return 0;

    final startedAt = DateTime.fromMillisecondsSinceEpoch(startMs);
    final elapsed = DateTime.now().difference(startedAt);

    // Se ficou mais de 8 horas parado, considera descansado → zera
    if (elapsed.inHours >= 8) {
      clearFatigueState();
      return 0;
    }

    // Recalcula: segundos salvos + tempo que o app ficou fechado
    final total = savedSeconds + elapsed.inSeconds;
    return total.clamp(0, 6 * 3600); // cap em 6h (acima disso sempre crítico)
  }

  /// Limpa o estado de fadiga (ex: ao encerrar a rota ou após descanso).
  Future<void> clearFatigueState() async {
    await _prefs.remove(_keyFatigueSeconds);
    await _prefs.remove(_keyFatigueStartMs);
  }
}
