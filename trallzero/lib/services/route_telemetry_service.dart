import 'package:latlong2/latlong.dart';

/// Amostra de velocidade capturada da telemetria GPS
class SpeedSample {
  final DateTime timestamp;
  final double speedMps; // Metros por segundo

  const SpeedSample(this.timestamp, this.speedMps);
}

/// Resultado da avaliação de telemetria da rota
class RouteTelemetryResult {
  /// Distância restante até o destino final em metros
  final double remainingDistanceMeters;

  /// Duração restante estimada em segundos
  final double remainingDurationSeconds;

  /// Velocidade média de deslocamento recente em km/h
  final double averageSpeedKmh;

  /// Progresso na rota de 0.0 (início) a 1.0 (destino)
  final double progressPercent;

  /// Horário previsto de chegada (ETA)
  final DateTime estimatedArrival;

  const RouteTelemetryResult({
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.averageSpeedKmh,
    required this.progressPercent,
    required this.estimatedArrival,
  });
}

/// Motor de telemetria de navegação em tempo real
class RouteTelemetryService {
  static final RouteTelemetryService instance = RouteTelemetryService._internal();
  RouteTelemetryService._internal();

  List<LatLng> _points = [];
  double _totalDistance = 0.0;
  double _nominalDuration = 0.0;

  /// Distâncias cumulativas pré-calculadas a partir de cada vértice [i] até o fim
  List<double> _cumulativeDistancesFrom = [];

  /// Histórico recente de velocidades em janela deslizante (últimos 90s)
  final List<SpeedSample> _speedSamples = [];

  /// Duração suavizada por filtro EMA (Exponential Moving Average)
  double? _smoothedRemainingDuration;

  /// Último resultado de telemetria computado
  RouteTelemetryResult? _lastResult;

  static const Distance _distanceCalculator = Distance();
  static const int _sampleWindowSeconds = 90;
  static const double _minMovingSpeedMps = 1.39; // ~5 km/h (filtra paradas em semáforos/pedágios)
  static const double _emaAlpha = 0.20; // Fator de suavização do ETA (20% novo, 80% histórico)

  /// Inicializa a rota ativa e pré-calcula a malha cumulativa de distâncias em O(N)
  void initRoute({
    required List<LatLng> points,
    required double totalDistance,
    required double totalDuration,
  }) {
    _points = points;
    _totalDistance = totalDistance > 0 ? totalDistance : 0.0;
    _nominalDuration = totalDuration > 0 ? totalDuration : 0.0;
    _speedSamples.clear();
    _smoothedRemainingDuration = null;
    _lastResult = null;

    if (_points.length < 2) {
      _cumulativeDistancesFrom = [_totalDistance];
      return;
    }

    _cumulativeDistancesFrom = List<double>.filled(_points.length, 0.0);
    double accum = 0.0;
    for (int i = _points.length - 2; i >= 0; i--) {
      final segDist = _distanceCalculator.as(
        LengthUnit.Meter,
        _points[i],
        _points[i + 1],
      );
      accum += segDist;
      _cumulativeDistancesFrom[i] = accum;
    }
    _cumulativeDistancesFrom[_points.length - 1] = 0.0;
  }

  /// Reseta todos os dados de telemetria
  void reset() {
    _points = [];
    _totalDistance = 0.0;
    _nominalDuration = 0.0;
    _cumulativeDistancesFrom = [];
    _speedSamples.clear();
    _smoothedRemainingDuration = null;
    _lastResult = null;
  }

