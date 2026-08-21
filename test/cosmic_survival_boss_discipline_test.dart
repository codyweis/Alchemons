import 'dart:math';

import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cosmic survival boss disciplines', () {
    test('milestone waves map to the intended boss disciplines', () {
      final spawner = CosmicSurvivalSpawner();

      final wave10 = spawner.createBossForWave(10, const Offset(0, 0));
      final wave15 = spawner.createBossForWave(15, const Offset(0, 0));
      final wave20 = spawner.createBossForWave(20, const Offset(0, 0));
      final wave25 = spawner.createBossForWave(25, const Offset(0, 0));

      expect(wave10, isNotNull);
      expect(wave15, isNotNull);
      expect(wave20, isNotNull);
      expect(wave25, isNotNull);

      expect(wave10!.discipline, SurvivalBossDiscipline.artillery);
      expect(wave15!.discipline, SurvivalBossDiscipline.trickster);
      expect(wave20!.discipline, SurvivalBossDiscipline.duelist);
      expect(wave25!.discipline, SurvivalBossDiscipline.conductor);
    });

    test('non-milestone boss waves stay on the standard discipline', () {
      final spawner = CosmicSurvivalSpawner();
      final wave5 = spawner.createBossForWave(5, const Offset(0, 0));

      expect(wave5, isNotNull);
      expect(wave5!.discipline, SurvivalBossDiscipline.standard);
    });

    test('survival boss roster avoids titanic bosses on normal waves', () {
      final spawner = CosmicSurvivalSpawner();

      for (final wave in [5, 10, 15, 20, 30, 35]) {
        final boss = spawner.createBossForWave(wave, const Offset(0, 0));
        expect(boss, isNotNull);
        expect(boss!.template.isTitanic, isFalse);
      }
    });

    test('forced titanic survival bosses use a reduced arena radius', () {
      final spawner = CosmicSurvivalSpawner();
      final boss = spawner.createBossForWave(25, const Offset(0, 0));

      expect(boss, isNotNull);
      expect(boss!.template.isTitanic, isTrue);
      expect(boss.radius, lessThan(boss.template.radius));
      expect(boss.radius, inInclusiveRange(84.0, 104.0));
    });

    test('survival boss templates do not repeat back to back', () {
      final spawner = CosmicSurvivalSpawner();
      final names = [
        spawner.createBossForWave(5, const Offset(0, 0))!.template.name,
        spawner.createBossForWave(10, const Offset(0, 0))!.template.name,
        spawner.createBossForWave(15, const Offset(0, 0))!.template.name,
        spawner.createBossForWave(20, const Offset(0, 0))!.template.name,
      ];

      for (var i = 1; i < names.length; i++) {
        expect(names[i], isNot(equals(names[i - 1])));
      }
    });

    test('boss add rosters reinforce each discipline identity', () {
      final spawner = CosmicSurvivalSpawner();
      final artillery = spawner.createBossForWave(10, const Offset(0, 0))!;
      final duelist = spawner.createBossForWave(20, const Offset(0, 0))!;
      final conductor = spawner.createBossForWave(25, const Offset(0, 0))!;
      final siegebreaker = spawner.createBossForWave(30, const Offset(0, 0))!;
      final riftcaller = spawner.createBossForWave(35, const Offset(0, 0))!;

      final artilleryAdds = spawner.spawnBossAdds(
        artillery,
        const Offset(0, 0),
        1280,
        720,
      );
      final duelistAdds = spawner.spawnBossAdds(
        duelist,
        const Offset(0, 0),
        1280,
        720,
      );
      final conductorAdds = spawner.spawnBossAdds(
        conductor,
        const Offset(0, 0),
        1280,
        720,
      );
      final siegebreakerAdds = spawner.spawnBossAdds(
        siegebreaker,
        const Offset(0, 0),
        1280,
        720,
      );
      final riftcallerAdds = spawner.spawnBossAdds(
        riftcaller,
        const Offset(0, 0),
        1280,
        720,
      );

      expect(
        artilleryAdds.any(
          (add) => add.variant == SurvivalEnemyVariant.siegeShooter,
        ),
        isTrue,
      );
      expect(
        duelistAdds.every((add) => add.variant == SurvivalEnemyVariant.pouncer),
        isTrue,
      );
      expect(
        conductorAdds.any(
          (add) => add.variant == SurvivalEnemyVariant.orbBreaker,
        ),
        isTrue,
      );
      expect(
        siegebreakerAdds.any(
          (add) => add.variant == SurvivalEnemyVariant.crusher,
        ),
        isTrue,
      );
      expect(
        riftcallerAdds.any(
          (add) => add.variant == SurvivalEnemyVariant.siegeShooter,
        ),
        isTrue,
      );
    });

    test('normal waves can advance after most enemies are defeated', () {
      final spawner = CosmicSurvivalSpawner()..startFirstWave();

      final spawned = <CosmicSurvivalEnemy>[];
      while (spawned.length < spawner.targetCountThisWave) {
        spawned.addAll(spawner.update(10, 0, 1280, 720, const Offset(0, 0)));
      }

      final requiredDefeats = max(
        1,
        (spawner.targetCountThisWave *
                CosmicSurvivalSpawner.earlyAdvanceKillThreshold)
            .round(),
      );
      final survivors = min(
        max(0, spawner.targetCountThisWave - requiredDefeats),
        max(
          3,
          (spawner.targetCountThisWave *
                  (1 - CosmicSurvivalSpawner.earlyAdvanceKillThreshold))
              .ceil(),
        ),
      );
      spawner.update(10, survivors, 1280, 720, const Offset(0, 0));
      spawner.checkWaveComplete(survivors);

      expect(spawner.intermission, isTrue);
    });

    test('early waves frontload more enemy bodies before midgame patterns', () {
      final spawner = CosmicSurvivalSpawner()..startFirstWave();

      final wave1Count = spawner.targetCountThisWave;
      spawner.resumeAfterIntermission();
      final wave2Count = spawner.targetCountThisWave;
      spawner.resumeAfterIntermission();
      final wave3Count = spawner.targetCountThisWave;

      expect(wave1Count, greaterThanOrEqualTo(8));
      expect(wave2Count, greaterThanOrEqualTo(10));
      expect(wave3Count, greaterThanOrEqualTo(13));
    });

    test('swarm rush joins the authored wave pattern pool', () {
      final seen = <SurvivalWavePattern>{};
      for (var wave = 1; wave <= 33; wave++) {
        final spawner = CosmicSurvivalSpawner();
        spawner.currentWave = wave - 1;
        spawner.resumeAfterIntermission();
        seen.add(spawner.currentPattern);
      }

      expect(seen, contains(SurvivalWavePattern.swarmRush));
    });

    test('elite affix pool expands with later waves', () {
      expect(CosmicSurvivalSpawner.eliteAffixPoolForWave(12), isEmpty);
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(14),
        contains(EliteAffix.bulwarked),
      );
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(24),
        contains(EliteAffix.volatile),
      );
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(30),
        contains(EliteAffix.vampiric),
      );
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(38),
        containsAll(EliteAffix.values),
      );
    });

    test('wave mutators only appear on eligible non-boss waves', () {
      expect(CosmicSurvivalSpawner.previewMutatorForWave(5), isNull);
      expect(CosmicSurvivalSpawner.previewMutatorForWave(6), isNull);
      expect(CosmicSurvivalSpawner.previewMutatorForWave(10), isNull);
      expect(
        CosmicSurvivalSpawner.previewMutatorForWave(7),
        SurvivalWaveMutator.orbSiege,
      );
      expect(CosmicSurvivalSpawner.previewMutatorForWave(11), isNotNull);
      expect(
        CosmicSurvivalSpawner.mutatorLabel(
          CosmicSurvivalSpawner.previewMutatorForWave(11),
        ),
        isNotEmpty,
      );
      expect(
        CosmicSurvivalSpawner.mutatorDescription(
          CosmicSurvivalSpawner.previewMutatorForWave(11),
        ),
        isNotEmpty,
      );
      expect(
        CosmicSurvivalSpawner.previewMutatorForWave(17),
        isNot(SurvivalWaveMutator.shatteredSpace),
      );
      expect(
        CosmicSurvivalSpawner.previewMutatorForWave(28),
        SurvivalWaveMutator.shatteredSpace,
      );
    });
  });
}
