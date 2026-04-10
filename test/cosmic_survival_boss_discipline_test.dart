import 'dart:math';

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

    test('elite affix pool expands with later waves', () {
      expect(CosmicSurvivalSpawner.eliteAffixPoolForWave(12), isEmpty);
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(14),
        contains(SurvivalEliteAffix.bulwarked),
      );
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(24),
        contains(SurvivalEliteAffix.volatile),
      );
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(30),
        contains(SurvivalEliteAffix.vampiric),
      );
      expect(
        CosmicSurvivalSpawner.eliteAffixPoolForWave(38),
        containsAll(SurvivalEliteAffix.values),
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
