import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'preferences_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web Client ID do Google Cloud Console (necessário para obter idToken no Android)
    serverClientId: '346260989283-aa5oksfe48vhcjae2lncgokvl6n08fml.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _currentUser != null;

  /// Tenta silenciosamente restaurar a sessão anterior
  Future<void> tryRestoreSession() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        debugPrint('✅ Sessão Google restaurada: ${_currentUser!.email}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Nenhuma sessão anterior para restaurar: $e');
    }
  }

  /// Abre a tela de seleção de conta do Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // Usuário cancelou
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = account;

      // Obtém o token de autenticação para enviar ao backend
      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken != null) {
        // Envia para o backend registrar/logar o usuário
        await _loginWithBackend(
          googleId: account.id,
          email: account.email,
          name: account.displayName ?? account.email,
          idToken: idToken,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Erro no Google Sign-In: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Envia as credenciais do Google para o backend criar/recuperar o usuário
  Future<void> _loginWithBackend({
    required String googleId,
    required String email,
    required String name,
    required String idToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/users/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'googleId': googleId,
          'email': email,
          'name': name,
          'idToken': idToken, // Backend pode validar com Google se quiser
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final userId = data['data']['id'];
        await PreferencesService.instance.prefs.setInt('userId', userId);
        ApiService.instance.setUserId(userId);
        debugPrint('✅ Login Google bem-sucedido! userId: $userId');
      } else {
        debugPrint('❌ Falha no backend: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao comunicar com backend: $e');
    }
  }

  /// Faz logout da conta Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;

    // Limpa o userId salvo (volta ao modo fantasma)
    await PreferencesService.instance.prefs.remove('userId');
    ApiService.instance.setUserId(null);

    notifyListeners();
    debugPrint('Logout realizado.');
  }
}
