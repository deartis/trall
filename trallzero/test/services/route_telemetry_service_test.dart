import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trallzero/services/route_telemetry_service.dart';

void main() {
  group('RouteTelemetryService Tests', () {
    late RouteTelemetryService service;

    // Rota simples de 3 pontos em linha reta Norte-Sul
    // Latitude -22.9000 até -22.9200 (~2.2 km no meridiano)
    final points = [
      const LatLng(-22.9000, -43.1800), // P0
      const LatLng(-22.9100, -43.1800), // P1 (~1100m de P0)
      const LatLng(-22.9200, -43.1800), // P2 (~1100m de P1, ~2200m total)
    ];

    const double totalDistance = 2220.0;
    const double totalDuration = 222.0; // 10 m/s = 36 km/h nominal

    setUp(() {
      service = RouteTelemetryService.instance;
      service.reset();
      service.initRoute(
        points: points,
        totalDistance: totalDistance,
        totalDuration: totalDuration,
      );
    });

    test('Inicialização e telemetria no início da rota', () {
      final now = DateTime(2026, 8, 30, 12, 0, 0);
      final result = service.update(
        position: points[0],
        speedMps: 10.0,
        segmentIndex: 0,
        currentTime: now,
      );

      // No início da rota, a distância restante deve ser próxima da distância total
      expect(result.remainingDistanceMeters, closeTo(2220.0, 50.0));
      expect(result.progressPercent, closeTo(0.0, 0.05));
      expect(result.remainingDurationSeconds, greaterThan(0));
    });

    test('Progresso e redução da distância restante no meio da rota', () {
      final now = DateTime(2026, 8, 30, 12, 0, 0);

      // Ponto P1 (metade do trajeto)
      final result = service.update(
        position: points[1],
        speedMps: 10.0,
        segmentIndex: 1,
        currentTime: now,
      );

      // Resta apenas o trecho P1 -> P2 (~1110m)
      expect(result.remainingDistanceMeters, closeTo(1110.0, 50.0));
      expect(result.progressPercent, closeTo(0.5, 0.05));
    });

    test('Telemetria ao atingir o destino final', () {
      final now = DateTime(2026, 8, 30, 12, 5, 0);

      // Ponto P2 (destino final)
      final result = service.update(
        position: points[2],
        speedMps: 0.0,
        segmentIndex: 1,
        currentTime: now,
      );

      expect(result.remainingDistanceMeters, lessThan(15.0));
      expect(result.remainingDurationSeconds, 0.0);
      expect(result.progressPercent, closeTo(1.0, 0.01));
      expect(result.estimatedArrival, now);
    });

    test('Buffer de velocidade móvel filtra paradas em semáforos/pedágios', () {
      final baseTime = DateTime(2026, 8, 30, 12, 0, 0);

      // 3 amostras dirigindo a 15 m/s (54 km/h)
      service.update(
        position: points[0],
        speedMps: 15.0,
        segmentIndex: 0,
        currentTime: baseTime,
      );
      service.update(
        position: points[0],
        speedMps: 15.0,
        segmentIndex: 0,
        currentTime: baseTime.add(const Duration(seconds: 2)),
      );
      final movingResult = service.update(
        position: points[0],
        speedMps: 15.0,
        segmentIndex: 0,
        currentTime: baseTime.add(const Duration(seconds: 4)),
      );

      expect(movingResult.averageSpeedKmh, closeTo(54.0, 1.0));

      // Caminhão para no semáforo (0 m/s)
      final stoppedResult = service.update(
        position: points[0],
        speedMps: 0.0,
        segmentIndex: 0,
        currentTime: baseTime.add(const Duration(seconds: 6)),
      );

      // A média de deslocamento não é destruída para 0 instantaneamente
      expect(stoppedResult.averageSpeedKmh, closeTo(54.0, 1.0));
      expect(stoppedResult.remainingDurationSeconds, greaterThan(0));
    });

    test('Suavização EMA evita saltos bruscos no tempo de chegada', () {
      final baseTime = DateTime(2026, 8, 30, 12, 0, 0);

      // Primeira estimativa a 10 m/s
      final r1 = service.update(
        position: points[0],
        speedMps: 10.0,
        segmentIndex: 0,
        currentTime: baseTime,
      );

      // Frenagem momentânea para 3 m/s
      final r2 = service.update(
        position: points[0],
        speedMps: 3.0,
        segmentIndex: 0,
        currentTime: baseTime.add(const Duration(seconds: 1)),
      );

      // A duração não pula 300% devido ao filtro EMA
      final diff = (r2.remainingDurationSeconds - r1.remainingDurationSeconds).abs();
      expect(diff, lessThan(r1.remainingDurationSeconds * 0.3));
    });

    test('Reset limpa os dados de telemetria', () {
      service.reset();
      expect(service.lastResult, isNull);

      final emptyResult = service.update(
        position: points[0],
        speedMps: 10.0,
      );
      expect(emptyResult.remainingDistanceMeters, 0.0);
      expect(emptyResult.progressPercent, 1.0);
    });
  });
}
