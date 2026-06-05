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
}
