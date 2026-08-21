import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The §2.4 fix, asserted: traits are rolled independently of the body, so the
/// combination space is actually reachable.
///
/// Before this, summoner only ever appeared on sentinel/phantom and splitter
/// only on brute/colossus, because the spawner keyed the roll on the tier.
void main() {
  group('trait selection is body-independent', () {
    test('a spawner run produces traits across many different bodies', () {
      final spawner = CosmicSurvivalSpawner()..startFirstWave();
      final byTrait = <EnemyTrait, Set<EnemyTier>>{};

      // Drive far enough that every trait's wave gate is open.
      for (var wave = 1; wave <= 30; wave++) {
        for (var i = 0; i < 400; i++) {
          for (final e in spawner.update(1.0, 0, 800, 600, Offset.zero)) {
            final t = e.trait;
            if (t != null) {
              byTrait.putIfAbsent(t, () => <EnemyTier>{}).add(e.tier);
            }
          }
        }
        spawner.forceNextWaveForTest();
      }

      expect(byTrait.keys, isNotEmpty, reason: 'no traits rolled at all');
      for (final entry in byTrait.entries) {
        expect(
          entry.value.length,
          greaterThan(1),
          reason:
              '${entry.key.name} only ever appeared on ${entry.value} — that '
              'is the body-locked behaviour this replaced',
        );
      }
    });

    test('every spawned enemy has a conduct', () {
      final spawner = CosmicSurvivalSpawner()..startFirstWave();
      for (var wave = 1; wave <= 12; wave++) {
        for (var i = 0; i < 100; i++) {
          for (final e in spawner.update(1.0, 0, 800, 600, Offset.zero)) {
            expect(EnemyConduct.values, contains(e.conduct));
          }
        }
        spawner.forceNextWaveForTest();
      }
    });
  });
}
