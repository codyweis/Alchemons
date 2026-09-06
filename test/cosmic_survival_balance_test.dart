import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cosmic survival balance', () {
    test('legacy Power 20-100 keeps strong high-end separation', () {
      final average = CosmicSurvivalBalance.qualityScore(2.5);
      final elite = CosmicSurvivalBalance.qualityScore(4.3);

      expect(elite, greaterThan(average * 1.7));
    });

    test('Power above 100 helps without breaking the survival curve', () {
      final legacyPeak = CosmicSurvivalBalance.survivalStatPower(5.0);
      final absolutePeak = CosmicSurvivalBalance.survivalStatPower(9.0);

      expect(absolutePeak, greaterThan(legacyPeak));
      expect(absolutePeak, closeTo(legacyPeak * 1.30, 0.000001));
      expect(
        CosmicSurvivalBalance.estimatedWaveReach(averageStat: 9.0),
        greaterThan(CosmicSurvivalBalance.estimatedWaveReach(averageStat: 5.0)),
      );
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
        inInclusiveRange(1.7, 2.3),
      );
      expect(
        CosmicSurvivalBalance.enemyWaveHpScale(50),
        inInclusiveRange(3.9, 4.7),
      );
      // Damage now climbs alongside HP so late waves stay threatening
      // instead of becoming pure damage sponges, while still trailing
      // the HP curve so fights don't become lethal coin-flips.
      expect(
        CosmicSurvivalBalance.enemyWaveDamageScale(50),
        inInclusiveRange(2.5, 3.3),
      );
      expect(
        CosmicSurvivalBalance.enemyWaveDamageScale(50),
        lessThan(CosmicSurvivalBalance.enemyWaveHpScale(50)),
      );
    });

    test(
      'performance mode preserves authored companion projectile identity',
      () {
        final authored = Projectile(
          position: const Offset(0, 0),
          angle: 0,
          element: 'Poison',
          visualStyle: ProjectileVisualStyle.sigil,
          abilityFamily: 'mask',
        );
        final generic = Projectile(
          position: const Offset(0, 0),
          angle: 0,
          element: 'Poison',
        );

        expect(
          shouldUseReducedCompanionProjectileRendering(
            quality: SurvivalVisualQuality.performance,
            projectile: authored,
          ),
          isFalse,
        );
        expect(
          shouldUseReducedCompanionProjectileRendering(
            quality: SurvivalVisualQuality.performance,
            projectile: generic,
          ),
          isTrue,
        );
        expect(
          shouldUseReducedCompanionProjectileRendering(
            quality: SurvivalVisualQuality.balanced,
            projectile: generic,
          ),
          isFalse,
        );
      },
    );
  });
}
