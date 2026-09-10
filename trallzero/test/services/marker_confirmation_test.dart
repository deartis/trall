import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trallzero/controllers/truck_controller.dart';
import 'package:trallzero/models/marker_model.dart';
import 'package:trallzero/services/api_service.dart';
import 'package:trallzero/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TruckerMarker Model Tests', () {
    test('Serialização e deserialização com validatedUserIds', () {
      final marker = TruckerMarker(
        id: '123',
        position: const LatLng(-23.5505, -46.6333),
        type: MarkerType.police,
        description: 'Polícia Rodoviária',
        confirmations: 3,
        authorId: 42,
        authorName: 'Caminhoneiro Silva',
        validatedUserIds: [101, 102, 103],
      );

      final map = marker.toMap();
      expect(map['validatedUserIds'], [101, 102, 103]);

      final fromMap = TruckerMarker.fromMap(map);
      expect(fromMap.id, '123');
      expect(fromMap.authorId, 42);
      expect(fromMap.confirmations, 3);
      expect(fromMap.validatedUserIds, [101, 102, 103]);
    });
  });

  group('TruckController Marker Confirmation Rules', () {
    late TruckController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.instance.init();
      ApiService.instance.setUserId(99); // Usuário logado é o ID 99
      controller = TruckController();
    });

    test('Autor do alerta não pode confirmar o próprio alerta por ID de autor', () {
      final ownMarker = TruckerMarker(
        id: 'own_alert_1',
        position: const LatLng(-23.55, -46.63),
        type: MarkerType.danger,
        authorId: 99, // Mesmo ID do usuário atual
        confirmations: 1,
      );

      expect(controller.isMarkerAuthor(ownMarker), isTrue);
      expect(controller.canConfirmMarker(ownMarker), isFalse);
    });

    test('Autor de alerta criado localmente não pode confirmar o próprio alerta', () async {
      await controller.addMarker(
        const LatLng(-23.55, -46.63),
        MarkerType.weighStation,
        'Balança aberta',
      );

      final createdMarker = controller.customMarkers.first;
      expect(controller.isMarkerAuthor(createdMarker), isTrue);
      expect(controller.canConfirmMarker(createdMarker), isFalse);

      final confirmSuccess = await controller.confirmMarker(createdMarker.id);
      expect(confirmSuccess, isFalse);
      expect(createdMarker.confirmations, 1); // Não incrementa
    });

    test('Motorista confirma alerta de outro usuário na primeira vez e bloqueia na segunda', () async {
      // Alerta criado por outro usuário (ID 55)
      final otherUserMarker = TruckerMarker(
        id: 'other_alert_1',
        position: const LatLng(-23.55, -46.63),
        type: MarkerType.police,
        authorId: 55,
        confirmations: 2,
        validatedUserIds: [10, 20],
      );

      controller.customMarkers.add(otherUserMarker);

      // 1ª checagem: não é autor e ainda não confirmou
      expect(controller.isMarkerAuthor(otherUserMarker), isFalse);
      expect(controller.hasConfirmedMarker(otherUserMarker), isFalse);
      expect(controller.canConfirmMarker(otherUserMarker), isTrue);

      // 1ª confirmação: deve ter sucesso e incrementar
      final firstAttempt = await controller.confirmMarker('other_alert_1');
      expect(firstAttempt, isTrue);

      final updated = controller.customMarkers.firstWhere((m) => m.id == 'other_alert_1');
      expect(updated.confirmations, 3);
      expect(updated.validatedUserIds.contains(99), isTrue);

      // 2ª checagem: agora já confirmou
      expect(controller.hasConfirmedMarker(updated), isTrue);
      expect(controller.canConfirmMarker(updated), isFalse);

      // 2ª tentativa de confirmação: deve ser bloqueada
      final secondAttempt = await controller.confirmMarker('other_alert_1');
      expect(secondAttempt, isFalse);
      expect(updated.confirmations, 3); // Não incrementa novamente
    });

    test('Alerta que já veio da API com ID do usuário nas validações é considerado confirmado', () {
      final alreadyValidatedFromApi = TruckerMarker(
        id: 'api_alert_44',
        position: const LatLng(-23.55, -46.63),
        type: MarkerType.loading,
        authorId: 10,
        confirmations: 5,
        validatedUserIds: [10, 20, 99], // Contém o ID 99 (usuário atual)
      );

      expect(controller.isMarkerAuthor(alreadyValidatedFromApi), isFalse);
      expect(controller.hasConfirmedMarker(alreadyValidatedFromApi), isTrue);
      expect(controller.canConfirmMarker(alreadyValidatedFromApi), isFalse);
    });
  });
}
