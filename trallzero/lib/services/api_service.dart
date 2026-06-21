import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/marker_model.dart';
import 'preferences_service.dart';
import 'dart:io' show Platform;

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:3000/api';
    if (Platform.isAndroid || Platform.isIOS) return 'https://api.trall.jalsl.com/api';
    return 'https://api.trall.jalsl.com/api';
  }

  int? _userId;
  int? get userId => _userId;

  /// Permite que o AuthService atualize o userId após login com Google
  void setUserId(int? id) {
    _userId = id;
  }

  Future<void> init() async {
    _userId = PreferencesService.instance.prefs.getInt('userId');
    
    await testConnection();
    
    if (_userId == null) {
      await _registerGhostUser();
    } else {
      debugPrint('Usuário já logado com ID: $_userId');
    }
  }

  Future<bool> testConnection() async {
    try {
      debugPrint('Testando conexão com a API em: $baseUrl/health');
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Conexão com API bem-sucedida! Retorno: ${data['message']}');
        return true;
      } else {
        debugPrint('❌ Falha na conexão com a API. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erro de conexão com a API: $e');
      return false;
    }
  }

  Future<void> _registerGhostUser() async {
    try {
      final name = 'Motorista ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final email = 'motorista_${DateTime.now().millisecondsSinceEpoch}@trall.com';
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': '123'
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _userId = data['data']['id'];
        await PreferencesService.instance.prefs.setInt('userId', _userId!);
        debugPrint('Usuário fantasma cadastrado: $_userId - $name');
      } else {
        debugPrint('Falha ao cadastrar: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erro ao cadastrar usuário fantasma: $e');
    }
  }

  Future<List<TruckerMarker>> fetchAlerts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/alerts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List alerts = data['data'];
        
        return alerts.map((a) {
          return TruckerMarker(
            id: a['id'].toString(),
            position: LatLng(a['latitude'], a['longitude']),
            type: _mapType(a['type']),
            description: a['description'] ?? '',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Erro ao buscar alertas da API: $e');
    }
    return [];
  }

  Future<bool> postAlert(TruckerMarker marker) async {
    if (_userId == null) {
      debugPrint('Erro ao postar alerta: _userId está nulo!');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': _unmapType(marker.type),
          'latitude': marker.position.latitude,
          'longitude': marker.position.longitude,
          'description': marker.description,
          'userId': _userId,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        debugPrint('Falha ao postar alerta. Código de status: ${response.statusCode}, Corpo: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao postar alerta: $e');
      return false;
    }
  }

  // ── ROTAS ────────────────────────────────────────────────────────────────

  /// Salva (ou substitui) a rota ativa do usuário no banco.
  /// Retorna a lista de paradas com os IDs reais do banco preenchidos.
  Future<List<Map<String, dynamic>>?> saveRoute(
      List<dynamic> stops, String truckType) async {
    if (_userId == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/routes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'truckType': truckType,
          'stops': stops,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final List stopsJson = data['data']['stops'];
        return stopsJson.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Erro ao salvar rota: $e');
    }
    return null;
  }

  /// Busca a rota ativa do usuário. Retorna null se não houver.
  Future<List<Map<String, dynamic>>?> fetchActiveRoute() async {
    if (_userId == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/routes/active?userId=$_userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] == null) return null;
        final List stops = data['data']['stops'];
        return stops.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Erro ao buscar rota ativa: $e');
    }
    return null;
  }

  /// Marca uma parada como concluída (ou não) pelo seu ID no banco.
  Future<void> markStopCompleted(int stopId, {bool completed = true}) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/routes/stops/$stopId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isCompleted': completed}),
      );
    } catch (e) {
      debugPrint('Erro ao marcar parada: $e');
    }
  }

  /// Encerra a rota ativa no banco (soft delete — isActive = false).
  Future<void> clearActiveRoute() async {
    if (_userId == null) return;
    try {
      await http.delete(
        Uri.parse('$baseUrl/routes/active?userId=$_userId'),
      );
    } catch (e) {
      debugPrint('Erro ao encerrar rota: $e');
    }
  }


  MarkerType _mapType(String apiType) {
    switch (apiType) {
      case 'MAX_HEIGHT': return MarkerType.restriction;
      case 'WEIGH_STATION': return MarkerType.weighStation;
      case 'POLICE': return MarkerType.police;
      case 'RISK_AREA': return MarkerType.danger;
      case 'PROHIBITED_AREA': return MarkerType.danger;
      case 'HILL': return MarkerType.danger;
      case 'GAS_STATION': return MarkerType.gasStation;
      case 'MECHANIC': return MarkerType.mechanic;
      case 'RESTAURANT': return MarkerType.restaurant;
      default: return MarkerType.other;
    }
  }

  String _unmapType(MarkerType type) {
    switch (type) {
      case MarkerType.restriction: return 'MAX_HEIGHT';
      case MarkerType.weighStation: return 'WEIGH_STATION';
      case MarkerType.police: return 'POLICE';
      case MarkerType.danger: return 'RISK_AREA';
      case MarkerType.loading: return 'LOAD_UNLOAD';
      case MarkerType.unloading: return 'LOAD_UNLOAD';
      case MarkerType.parking: return 'OTHER';
      case MarkerType.gasStation: return 'GAS_STATION';
      case MarkerType.mechanic: return 'MECHANIC';
      case MarkerType.restaurant: return 'RESTAURANT';
      case MarkerType.other: return 'OTHER';
    }
  }
}