  /// Atualiza a telemetria com a posição do veículo e velocidade instantânea (em m/s)
  RouteTelemetryResult update({
    required LatLng position,
    required double speedMps,
    int? segmentIndex,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    // 1. Registro na janela deslizante de velocidade
    final validSpeed = (speedMps.isNaN || speedMps < 0) ? 0.0 : speedMps;
    _speedSamples.add(SpeedSample(now, validSpeed));
    _speedSamples.removeWhere(
      (s) => now.difference(s.timestamp).inSeconds > _sampleWindowSeconds,
    );

    if (_points.isEmpty || _cumulativeDistancesFrom.isEmpty) {
      return RouteTelemetryResult(
        remainingDistanceMeters: 0,
        remainingDurationSeconds: 0,
        averageSpeedKmh: validSpeed * 3.6,
        progressPercent: 1.0,
        estimatedArrival: now,
      );
    }

    // 2. Localiza o segmento na rota se não tiver sido fornecido
    int segIdx = segmentIndex ?? _findClosestSegmentIndex(position);
    segIdx = segIdx.clamp(0, _points.length - 2);

    // 3. Distância do ponto atual até o próximo vértice + distâncias cumulativas posteriores
    final nextVertex = _points[segIdx + 1];
    final distToNextVertex = _distanceCalculator.as(
      LengthUnit.Meter,
      position,
      nextVertex,
    );
    final distAfterNextVertex = (segIdx + 1 < _cumulativeDistancesFrom.length)
        ? _cumulativeDistancesFrom[segIdx + 1]
        : 0.0;

    double remainingDistance = distToNextVertex + distAfterNextVertex;
    if (_totalDistance > 0) {
      remainingDistance = remainingDistance.clamp(0.0, _totalDistance);
    }

    // 4. Progresso na rota (0.0 a 1.0)
    final progress = (_totalDistance > 0)
        ? ((_totalDistance - remainingDistance) / _totalDistance).clamp(0.0, 1.0)
        : 0.0;

    // 5. Média móvel de velocidade de deslocamento ativo (> 5 km/h)
    final movingSamples = _speedSamples
        .where((s) => s.speedMps >= _minMovingSpeedMps)
        .toList();

    double avgMovingSpeedMps = 0.0;
    if (movingSamples.isNotEmpty) {
      final sum = movingSamples.fold<double>(
        0.0,
        (acc, item) => acc + item.speedMps,
      );
      avgMovingSpeedMps = sum / movingSamples.length;
    }

    // 6. Cálculo da duração restante combinando velocidade nominal da via e telemetria real
    final double baseNominalSpeed = (_totalDistance > 0 && _nominalDuration > 0)
        ? (_totalDistance / _nominalDuration)
        : 16.67; // ~60 km/h default

    // Duração puramente nominal dos metros restantes
    final double nominalRemainingDuration = remainingDistance / baseNominalSpeed;

    double targetDuration = nominalRemainingDuration;

    // Se temos histórico em movimento representativo (ao menos 3 amostras)
    if (movingSamples.length >= 3 && avgMovingSpeedMps > _minMovingSpeedMps) {
      // Fator de ritmo do caminhão (ex: 0.7 = 30% mais lento que o nominal)
      final paceFactor = (avgMovingSpeedMps / baseNominalSpeed).clamp(0.40, 1.60);

      // Ponderação: os próximos 15 km sofrem maior influência do ritmo atual do caminhão
      const double nearHorizonMeters = 15000.0;
      final double nearWeight = (remainingDistance <= nearHorizonMeters)
          ? 0.70
          : (nearHorizonMeters / remainingDistance).clamp(0.20, 0.70);

      final adjustedPace = (paceFactor * nearWeight) + (1.0 * (1.0 - nearWeight));
      targetDuration = nominalRemainingDuration / adjustedPace;
    }

    // 7. Filtro EMA (Exponential Moving Average) para evitar oscilações no relógio
    if (_smoothedRemainingDuration == null) {
      _smoothedRemainingDuration = targetDuration;
    } else {
      _smoothedRemainingDuration = (_emaAlpha * targetDuration) +
          ((1.0 - _emaAlpha) * _smoothedRemainingDuration!);
    }

    // Se a distância for praticamente zero, zera a duração
    if (remainingDistance < 15.0) {
      _smoothedRemainingDuration = 0.0;
    }

    final finalDuration = (_smoothedRemainingDuration ?? targetDuration).clamp(0.0, double.infinity);
    final arrivalTime = now.add(Duration(seconds: finalDuration.round()));

    final result = RouteTelemetryResult(
      remainingDistanceMeters: remainingDistance,
      remainingDurationSeconds: finalDuration,
      averageSpeedKmh: (avgMovingSpeedMps > 0 ? avgMovingSpeedMps : validSpeed) * 3.6,
      progressPercent: progress,
      estimatedArrival: arrivalTime,
    );

    _lastResult = result;
    return result;
  }

  /// Busca do índice do segmento mais próximo
  int _findClosestSegmentIndex(LatLng pos) {
    if (_points.length < 2) return 0;
    int bestIdx = 0;
    double bestDist = double.infinity;

    for (int i = 0; i < _points.length - 1; i++) {
      final a = _points[i];
      final b = _points[i + 1];
      final dist = _distanceCalculator.as(LengthUnit.Meter, pos, a) +
          _distanceCalculator.as(LengthUnit.Meter, pos, b);
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  RouteTelemetryResult? get lastResult => _lastResult;
}
