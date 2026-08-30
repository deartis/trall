import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trallzero/models/user_rank.dart';
import 'package:trallzero/services/user_score_service.dart';

void main() {
  group('UserRank Tests', () {
    test('Calcula patentes corretamente com base no XP', () {
      expect(UserRank.getRank(0).level, 1);
      expect(UserRank.getRank(0).title, 'Novato da Estrada');

      expect(UserRank.getRank(50).level, 1);
      expect(UserRank.getRank(51).level, 2);
      expect(UserRank.getRank(51).title, 'Chofer Parceiro');

      expect(UserRank.getRank(200).level, 2);
      expect(UserRank.getRank(201).level, 3);
      expect(UserRank.getRank(201).title, 'Rei da Pista');

      expect(UserRank.getRank(600).level, 3);
      expect(UserRank.getRank(601).level, 4);
      expect(UserRank.getRank(601).title, 'Mestre da Boleia');

      expect(UserRank.getRank(1500).level, 4);
      expect(UserRank.getRank(1501).level, 5);
      expect(UserRank.getRank(1501).title, 'Lenda da Rodovia');
      expect(UserRank.getRank(5000).level, 5);
    });

    test('Progresso percentual dentro do nível', () {
      final rank1 = UserRank.getRank(0);
      expect(rank1.getProgress(0), 0.0);
      // Nível 1 vai de 0 a 50 (51 pontos total). 25 pontos é aprox 0.49
      expect(rank1.getProgress(25), closeTo(0.49, 0.05));

      final rank5 = UserRank.getRank(2000);
      expect(rank5.getProgress(2000), 1.0); // Nível máximo sempre 100%
    });

    test('Cálculo de XP restante para o próximo nível', () {
      final rank1 = UserRank.getRank(40);
      expect(rank1.getRemainingXp(40), 11); // 51 - 40 = 11

      final rank5 = UserRank.getRank(3000);
      expect(rank5.getRemainingXp(3000), 0);
    });
  });

  group('UserScoreService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await UserScoreService.instance.init();
      await UserScoreService.instance.reset();
    });

    test('Pontuação inicial zerada', () {
      final service = UserScoreService.instance;
      expect(service.xp, 0);
      expect(service.reportsCount, 0);
      expect(service.confirmationsCount, 0);
      expect(service.correctionsCount, 0);
      expect(service.currentRank.level, 1);
    });

    test('Adicionar novo alerta concede 10 XP', () async {
      final service = UserScoreService.instance;
      final event = await service.addScoreForNewReport();

      expect(service.xp, 10);
      expect(service.reportsCount, 1);
      expect(event.points, 10);
      expect(event.leveledUp, false);
      expect(event.currentRank.level, 1);
    });

    test('Confirmar presença concede 5 XP', () async {
      final service = UserScoreService.instance;
      final event = await service.addScoreForConfirmation();

      expect(service.xp, 5);
      expect(service.confirmationsCount, 1);
      expect(event.points, 5);
      expect(event.leveledUp, false);
    });

    test('Corrigir alerta concede 15 XP', () async {
      final service = UserScoreService.instance;
      final event = await service.addScoreForCorrection();

      expect(service.xp, 15);
      expect(service.correctionsCount, 1);
      expect(event.points, 15);
      expect(event.leveledUp, false);
    });

    test('Subir de nível detecta leveledUp == true', () async {
      final service = UserScoreService.instance;
      // Começa no nível 1 (0-50 XP)
      await service.addScore(45, 'Ação 1');
      expect(service.currentRank.level, 1);

      // Adiciona mais 10 XP -> total 55 XP -> sobe para o Nível 2 (Chofer Parceiro)
      final event = await service.addScore(10, 'Ação 2');
      expect(service.xp, 55);
      expect(event.leveledUp, true);
      expect(event.currentRank.level, 2);
      expect(event.currentRank.title, 'Chofer Parceiro');
    });
  });
}
