import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Resultado de uma consulta de CEP.
class CepResult {
  final String logradouro;
  final String bairro;
  final String cidade;
  final String estado;
  final String cep;

  const CepResult({
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.estado,
    required this.cep,
  });

  /// Endereço formatado para exibição e busca de geocódigo.
  String get formattedAddress {
    final parts = <String>[];
    if (logradouro.isNotEmpty) parts.add(logradouro);
    if (bairro.isNotEmpty) parts.add(bairro);
    if (cidade.isNotEmpty) parts.add(cidade);
    if (estado.isNotEmpty) parts.add(estado);
    return parts.join(', ');
  }

  /// Endereço curto para exibição na lista de sugestões.
  String get shortAddress {
    final parts = <String>[];
    if (logradouro.isNotEmpty) parts.add(logradouro);
    if (cidade.isNotEmpty) parts.add(cidade);
    if (estado.isNotEmpty) parts.add(estado);
    return parts.join(', ');
  }
}

/// Serviço de consulta de CEP via ViaCEP (gratuito, sem chave de API).
///
/// Docs: https://viacep.com.br/
abstract final class CepService {
  static const _timeout = Duration(seconds: 8);

  /// Retorna true se [query] parece ser um CEP brasileiro.
  /// Aceita formatos: "01310-100", "01310100".
  static bool isCep(String query) {
    final cleaned = query.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 8;
  }

  /// Normaliza para o formato sem traço (ex: "01310100").
  static String _normalize(String cep) =>
      cep.replaceAll(RegExp(r'[^\d]'), '');

  /// Busca os dados de um CEP.
  /// Retorna null se o CEP não existir ou houver erro.
  static Future<CepResult?> lookup(String cep) async {
    final normalized = _normalize(cep);
    if (normalized.length != 8) return null;

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$normalized/json/');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;

      // ViaCEP retorna {"erro": true} para CEPs inválidos
      if (data['erro'] == true) return null;

      return CepResult(
        logradouro: (data['logradouro'] as String? ?? '').trim(),
        bairro: (data['bairro'] as String? ?? '').trim(),
        cidade: (data['localidade'] as String? ?? '').trim(),
        estado: (data['uf'] as String? ?? '').trim(),
        cep: (data['cep'] as String? ?? normalized),
      );
    } catch (e) {
      debugPrint('[CepService] Erro ao consultar CEP $normalized: $e');
      return null;
    }
  }

  /// Geocodifica um CEP via Nominatim e retorna as coordenadas.
  /// Usa o endereço completo para maior precisão.
  static Future<LatLng?> geocode(CepResult result) async {
    try {
      final query = Uri.encodeComponent(
        '${result.logradouro}, ${result.bairro}, ${result.cidade}, ${result.estado}, Brasil',
      );
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$query&format=json&limit=1&countrycodes=br',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'TrallApp/1.0'})
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final List data = json.decode(response.body);
      if (data.isEmpty) return null;

      final lat = double.tryParse(data[0]['lat'] as String? ?? '');
      final lon = double.tryParse(data[0]['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;

      return LatLng(lat, lon);
    } catch (e) {
      debugPrint('[CepService] Erro ao geocodificar CEP: $e');
      return null;
    }
  }
}
