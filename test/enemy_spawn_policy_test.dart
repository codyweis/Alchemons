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

  group('traits drive behaviour, not just the sigil', () {
    test('a summoner of ANY body can summon wisps', () {
      final spawner = CosmicSurvivalSpawner()..startFirstWave();
      // A summoner on a light body was impossible before: the roll was gated
      // on sentinel/phantom. Build one directly and confirm the spawner will
      // produce adds for it.
      final wispSummoner = CosmicSurvivalEnemy(
        position: Offset.zero,
        hp: 50,
        maxHp: 50,
        speed: 60,
        damage: 5,
        radius: 9,
        tier: EnemyTier.wisp,
        element: 'Fire',
        role: CosmicEnemyRole.striker,
        target: CosmicEnemyTarget.orb,
        conduct: EnemyConduct.charge,
        trait: EnemyTrait.summoner,
      );
      expect(wispSummoner.trait, EnemyTrait.summoner);
      expect(spawner.spawnSummonerWisps(wispSummoner), isNotEmpty);
    });

    test('a splitter of ANY body sheds shards', () {
      final spawner = CosmicSurvivalSpawner()..startFirstWave();
      final droneSplitter = CosmicSurvivalEnemy(
        position: Offset.zero,
        hp: 40,
        maxHp: 40,
        speed: 70,
        damage: 6,
        radius: 11,
        tier: EnemyTier.drone,
        element: 'Ice',
        role: CosmicEnemyRole.striker,
        target: CosmicEnemyTarget.orb,
        conduct: EnemyConduct.stalk,
        trait: EnemyTrait.splitter,
      );
      expect(spawner.spawnSplitterShards(droneSplitter), isNotEmpty);
    });

    test('conduct and trait survive the constructor unchanged', () {
      final e = CosmicSurvivalEnemy(
        position: Offset.zero,
        hp: 10,
        maxHp: 10,
        speed: 10,
        damage: 1,
        radius: 5,
        tier: EnemyTier.colossus,
        element: 'Dark',
        role: CosmicEnemyRole.shooter,
        target: CosmicEnemyTarget.orb,
        conduct: EnemyConduct.graze,
        trait: EnemyTrait.breaker,
      );
      // Explicit values must win over the legacy derivation.
      expect(e.conduct, EnemyConduct.graze);
      expect(e.trait, EnemyTrait.breaker);
    });
  });
}
