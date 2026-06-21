enum TruckProfileType {
  lightTruck,
  truck,
  carreta,
  bitrem,
  rodotrem,
}

enum CargoType {
  general,
  dangerous,
  oversized,
  overweight,
}

class TruckProfile {
  final TruckProfileType type;
  final String label;
  final double maxWeightKg;
  final double maxHeightMeters;
  final int axles;
  final double lengthMeters;
  final CargoType cargoType;
  final double recommendedMaxSlope;

  const TruckProfile({
    required this.type,
    required this.label,
    required this.maxWeightKg,
    required this.maxHeightMeters,
    required this.axles,
    required this.lengthMeters,
    this.cargoType = CargoType.general,
    this.recommendedMaxSlope = 10.0,
  });
}

class TruckProfilePresets {
  static const lightTruck = TruckProfile(
    type: TruckProfileType.lightTruck,
    label: 'Caminhão leve',
    maxWeightKg: 12000,
    maxHeightMeters: 4.3,
    axles: 2,
    lengthMeters: 9.0,
    recommendedMaxSlope: 10.0,
  );

  static const truck = TruckProfile(
    type: TruckProfileType.truck,
    label: 'Truck',
    maxWeightKg: 18000,
    maxHeightMeters: 4.3,
    axles: 3,
    lengthMeters: 12.0,
    recommendedMaxSlope: 8.0,
  );

  static const carreta = TruckProfile(
    type: TruckProfileType.carreta,
    label: 'Carreta',
    maxWeightKg: 30000,
    maxHeightMeters: 4.3,
    axles: 5,
    lengthMeters: 18.0,
    recommendedMaxSlope: 7.5,
  );

  static const bitrem = TruckProfile(
    type: TruckProfileType.bitrem,
    label: 'Bitrem',
    maxWeightKg: 39000,
    maxHeightMeters: 4.3,
    axles: 9,
    lengthMeters: 22.0,
    recommendedMaxSlope: 7.0,
  );

  static const rodotrem = TruckProfile(
    type: TruckProfileType.rodotrem,
    label: 'Rodotrem',
    maxWeightKg: 50000,
    maxHeightMeters: 4.3,
    axles: 13,
    lengthMeters: 30.0,
    recommendedMaxSlope: 6.5,
  );

  static const all = [
    lightTruck,
    truck,
    carreta,
    bitrem,
    rodotrem,
  ];
}
