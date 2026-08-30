import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trallzero/models/marker_model.dart';
import 'package:trallzero/services/marker_deduplication_service.dart';

void main() {
  group('MarkerDeduplicationService Tests', () {
    test('headingDifference calcula a menor diferença angular corretamente', () {
      expect(MarkerDeduplicationService.headingDifference(0, 350), 10.0);
      expect(MarkerDeduplicationService.headingDifference(350, 0), 10.0);
      expect(MarkerDeduplicationService.headingDifference(10, 190), 180.0);
      expect(MarkerDeduplicationService.headingDifference(45, 65), 20.0);
      expect(MarkerDeduplicationService.headingDifference(0, 180), 180.0);
    });

    test('Lista vazia de marcadores retorna createNew', () {
      final res = MarkerDeduplicationService.evaluate(
        point: const LatLng(-23.5505, -46.6333),
        proposedType: MarkerType.speedCamera,
        existingMarkers: [],
      );

      expect(res.action, DeduplicationAction.createNew);
    });

    test('Marcador do mesmo tipo próximo e no mesmo sentido retorna confirmExisting', () {
      final basePoint = const LatLng(-23.5505, -46.6333);
      // Ponto ~30m de distância
      final nearbyPoint = const LatLng(-23.5507, -46.6333);

      final existing = [
        TruckerMarker(
          id: '1',
          position: nearbyPoint,
          type: MarkerType.speedCamera,
          heading: 90.0,
          confirmations: 2,
        ),
      ];

      final res = MarkerDeduplicationService.evaluate(
        point: basePoint,
        proposedType: MarkerType.speedCamera,
        existingMarkers: existing,
        heading: 95.0, // Sentido compatível (apenas 5° de diferença)
      );

      expect(res.action, DeduplicationAction.confirmExisting);
      expect(res.existingMarker?.id, '1');
      expect(res.distanceMeters, isNotNull);
      expect(res.distanceMeters!, lessThan(80.0));
    });

    test('Marcador do mesmo tipo próximo mas em SENTIDO OPOSTO (pista contrária) retorna createNew', () {
      final basePoint = const LatLng(-23.5505, -46.6333);
      final nearbyPoint = const LatLng(-23.5507, -46.6333);

      final existing = [
        TruckerMarker(
          id: '1',
          position: nearbyPoint,
          type: MarkerType.speedCamera,
          heading: 90.0, // Sentido Leste
        ),
      ];

      final res = MarkerDeduplicationService.evaluate(
        point: basePoint,
        proposedType: MarkerType.speedCamera,
        existingMarkers: existing,
        heading: 270.0, // Sentido Oeste (180° de diferença — pista contrária!)
      );

      expect(res.action, DeduplicationAction.createNew);
    });

    test('Marcador de TIPO DIFERENTE próximo no mesmo sentido retorna conflictDifferentType', () {
      final basePoint = const LatLng(-23.5505, -46.6333);
      final nearbyPoint = const LatLng(-23.5507, -46.6333);

      final existing = [
        TruckerMarker(
          id: '1',
          position: nearbyPoint,
          type: MarkerType.danger, // Já existe perigo
          heading: 45.0,
        ),
      ];

      final res = MarkerDeduplicationService.evaluate(
        point: basePoint,
        proposedType: MarkerType.weighStation, // Usuário quer marcar Balança
        existingMarkers: existing,
        heading: 50.0,
      );

      expect(res.action, DeduplicationAction.conflictDifferentType);
      expect(res.existingMarker?.type, MarkerType.danger);
    });

    test('Marcador fora do raio de 80m retorna createNew', () {
      final basePoint = const LatLng(-23.5505, -46.6333);
      // Ponto a ~500m de distância
      final farPoint = const LatLng(-23.5550, -46.6333);

      final existing = [
        TruckerMarker(
          id: '1',
          position: farPoint,
          type: MarkerType.speedCamera,
          heading: 90.0,
        ),
      ];

      final res = MarkerDeduplicationService.evaluate(
        point: basePoint,
        proposedType: MarkerType.speedCamera,
        existingMarkers: existing,
        heading: 90.0,
      );

      expect(res.action, DeduplicationAction.createNew);
    });
  });
}
