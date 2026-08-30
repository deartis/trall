import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'preferences_service.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();

  late final FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  TtsService._internal() {
    _flutterTts = FlutterTts();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      final dynamic isLanguageAvailable = await _flutterTts.isLanguageAvailable("pt-BR");
      if (isLanguageAvailable == true) {
        await _flutterTts.setLanguage("pt-BR");
        debugPrint('[TTS] Linguagem pt-BR configurada com sucesso.');
      } else {
        final dynamic isPtAvailable = await _flutterTts.isLanguageAvailable("pt");
        if (isPtAvailable == true) {
          await _flutterTts.setLanguage("pt");
          debugPrint('[TTS] Linguagem pt-BR indisponível, usando fallback "pt".');
        } else {
          debugPrint('[TTS] Nenhuma linguagem em português (pt-BR / pt) está disponível neste dispositivo.');
        }
      }
      await _flutterTts.setSpeechRate(0.5); // Velocidade agradável e clara
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[TTS Error] $msg');
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TTS Init Error] $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) return;
    
    // Respeita a preferência do usuário de ativar/desativar a voz
    if (!PreferencesService.instance.ttsEnabled) return;
    
    // Se já estiver falando algo, interrompe para falar a nova prioridade
    if (_isSpeaking) {
      await stop();
    }
    
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
    _isSpeaking = false;
  }
}
