import 'package:latlong2/latlong.dart';
import '../models/marker_model.dart';

/// Tipo de ação recomendada pelo algoritmo de deduplicação
enum DeduplicationAction {
  /// Nenhum marcador próximo na mesma direção — seguro para cadastrar novo alerta
  createNew,

  /// Marcador do MESMO tipo encontrado na mesma direção e raio — sugerir confirmação
  confirmExisting,

  /// Marcador de tipo DIFERENTE encontrado na mesma direção e raio — conflito/substituição
  conflictDifferentType,
}

/// Resultado da avaliação espacial e direcional
class DeduplicationResult {
  final DeduplicationAction action;
  final TruckerMarker? existingMarker;
  final double? distanceMeters;
  final double? headingDiffDegrees;
  final bool isSameDirection;

  const DeduplicationResult({
    required this.action,
    this.existingMarker,
    this.distanceMeters,
    this.headingDiffDegrees,
    this.isSameDirection = true,
  });

  bool get hasConflict => action == DeduplicationAction.conflictDifferentType;
  bool get canConfirm => action == DeduplicationAction.confirmExisting;
  bool get isNew => action == DeduplicationAction.createNew;
}

/// Serviço inteligente para cálculo de proximidade e prevenção de duplicações (padrão Waze)
class MarkerDeduplicationService {
  static const Distance _distanceCalculator = Distance();

  /// Raio padrão de tolerância para alertas rodoviários/urbanos (em metros)
  static const double defaultRadiusMeters = 80.0;

  /// Tolerância angular máxima para considerar o mesmo sentido de via (em graus)
  static const double defaultMaxHeadingDiffDegrees = 75.0;

  /// Calcula a menor diferença angular entre dois azimutes (0° a 180°)
  static double headingDifference(double h1, double h2) {
    final diff = (h1 - h2).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  /// Calcula a distância geodésica em metros entre duas coordenadas
  static double distanceBetween(LatLng p1, LatLng p2) {
    return _distanceCalculator.as(LengthUnit.Meter, p1, p2);
  }

  /// Avalia uma nova tentativa de marcação comparando com os marcadores existentes
  static DeduplicationResult evaluate({
    required LatLng point,
    required MarkerType proposedType,
    required List<TruckerMarker> existingMarkers,
    double? heading,
    double radiusMeters = defaultRadiusMeters,
    double maxHeadingDiff = defaultMaxHeadingDiffDegrees,
  }) {
    if (existingMarkers.isEmpty) {
      return const DeduplicationResult(action: DeduplicationAction.createNew);
    }

    TruckerMarker? nearestSameType;
    double minDistanceSameType = double.infinity;
    double? headingDiffSameType;

    TruckerMarker? nearestDifferentType;
    double minDistanceDifferentType = double.infinity;
    double? headingDiffDifferentType;

    for (final marker in existingMarkers) {
      final dist = distanceBetween(point, marker.position);
      if (dist > radiusMeters) continue;

      // Verificação de direção (sentido da via)
      bool sameDirection = true;
      double? angleDiff;
      if (heading != null && marker.heading != null) {
        angleDiff = headingDifference(heading, marker.heading!);
        // Se a diferença for maior que a tolerância (ex: ~180° pista contrária), ignorar
        if (angleDiff > maxHeadingDiff) {
          sameDirection = false;
        }
      }

      // Se estiver em sentido oposto em rodovia duplicada, não conflita nem deduplica
      if (!sameDirection) continue;

      if (marker.type == proposedType) {
        if (dist < minDistanceSameType) {
          minDistanceSameType = dist;
          nearestSameType = marker;
          headingDiffSameType = angleDiff;
        }
      } else {
        if (dist < minDistanceDifferentType) {
          minDistanceDifferentType = dist;
          nearestDifferentType = marker;
          headingDiffDifferentType = angleDiff;
        }
      }
    }

    // Prioridade 1: Mesmo tipo encontrado -> Sugerir confirmação (Upvote / "Ainda está lá?")
    if (nearestSameType != null) {
      return DeduplicationResult(
        action: DeduplicationAction.confirmExisting,
        existingMarker: nearestSameType,
        distanceMeters: minDistanceSameType,
        headingDiffDegrees: headingDiffSameType,
        isSameDirection: true,
      );
    }

    // Prioridade 2: Tipo diferente encontrado no mesmo local/sentido -> Conflito
    if (nearestDifferentType != null) {
      return DeduplicationResult(
        action: DeduplicationAction.conflictDifferentType,
        existingMarker: nearestDifferentType,
        distanceMeters: minDistanceDifferentType,
        headingDiffDegrees: headingDiffDifferentType,
        isSameDirection: true,
      );
    }

    return const DeduplicationResult(action: DeduplicationAction.createNew);
  }

  /// Formata a distância em metros para exibição amigável
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
