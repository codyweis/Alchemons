import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cosmic survival balance', () {
    test('boss waves cannot award multiple full meters from boss deaths', () {
      for (var wave = 5; wave <= 100; wave += 5) {
        final reward =
            CosmicSurvivalBalance.bossAlchemyReward(wave) *
            CosmicSurvivalBalance.bossCountForWave(wave);
        final capacity = CosmicSurvivalBalance.alchemicalMeterCapacity(wave);
        expect(reward / capacity, inInclusiveRange(0.54, 0.71));
      }
    });

    test(
      'outbreaks and titans leave room for their environmental mechanics',
      () {
        for (final wave in [20, 25, 30, 40, 50]) {
          expect(CosmicSurvivalBalance.bossCountForWave(wave), 1);
        }
        for (final wave in [15, 35, 45]) {
          expect(CosmicSurvivalBalance.bossCountForWave(wave), 2);
        }
      },
    );

    test('meter retains early pacing and continues growing past wave 31', () {
      expect(CosmicSurvivalBalance.alchemicalMeterCapacity(1), 100);
      expect(CosmicSurvivalBalance.alchemicalMeterCapacity(11), 180);
      for (var wave = 31; wave < 100; wave++) {
        expect(
          CosmicSurvivalBalance.alchemicalMeterCapacity(wave + 1),
          greaterThan(CosmicSurvivalBalance.alchemicalMeterCapacity(wave)),
        );
      }
    });

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

    test('enemy health and damage climb together', () {
      // This used to require damage to TRAIL health — x2.96 against x5.65 at
      // wave 50 — on the reasoning that a damage curve meeting the health
      // curve would turn late fights into lethal coin-flips.
      //
      // Measured, that reasoning produced the opposite problem. A health curve
      // running at twice the damage curve is the shape of a game that gets
      // LONGER rather than harder: late waves were no more likely to kill you,
      // just slower to clear. A fight you cannot lose stops mattering however
      // big its numbers get. See test/survival_balance_audit_test.dart for the
      // run-level figures behind that.
      //
      // They rise together now — about x4 each at wave 50 — so a late enemy is
      // exactly as dangerous as it is tanky. Parity is not the coin-flip the
      // old note worried about: that would need damage to OUTRUN health, which
      // this still asserts it does not.
      expect(
        CosmicSurvivalBalance.enemyWaveHpScale(15),
        inInclusiveRange(1.5, 1.8),
      );
      expect(
        CosmicSurvivalBalance.enemyWaveHpScale(50),
        inInclusiveRange(3.8, 4.4),
      );
      expect(
        CosmicSurvivalBalance.enemyWaveDamageScale(50),
        inInclusiveRange(3.8, 4.4),
      );
      // Neither runs away from the other, in either direction.
      final hp = CosmicSurvivalBalance.enemyWaveHpScale(50);
      final dmg = CosmicSurvivalBalance.enemyWaveDamageScale(50);
      expect(
        (hp - dmg).abs() / hp,
        lessThan(0.15),
        reason: 'the two curves have drifted apart again',
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
