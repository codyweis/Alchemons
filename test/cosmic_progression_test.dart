import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the refresh path without loading rendering/audio assets.
class _LoadedGame extends CosmicGame {
  _LoadedGame()
    : super(world_: CosmicWorld.generate(seed: 7), onMeterChanged: () {});

  @override
  bool get isLoaded => true;
}

void main() {
  test('guardian milestones are bounded, with easier encounters retained', () {
    final rng = Random(42);
    for (final entry in {
      -1: 1,
      0: 1,
      1: 2,
      3: 2,
      4: 3,
      7: 3,
      8: 4,
      11: 4,
      12: 5,
      18: 5,
      999: 5,
    }.entries) {
      expect(CosmicBalance.spaceLevel(entry.key), entry.value);
      final levels = List.generate(
        200,
        (_) => CosmicBalance.rollSpaceLevel(entry.key, rng),
      );
      expect(
        levels,
        everyElement(inInclusiveRange(max(1, entry.value - 1), entry.value)),
      );
      expect(levels.toSet(), {max(1, entry.value - 1), entry.value});
    }
  });

  test('generated encounters respect campaign progress and rewards grow', () {
    final world = CosmicWorld.generate(seed: 7);
    for (final count in [0, 1, 4, 8, 12]) {
      final ceiling = CosmicBalance.spaceLevel(count);
      final whirls = GalaxyWhirl.generate(
        seed: 7,
        worldSize: world.worldSize,
        planets: world.planets,
        guardiansDefeated: count,
      );
      expect(
        whirls.map((w) => w.level),
        everyElement(inInclusiveRange(max(1, ceiling - 1), ceiling)),
      );
      final lair = BossLair.generate(
        rng: Random(7),
        worldSize: world.worldSize,
        planets: world.planets,
        whirls: whirls,
        guardiansDefeated: count,
      );
      expect(lair.level, inInclusiveRange(max(1, ceiling - 1), ceiling));
    }
    final easy = GalaxyWhirl(position: Offset.zero, element: 'Fire', level: 1);
    final hard = GalaxyWhirl(position: Offset.zero, element: 'Fire', level: 5);
    expect(hard.shardReward, greaterThan(easy.shardReward));
    expect(hard.particleReward, greaterThan(easy.particleReward));
    expect(hard.enemyHealthScale, closeTo(1.8, 0.001));
    expect(easy.hordeType, HordeType.skirmish);
    expect(hordeTypeForLevel(3), HordeType.siege);
    expect(hard.hordeType, HordeType.onslaught);
  });

  test(
    'progress refresh upgrades idle encounters and preserves active fights',
    () {
      final game = _LoadedGame();
      final waiting = BossLair.generate(
        rng: Random(7),
        worldSize: game.world_.worldSize,
        planets: game.world_.planets,
        whirls: [],
      );
      final fighting = BossLair(
        position: Offset.zero,
        template: waiting.template,
        level: 1,
        state: BossLairState.fighting,
      );
      final dormant = GalaxyWhirl(
        position: Offset.zero,
        element: 'Fire',
        level: 1,
      );
      final active = GalaxyWhirl(
        position: Offset.zero,
        element: 'Water',
        level: 1,
      );
      active.state = WhirlState.active;
      final oldType = active.hordeType;
      final oldReward = active.shardReward;
      game.bossLairs = [waiting, fighting];
      game.galaxyWhirls = [dormant, active];
      game.syncGuardianProgress(12);
      expect(waiting.level, inInclusiveRange(4, 5));
      expect(dormant.level, inInclusiveRange(4, 5));
      expect(dormant.hordeType, hordeTypeForLevel(dormant.level));
      expect(fighting.level, 1);
      expect(active.level, 1);
      expect(active.hordeType, oldType);
      expect(active.shardReward, oldReward);
      final levels = [waiting.level, dormant.level];
      game.syncGuardianProgress(12);
      game.syncGuardianProgress(13);
      expect([waiting.level, dormant.level], levels);
    },
  );

  test('progress can refresh before load and home protection wraps', () {
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 7),
      onMeterChanged: () {},
      guardiansDefeated: 4,
    );
    game.syncGuardianProgress(12);
    expect(game.guardiansDefeated, 12);
    expect(game.isHomeRecoveryArea(Offset.zero), isFalse);
    game.homePlanet = HomePlanet(position: const Offset(10, 10));
    expect(game.isHomeRecoveryArea(Offset.zero), isTrue);
    expect(
      game.isHomeRecoveryArea(Offset(game.world_.worldSize.width - 10, 10)),
      isTrue,
    );
    expect(game.isHomeRecoveryArea(const Offset(5000, 5000)), isFalse);
  });

  test('ambient heavy enemies unlock gradually', () {
    expect(
      CosmicBalance.spaceEnemyTier(EnemyTier.colossus, 0),
      EnemyTier.sentinel,
    );
    expect(CosmicBalance.spaceEnemyTier(EnemyTier.phantom, 0), EnemyTier.wisp);
    expect(
      CosmicBalance.spaceEnemyTier(EnemyTier.phantom, 1),
      EnemyTier.phantom,
    );
    expect(
      CosmicBalance.spaceEnemyTier(EnemyTier.colossus, 4),
      EnemyTier.brute,
    );
    expect(
      CosmicBalance.spaceEnemyTier(EnemyTier.colossus, 12),
      EnemyTier.colossus,
    );
  });
}
