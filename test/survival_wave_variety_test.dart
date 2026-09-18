import 'dart:math';

import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two runs should not be the same run. The rhythm of survival is authored —
/// boss waves on fives, hordes growing — but which modifier a wave carries,
/// which shape it arrives in, how many bodies it brings and which way the
/// escape gap faces are rolled, or every run is the one before it replayed.
void main() {
  /// Plays [waves] waves of a run and reports what each one was.
  List<String> schedule(int seed, {int waves = 24}) {
    final spawner = CosmicSurvivalSpawner(random: Random(seed));
    spawner.startFirstWave();
    final out = <String>[];
    for (var wave = 1; wave <= waves; wave++) {
      // Drain the wave so the next one can start.
      for (var i = 0; i < 4000; i++) {
        spawner.update(0.9, 0, 900, 1400, Offset.zero, arenaRadius: 1140);
        if (spawner.spawnedThisWave >= spawner.targetCountThisWave) break;
      }
      out.add(
        '${spawner.currentPattern.name}/${spawner.currentMutator?.name ?? "-"}/'
        '${spawner.targetCountThisWave}/${spawner.frontCount}',
      );
      spawner.checkWaveComplete(0, bossAlive: false);
      spawner.resumeAfterIntermission();
    }
    return out;
  }

  test('two runs play different waves', () {
    final a = schedule(1);
    final b = schedule(2);
    final c = schedule(3);
    expect(a, isNot(b));
    expect(b, isNot(c));
    // Not just one wave in twenty-four: a run should feel different most of
    // the way down.
    var differing = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) differing++;
    }
    expect(differing, greaterThan(a.length ~/ 3));
  });

  test('the same seed still replays exactly', () {
    expect(schedule(7), schedule(7));
  });

  test('what is authored stays authored', () {
    final spawner = CosmicSurvivalSpawner(random: Random(4));
    spawner.startFirstWave();
    for (var wave = 1; wave <= 40; wave++) {
      final boss = CosmicSurvivalSpawner.isBossWaveNumber(wave);
      expect(spawner.currentWave, wave);
      expect(spawner.isBossWave, boss);
      // Modifiers are earned, and boss waves carry their own mechanics.
      if (wave < 7 || boss) {
        expect(spawner.currentMutator, isNull, reason: 'wave $wave');
      }
      final mutator = spawner.currentMutator;
      if (mutator != null) {
        expect(
          wave,
          greaterThanOrEqualTo(
            CosmicSurvivalSpawner.kMutatorUnlockWave[mutator]!,
          ),
          reason: '$mutator arrived before it was unlocked',
        );
      }
      // Fronts stay readable: a couple of broad ones or a few tight ones.
      expect(spawner.frontCount, inInclusiveRange(2, 4));
      expect(spawner.frontBearing, inInclusiveRange(0.0, 2 * pi));
      for (var i = 0; i < 4000; i++) {
        spawner.update(0.9, 0, 900, 1400, Offset.zero, arenaRadius: 1140);
        if (spawner.spawnedThisWave >= spawner.targetCountThisWave) break;
      }
      spawner.checkWaveComplete(0, bossAlive: false);
      spawner.resumeAfterIntermission();
    }
  });

  test('a run does not repeat the same modifier back to back', () {
    for (final seed in [11, 12, 13]) {
      final spawner = CosmicSurvivalSpawner(random: Random(seed));
      spawner.startFirstWave();
      SurvivalWaveMutator? previous;
      for (var wave = 1; wave <= 40; wave++) {
        final mutator = spawner.currentMutator;
        if (mutator != null && previous != null) {
          expect(mutator, isNot(previous), reason: 'wave $wave repeated it');
        }
        if (mutator != null) previous = mutator;
        for (var i = 0; i < 4000; i++) {
          spawner.update(0.9, 0, 900, 1400, Offset.zero, arenaRadius: 1140);
          if (spawner.spawnedThisWave >= spawner.targetCountThisWave) break;
        }
        spawner.checkWaveComplete(0, bossAlive: false);
        spawner.resumeAfterIntermission();
      }
    }
  });
}
