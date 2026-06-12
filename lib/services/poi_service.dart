import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/marker_model.dart';

class PoiService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Busca pontos de interesse (POIs) ao redor de uma localização, num raio específico em metros.
  static Future<List<TruckerMarker>?> fetchPOIsAround(LatLng center, {double radius = 5000}) async {
    final lat = center.latitude;
    final lon = center.longitude;

    // A query Overpass em Overpass QL
    // Buscamos postos de combustível, borracharias/oficinas e restaurantes
    final query = '''
      [out:json][timeout:25];
      (
        nwr["amenity"="fuel"](around:$radius,$lat,$lon);
        nwr["shop"="car_repair"](around:$radius,$lat,$lon);
        nwr["amenity"="restaurant"](around:$radius,$lat,$lon);
      );
      out center tags;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'User-Agent': 'TrallZeroApp'},
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;
        
        debugPrint('POI Service: Retornou \${elements.length} elementos do Overpass.');

        final List<TruckerMarker> markers = [];
        for (var element in elements) {
          double? elementLat;
          double? elementLon;

          try {
            if (element['type'] == 'node') {
              elementLat = (element['lat'] as num?)?.toDouble();
              elementLon = (element['lon'] as num?)?.toDouble();
            } else if (element['center'] != null) {
              elementLat = (element['center']['lat'] as num?)?.toDouble();
              elementLon = (element['center']['lon'] as num?)?.toDouble();
            }
          } catch (e) {
            debugPrint('Erro ao parsear coordenada: $e');
          }

          if (elementLat == null || elementLon == null) continue;

          final tags = element['tags'] as Map<String, dynamic>? ?? {};

          MarkerType type = MarkerType.other;
          String description = 'Ponto de Interesse';

          if (tags['amenity'] == 'fuel') {
            type = MarkerType.gasStation;
            description = tags['name'] ?? 'Posto de Combustível';
          } else if (tags['shop'] == 'car_repair') {
            type = MarkerType.mechanic;
            description = tags['name'] ?? 'Mecânica / Borracharia';
          } else if (tags['amenity'] == 'restaurant') {
            type = MarkerType.restaurant;
            description = tags['name'] ?? 'Parada / Restaurante';
          }

          // Adicionamos a marca (ex: Shell, Petrobras) se disponível
          if (tags['brand'] != null) {
            description += ' - ${tags['brand']}';
          }

          markers.add(TruckerMarker(
            id: 'osm_${element['id']}',
            position: LatLng(elementLat, elementLon),
            type: type,
            description: description,
          ));
        }
        return markers;
      } else {
        debugPrint('Erro na Overpass API: ${response.statusCode}');
        debugPrint('Detalhes do erro: ${response.body}');
        return null;
      }
    } catch (e, stacktrace) {
      debugPrint('Exceção ao buscar POIs: $e');
      debugPrint('Stacktrace: $stacktrace');
      return null;
    }
  }
}
