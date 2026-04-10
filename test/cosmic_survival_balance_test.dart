import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cosmic survival balance', () {
    test('0-5 stat scale has strong separation for high-end alchemons', () {
      final average = CosmicSurvivalBalance.qualityScore(2.5);
      final elite = CosmicSurvivalBalance.qualityScore(4.3);

      expect(elite, greaterThan(average * 1.7));
    });

    test('average 2.0-3.0 solo alchemons land around wave 15', () {
      final lowAverage = CosmicSurvivalBalance.estimatedWaveReach(
        averageStat: 2.0,
      );
      final highAverage = CosmicSurvivalBalance.estimatedWaveReach(
        averageStat: 3.0,
      );

      expect(lowAverage, inInclusiveRange(9, 15));
      expect(highAverage, inInclusiveRange(16, 22));
    });

    test('3.5 solo alchemons land around wave 25-30', () {
      final wave = CosmicSurvivalBalance.estimatedWaveReach(averageStat: 3.5);

      expect(wave, inInclusiveRange(25, 30));
    });

    test('4.0 full squads can push to wave 50', () {
      final wave = CosmicSurvivalBalance.estimatedWaveReach(
        averageStat: 4.0,
        teamSize: 5,
        extraCompanionSlots: 0,
        perkLevels: 4,
      );

      expect(wave, greaterThanOrEqualTo(50));
      expect(wave, lessThanOrEqualTo(60));
    });

    test('enemy scaling stays gentle early and serious late', () {
      expect(
        CosmicSurvivalBalance.enemyWaveHpScale(15),
        inInclusiveRange(1.8, 2.3),
      );
      expect(
        CosmicSurvivalBalance.enemyWaveHpScale(50),
        inInclusiveRange(5.0, 6.2),
      );
      expect(CosmicSurvivalBalance.enemyWaveDamageScale(50), lessThan(2.0));
    });
  });
}
