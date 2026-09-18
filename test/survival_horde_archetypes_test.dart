import 'dart:math';

import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two things a front needs that chaff cannot do: shell the orb from
/// outside anyone's reach, and keep replacing itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CosmicSurvivalGame> gameAtWave(int wave) async {
    final game = CosmicSurvivalGame(
      party: const [],
      random: Random(9),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.spawner.currentWave = wave - 1;
    game.spawner.resumeAfterIntermission();
    game.spawner.isBossWave = false;
    return game;
  }

  void run(CosmicSurvivalGame game, int frames) {
    for (var i = 0; i < frames; i++) {
      game.alchemicalMeter = 0;
      game.showingPowerUpSelection = false;
      game.gamePaused = false;
      game.orb.currentHp = game.orb.maxHp;
      game.ship.currentHp = game.ship.maxHp.toDouble();
      game.spawner.isBossWave = false;
      game.update(1 / 60);
    }
  }

  test('a wave fields artillery and broodmothers once they are due', () async {
    expect(CosmicSurvivalBalance.artilleryCountForWave(4), 0);
    expect(CosmicSurvivalBalance.broodCountForWave(6), 0);
    expect(CosmicSurvivalBalance.artilleryCountForWave(12), greaterThan(0));

    final game = await gameAtWave(14);
    run(game, 60 * 25);
    final artillery = game.enemies
        .where((e) => e.conduct == EnemyConduct.siege)
        .toList();
    final brood = game.enemies
        .where((e) => e.trait == EnemyTrait.summoner)
        .toList();
    expect(artillery, isNotEmpty, reason: 'nothing shells the orb');
    expect(brood, isNotEmpty, reason: 'nothing replaces the front');
    // Both are a minority of the wave: the horde is still the horde.
    expect(artillery.length + brood.length, lessThan(game.enemies.length ~/ 4));
    game.onRemove();
  });

  test('artillery parks past companion reach and shells the orb', () async {
    final game = await gameAtWave(14);
    // A companion parked on the ship cannot answer these: the hold distance
    // is the archetype.
    expect(kSiegeHoldRange, greaterThan(600));

    // Shells are in flight only part of the time, so watch across the run.
    var shellsSeen = 0;
    var shellsAtOrb = 0;
    for (var i = 0; i < 60 * 45; i++) {
      run(game, 1);
      for (final p in game.enemyProjectiles) {
        if (p.radius <= 6) continue;
        shellsSeen++;
        if (p.target == CosmicEnemyTarget.orb) shellsAtOrb++;
      }
    }
    final artillery = game.enemies
        .where((e) => e.conduct == EnemyConduct.siege && !e.isDead)
        .toList();
    expect(artillery, isNotEmpty);
    final parked = artillery.where(
      (e) =>
          ((e.position - game.orb.position).distance - kSiegeHoldRange).abs() <
          160,
    );
    expect(
      parked,
      isNotEmpty,
      reason: 'artillery walked in instead of holding its range',
    );
    expect(shellsSeen, greaterThan(0), reason: 'artillery never fired');
    // A siege weapon shoots at the thing it is besieging.
    expect(shellsAtOrb, shellsSeen);
    game.onRemove();
  });

  test('a broodmother keeps feeding the front until it dies', () async {
    final game = await gameAtWave(14);
    run(game, 60 * 20);
    final mother = game.enemies.firstWhere(
      (e) => e.trait == EnemyTrait.summoner && !e.isDead,
    );
    // A field at its cap silences every brood, so make room first.
    for (final e in game.enemies.toList()) {
      if (identical(e, mother)) continue;
      // ignore: invalid_use_of_visible_for_testing_member
      game.debugKillEnemy(e);
    }
    final known = Set<CosmicSurvivalEnemy>.identity()..addAll(game.enemies);
    run(game, (CosmicSurvivalBalance.broodInterval * 2.2 * 60).round());
    // Wave spawns arrive at the rim; a brood's children arrive on top of it.
    final children = game.enemies
        .where(
          (e) =>
              !known.contains(e) &&
              (e.position - mother.position).distance < 220,
        )
        .toList();
    expect(
      children.length,
      greaterThanOrEqualTo(CosmicSurvivalBalance.broodBurst),
      reason: 'the brood produced nothing',
    );
    // It is a wall, not chaff.
    expect(mother.maxHp, greaterThan(400));
    // ignore: invalid_use_of_visible_for_testing_member
    game.debugKillEnemy(mother);
    expect(mother.isDead, isTrue);
    game.onRemove();
  });
}
