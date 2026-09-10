import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/marker_model.dart';
import 'preferences_service.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();

  late final FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Timestamp da última fala — usado para o cooldown global de 30 s
  DateTime? _lastSpeakTime;
  static const Duration _cooldownDuration = Duration(seconds: 30);

  TtsService._internal() {
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      final dynamic isLanguageAvailable =
          await _flutterTts.isLanguageAvailable('pt-BR');
      if (isLanguageAvailable == true) {
        await _flutterTts.setLanguage('pt-BR');
        debugPrint('[TTS] Linguagem pt-BR configurada com sucesso.');
      } else {
        final dynamic isPtAvailable =
            await _flutterTts.isLanguageAvailable('pt');
        if (isPtAvailable == true) {
          await _flutterTts.setLanguage('pt');
          debugPrint(
              '[TTS] Linguagem pt-BR indisponível, usando fallback "pt".');
        } else {
          debugPrint(
              '[TTS] Nenhuma linguagem em português (pt-BR / pt) está disponível neste dispositivo.');
        }
      }
      await _flutterTts.setSpeechRate(0.48); // Clara e ligeiramente mais lenta
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() => _isSpeaking = true);
      _flutterTts.setCompletionHandler(() => _isSpeaking = false);
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[TTS Error] $msg');
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TTS Init Error] $e');
    }
  }

  // ── Cooldown global ───────────────────────────────────────────────────────

  /// Retorna true se já passou o cooldown mínimo desde a última fala.
  bool get canSpeak {
    if (_lastSpeakTime == null) return true;
    return DateTime.now().difference(_lastSpeakTime!) >= _cooldownDuration;
  }

  // ── Fala genérica ─────────────────────────────────────────────────────────

  Future<void> speak(String text) async {
    if (!_isInitialized) return;
    if (!PreferencesService.instance.ttsEnabled) return;

    if (_isSpeaking) await stop();

    _lastSpeakTime = DateTime.now();
    await _flutterTts.speak(text);
  }

  // ── Alerta de marcador de mapa ─────────────────────────────────────────────

  /// Anuncia um marcador do mapa com frase natural em português.
  /// [distanceLabel] ex: "350 m" ou "1,2 km"  — incluso na frase quando relevante.
  Future<void> speakMarkerAlert(
    MarkerType type, {
    String? distanceLabel,
  }) async {
    if (!_isInitialized) return;
    if (!PreferencesService.instance.ttsEnabled) return;
    if (!canSpeak) return;

    final dist =
        distanceLabel != null ? ', em $distanceLabel' : '';

    final String text = switch (type) {
      MarkerType.restriction =>
        'Atenção. Restrição de trânsito à frente$dist.',
      MarkerType.weighStation =>
        'Balança à frente$dist. Prepare sua documentação.',
      MarkerType.police =>
        'Polícia à frente$dist.',
      MarkerType.danger =>
        'Atenção. Perigo na pista à frente$dist.',
      MarkerType.speedCamera =>
        'Radar à frente$dist. Reduza a velocidade.',
      MarkerType.loading =>
        'Ponto de carga à frente$dist.',
      MarkerType.parking =>
        'Estacionamento para caminhões à frente$dist.',
      MarkerType.gasStation =>
        'Posto de combustível à frente$dist.',
      MarkerType.mechanic =>
        'Mecânico à frente$dist.',
      MarkerType.restaurant =>
        'Restaurante à frente$dist.',
      _ =>
        'Alerta de trânsito à frente$dist.',
    };

    if (_isSpeaking) await stop();
    _lastSpeakTime = DateTime.now();
    await _flutterTts.speak(text);
    debugPrint('[TTS] Anunciando marcador ${type.name}: "$text"');
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
    _isSpeaking = false;
  }
}
