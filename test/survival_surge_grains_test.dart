// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/surge_grains.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// A kill pays the surge through grains: they wait where the body fell until
/// the ship pulls them in, the core's field drinks them, or the wave is
/// cleared; Surge Magnet widens the pull and at its top level sends them to
/// the core by themselves.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member() => CosmicPartyMember(
    instanceId: 'pip-0',
    baseId: 'PIP01',
    displayName: 'Pip',
    family: 'Pip',
    element: 'Fire',
    level: 10,
    slotIndex: 0,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    staminaBars: 3,
    staminaMax: 3,
  );

  CosmicSurvivalEnemy body(Offset at) => CosmicSurvivalEnemy(
    position: at,
    hp: 10,
    maxHp: 10,
    speed: 0,
    damage: 0,
    radius: 10,
    tier: EnemyTier.drone,
    element: 'Earth',
    conduct: EnemyConduct.charge,
    target: CosmicEnemyTarget.orb,
    retargetTimer: 0,
  );

  Future<CosmicSurvivalGame> arena() async {
    final game = CosmicSurvivalGame(
      party: [member()],
      onGameOver: () {},
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.enemies.clear();
    return game;
  }

  /// Runs the field with no spawns, the ship held where it is put.
  void run(CosmicSurvivalGame game, double seconds, {Offset? shipAt}) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.enemies.removeWhere((e) => !e.isDead && e.hp > 1e8);
      if (shipAt != null) game.ship.position = shipAt;
      game.showingPowerUpSelection = false;
      game.update(1 / 60);
    }
  }

  test('a kill far from the ship pays nothing until its grains are taken', () async {
    final game = await arena();
    final far = game.orb.position + const Offset(600, 0);
    final away = game.orb.position + const Offset(-600, 0);
    final before = game.alchemicalMeter;
    final e = body(far);
    game.enemies.add(e);
    game.debugKillEnemy(e);
    expect(game.alchemicalMeter, before);
    expect(game.debugSurgeOut, greaterThan(0));

    run(game, 2, shipAt: away);
    expect(game.debugSurgeOut, greaterThan(0), reason: 'out of reach');
    expect(game.alchemicalMeter, closeTo(before, 1e-9));

    run(game, 2, shipAt: far);
    expect(game.debugSurgeOut, closeTo(0, 1e-9));
    expect(game.alchemicalMeter, greaterThan(before));
    final grains = game.debugSurgeGrains;
    expect(grains.takenValue, closeTo(grains.spawnedValue, 1e-9));
  });

  test('the core drinks grains that fall inside its field', () async {
    final game = await arena();
    final near = game.orb.position + const Offset(120, 0);
    final e = body(near);
    game.enemies.add(e);
    game.debugKillEnemy(e);
    final before = game.alchemicalMeter;
    run(game, 2, shipAt: game.orb.position + const Offset(-600, 0));
    expect(game.debugSurgeOut, closeTo(0, 1e-9));
    expect(game.alchemicalMeter, greaterThan(before));
  });

  test('Surge Magnet widens the pull, and its top level sends a cleared wave\u2019s grains home', () async {
    final magnet = kAllPowerUps.firstWhere((d) => d.id == 'surge_magnet');
    expect(magnet.maxStacks, kSurgeMagnetMaxLevel);

    // 200 from the ship: out of the base reach, inside level 1's.
    for (final (level, taken) in [(0, false), (1, true)]) {
      final game = await arena();
      for (var i = 0; i < level; i++) {
        game.applyPowerUp(magnet);
      }
      final shipAt = game.orb.position + const Offset(0, -600);
      final e = body(shipAt + const Offset(200, 0));
      game.enemies.add(e);
      game.debugKillEnemy(e);
      run(game, 3, shipAt: shipAt);
      expect(game.debugSurgeOut < 1e-9, taken, reason: 'level $level');
    }

    // Below the top level a cleared wave leaves the grains out for the
    // ship; at the top level they flow home.
    for (final (level, home) in [
      (kSurgeMagnetMaxLevel - 1, false),
      (kSurgeMagnetMaxLevel, true),
    ]) {
      final game = await arena();
      for (var i = 0; i < level; i++) {
        game.applyPowerUp(magnet);
      }
      final away = game.orb.position + const Offset(-700, 0);
      final e = body(game.orb.position + const Offset(700, 0));
      game.enemies.add(e);
      game.debugKillEnemy(e);
      // Mid-wave, nothing goes home by itself at any level.
      run(game, 3, shipAt: away);
      expect(game.debugSurgeOut, greaterThan(0), reason: 'level $level');
      game.debugEndWaveGrains();
      run(game, 5, shipAt: away);
      expect(
        game.debugSurgeOut < 1e-9,
        home,
        reason: 'level $level after the wave',
      );
    }
  });

  test('Autopilot flies a let-go ship out for grains, and steering keeps it', () async {
    final autopilot = kAllPowerUps.firstWhere((d) => d.id == 'autopilot');
    expect(autopilot.maxStacks, 1);
    // 500 out: past the core's field and the idle orbit's pull.
    for (final (pick, steer, taken) in [
      (false, false, false),
      (true, false, true),
      (true, true, false),
    ]) {
      final game = await arena();
      if (pick) game.applyPowerUp(autopilot);
      final spot = game.orb.position + const Offset(500, 0);
      final e = body(spot);
      game.enemies.add(e);
      game.debugKillEnemy(e);
      game.setJoystickInput(steer ? const Offset(-1, 0) : Offset.zero);
      run(game, 6);
      final label = 'autopilot $pick, steering $steer';
      expect(game.debugSurgeOut < 1e-9, taken, reason: label);
      if (pick && !steer) {
        run(game, 6);
        expect(
          (game.ship.position - game.orb.position).distance,
          lessThan(400),
          reason: 'with nothing left out it comes home to its orbit',
        );
      }
    }
  });

  test('a full field keeps every kill’s value', () {
    final grains = SurgeGrains(random: Random(1));
    for (var i = 0; i < SurgeGrains.cap + 200; i++) {
      grains.spawn(Offset(i.toDouble(), 0), 1, 1);
    }
    expect(grains.length, SurgeGrains.cap);
    expect(grains.valueOut, closeTo(SurgeGrains.cap + 200.0, 1e-6));
  });

  test('a companion in constant contact flashes at most every half second', () {
    final comp = CosmicSurvivalCompanion(
      member: member(),
      slotIndex: 0,
      position: Offset.zero,
      anchor: Offset.zero,
      maxHp: 100,
      currentHp: 100,
      physAtk: 1,
      elemAtk: 1,
      abilityAtk: 1,
      physDef: 1,
      elemDef: 1,
      cooldownReduction: 0,
      specialCooldownReduction: 0,
      attackRange: 100,
      specialAbilityRange: 100,
    );
    var flashes = 0;
    var lit = 0;
    var last = 0.0;
    for (var f = 0; f < 120; f++) {
      comp.hitFlash = 1.0; // hit every frame, for two seconds
      comp.tickFlash(1 / 60);
      if (comp.shownFlash > last + 0.5) flashes++;
      if (comp.shownFlash > 0.05) lit++;
      last = comp.shownFlash;
    }
    expect(flashes, inInclusiveRange(4, 5));
    expect(lit, lessThan(120 * 0.4), reason: 'mostly its own colours');
  });

  test('a wave\u2019s drones share one form, and a run meets all three', () {
    final spawner = CosmicSurvivalSpawner(random: Random(8));
    spawner.startFirstWave();
    final seen = <int>{};
    for (var w = 0; w < 24; w++) {
      spawner.forceNextWaveForTest();
      if (spawner.isBossWave) continue;
      final drones = <CosmicSurvivalEnemy>[];
      for (var i = 0; i < 200 && drones.length < 12; i++) {
        drones.addAll(
          spawner
              .update(0.25, 0, 900, 700, Offset.zero)
              .where((e) => e.tier == EnemyTier.drone),
        );
      }
      if (drones.isEmpty) continue;
      expect(
        drones.map((e) => e.droneForm).toSet(),
        {spawner.waveDroneForm},
        reason: 'wave ${spawner.currentWave}',
      );
      seen.add(spawner.waveDroneForm);
    }
    expect(seen, {0, 1, 2});
  });

  test('each wave arrives in the element named as next the wave before', () {
    final spawner = CosmicSurvivalSpawner(random: Random(3));
    spawner.startFirstWave();
    for (var w = 0; w < 30; w++) {
      final promised = spawner.nextWaveElement;
      expect(promised, isNot(spawner.waveElement));
      spawner.forceNextWaveForTest();
      expect(spawner.waveElement, promised, reason: 'wave ${spawner.currentWave}');
    }
  });

  test('a wave’s small bodies share one element; elites keep their own', () {
    final spawner = CosmicSurvivalSpawner(random: Random(11));
    spawner.startFirstWave();
    for (var w = 1; w < 24; w++) {
      spawner.forceNextWaveForTest();
    }
    final seen = <CosmicSurvivalEnemy>[];
    for (var i = 0; i < 400 && seen.length < 150; i++) {
      seen.addAll(spawner.update(0.25, 0, 900, 700, Offset.zero));
    }
    final small = seen.where(
      (e) =>
          !e.isElite &&
          (e.tier == EnemyTier.wisp ||
              e.tier == EnemyTier.drone ||
              e.tier == EnemyTier.sentinel ||
              e.tier == EnemyTier.phantom),
    );
    expect(small, isNotEmpty);
    expect(small.map((e) => e.element).toSet(), {spawner.waveElement});
  });
}
