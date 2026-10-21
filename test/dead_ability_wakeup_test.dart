import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/mask_trap_placement.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abilities that did nothing in most survival waves, woken without changing
/// what they are (2026-10-20 audit; user, the same day: "everything can have a
/// niche"):
///
///  * A Mystic's wait counted its SPECIAL from 0 to 36, and every Mystic is
///    past 36 at Potential 0, so all of them waited 60 s and the per-element
///    gap table did nothing. Brought back to life, it left low-bred Mystics
///    waiting up to 140 s, too late to matter; the user made it a flat
///    minute for every Mystic (2026-10-21).
///  * The Lava world's cracks broke for a boss only: nothing on four waves in
///    five.
///  * The Dust world's haze choked shooters only, and a horde body never
///    shoots.
///  * The Crystal world's shards paid alchemical meter only.
///  * A Light Mask threw one void a cast: one kill every half minute.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Mystic cadence ──────────────────────────────────────────────────────

  /// Magmara's (the Lava Mystic's) stats at a breeding, level 10.
  CosmicPartyMember bred(String element, int potential, {int enh = 0}) {
    double stat(int base) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base,
      level: 10,
      potential: potential,
      enhancementRank: enh,
    );
    return CosmicPartyMember(
      instanceId: 'm-$element-$potential-$enh',
      baseId: 'MYS06',
      displayName: '$element Mystic',
      family: 'Mystic',
      element: element,
      level: 10,
      slotIndex: 0,
      statSpeed: stat(69),
      statIntelligence: stat(80),
      statStrength: stat(82),
      statBeauty: stat(84),
      statSpeedPotential: potential.toDouble(),
      statIntelligencePotential: potential.toDouble(),
      statStrengthPotential: potential.toDouble(),
      statBeautyPotential: potential.toDouble(),
      staminaBars: 3,
      staminaMax: 3,
    );
  }

  double wait(String element, int potential, {int enh = 0}) {
    final s = deriveAlchemonCombatStats(
      member: bred(element, potential, enh: enh),
    );
    return alchemonSpecialInterval(
      family: 'Mystic',
      element: element,
      specialCooldownReduction: s.specialCooldownReduction,
      abilityAtk: s.abilityAtk,
    );
  }

  group('Mystic cadence', () {
    test('every Mystic waits a flat minute, whatever its element or breeding', () {
      // User, 2026-10-21: "maybe we just make it a flat 60 seconds for all
      // mystics".
      for (final element in ['Air', 'Water', 'Steam', 'Fire', 'Lava', 'Dark']) {
        for (final (p, e) in [(0, 0), (20, 0), (50, 0), (80, 0), (100, 10)]) {
          expect(
            wait(element, p, enh: e),
            kMysticWorldWait,
            reason: '$element at P$p E$e',
          );
        }
      }
    });

    test('a deployed Mystic waits that minute for its world', () async {
      final game = CosmicSurvivalGame(
        party: [bred('Dark', 0)],
        random: Random(3),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      final comp = game.activeCompanions[0]!;
      expect(comp.specialCooldown, closeTo(kMysticWorldWait, 1e-6));
    });
  });

  // ── The worlds ──────────────────────────────────────────────────────────

  CosmicPartyMember mystic(String element) => CosmicPartyMember(
    instanceId: 'w-$element',
    baseId: 'MYW01',
    displayName: '$element Mystic',
    family: 'Mystic',
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    statSpeedPotential: 80,
    statIntelligencePotential: 80,
    statStrengthPotential: 80,
    statBeautyPotential: 80,
    staminaBars: 3,
    staminaMax: 3,
  );

  void keepAlive(CosmicSurvivalGame game) {
    game.orb.currentHp = game.orb.maxHp;
    game.ship.currentHp = game.ship.maxHp;
    final comp = game.activeCompanions[0];
    if (comp != null) comp.currentHp = comp.maxHp;
    if (game.showingPowerUpSelection) {
      game.alchemicalMeter = 0;
      game.dismissPowerUpSelection();
    }
  }

  void run(CosmicSurvivalGame game, int frames) {
    for (var f = 0; f < frames; f++) {
      keepAlive(game);
      game.update(1 / 60);
    }
  }

  /// A world of [element], lit.
  Future<CosmicSurvivalGame> lit(String element) async {
    final game = CosmicSurvivalGame(
      party: [mystic(element)],
      random: Random(5),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    for (
      var i = 0;
      i < 1200 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      keepAlive(game);
      game.update(1 / 60);
    }
    final comp = game.activeCompanions[0]!;
    final target = game.enemies.firstWhere((e) => !e.isDead);
    comp.specialCooldown = 0;
    for (var f = 0; f < 1200 && !game.isMysticFieldSpent(0); f++) {
      target
        ..isDead = false
        ..hp = 1e9
        ..position = comp.position + const Offset(70, 0);
      keepAlive(game);
      game.update(1 / 60);
    }
    expect(game.isMysticFieldSpent(0), isTrue, reason: 'the world never lit');
    return game;
  }

  CosmicSurvivalEnemy body(
    Offset at, {
    EnemyTier tier = EnemyTier.wisp,
    bool elite = false,
    double hp = 1e9,
    double speed = 0,
    EnemyConduct conduct = EnemyConduct.charge,
  }) => CosmicSurvivalEnemy(
    position: at,
    hp: hp,
    maxHp: hp,
    speed: speed,
    damage: 0,
    radius: tierRadius(tier) * (elite ? 1.3 : 1.0),
    tier: tier,
    element: 'Fire',
    conduct: conduct,
    target: CosmicEnemyTarget.orb,
    isElite: elite,
  )..retargetTimer = 1000;

  group('Lava: the Fissures', () {
    test('a brute crossing a crack sets it off; a wisp does not', () async {
      final game = await lit('Lava');
      game.enemies.clear();
      final crack = game.mysticFissurePointNear(0)!;
      final wisp = body(crack);
      game.enemies.add(wisp);
      for (var f = 0; f < 120; f++) {
        wisp.position = crack;
        keepAlive(game);
        game.update(1 / 60);
      }
      expect(
        game.mysticMeteorCount,
        isZero,
        reason: 'the rank and file broke the floor open',
      );

      final brute = body(crack, tier: EnemyTier.brute);
      game.enemies.add(brute);
      for (var f = 0; f < 60 && game.mysticMeteorCount == 0; f++) {
        brute.position = crack;
        keepAlive(game);
        game.update(1 / 60);
      }
      expect(
        game.mysticMeteorCount,
        greaterThan(0),
        reason: 'a brute stood on a crack and nothing came down',
      );
    });

    test('an elite breaks a crack whatever its size', () async {
      final game = await lit('Lava');
      game.enemies.clear();
      final crack = game.mysticFissurePointNear(0)!;
      final elite = body(crack, tier: EnemyTier.drone, elite: true);
      game.enemies.add(elite);
      for (var f = 0; f < 60 && game.mysticMeteorCount == 0; f++) {
        elite.position = crack;
        keepAlive(game);
        game.update(1 / 60);
      }
      expect(game.mysticMeteorCount, greaterThan(0));
    });
  });

  group('Dust: the Haze', () {
    double turned(Offset moved, Offset toward) {
      final a = atan2(moved.dy, moved.dx) - atan2(toward.dy, toward.dx);
      return atan2(sin(a), cos(a)).abs();
    }

    test('a charger in the haze can lose the orb, then find it', () async {
      final game = await lit('Dust');
      game.enemies.clear();
      final charger = body(
        game.orb.position + const Offset(-600, 0),
        speed: 60,
      );
      game.enemies.add(charger);
      var lost = false;
      for (var i = 0; i < 200 && !lost; i++) {
        lost = game.debugLoseWayInHaze(charger);
      }
      expect(lost, isTrue, reason: 'the haze never took a walker');
      expect(charger.mysticHazeLostTimer, greaterThan(0));
      expect(game.mysticHazeLostCount, greaterThan(0));

      // Walks off its heading while lost...
      var from = charger.position;
      var toward = game.orb.position - from;
      run(game, 10);
      expect(
        turned(charger.position - from, toward),
        greaterThan(40 * pi / 180),
        reason: 'it walked straight at the orb while lost in the haze',
      );

      // ...and straight at the orb once it finds it again.
      for (var f = 0; f < 240 && charger.mysticHazeLostTimer > 0; f++) {
        keepAlive(game);
        game.update(1 / 60);
      }
      expect(charger.mysticHazeLostTimer, 0);
      from = charger.position;
      toward = game.orb.position - from;
      run(game, 10);
      expect(turned(charger.position - from, toward), lessThan(0.1));
    });

    test('shooters keep their misfire; nothing is lost without the world', () async {
      final game = await lit('Dust');
      final shooter = body(
        game.orb.position + const Offset(-600, 0),
        conduct: EnemyConduct.standoff,
      );
      for (var i = 0; i < 200; i++) {
        expect(game.debugLoseWayInHaze(shooter), isFalse);
      }
      final walker = body(game.orb.position + const Offset(-600, 0));
      game.returnCompanion(0);
      for (var i = 0; i < 200; i++) {
        expect(game.debugLoseWayInHaze(walker), isFalse);
      }
      expect(walker.mysticHazeLostTimer, 0);
    });
  });

  group('Crystal: the Vein', () {
    test('a taken shard bursts round the ship, and still pays the meter', () async {
      final game = await lit('Crystal');
      game.enemies.clear();
      // Kill bodies beside the ship until a shard drops.
      for (var i = 0; i < 200 && game.mysticCrystalCount(0) == 0; i++) {
        final victim = body(game.ship.position + const Offset(90, 0), hp: 1);
        game.enemies.add(victim);
        game.debugKillEnemy(victim);
      }
      expect(game.mysticCrystalCount(0), greaterThan(0));

      final caster = game.activeCompanions[0]!;
      final burst = game.debugMysticCrystalBurst(
        game.debugMysticCrystalValue(EnemyTier.wisp),
        caster.abilityAtk,
      );
      expect(
        burst,
        closeTo(
          caster.abilityAtk * CosmicSurvivalGame.kMysticCrystalBurstPower,
          1e-6,
        ),
      );

      final near = body(game.ship.position + const Offset(40, 0));
      game.enemies.add(near);
      game.alchemicalMeter = 0;
      final burstsBefore = game.mysticCrystalBurstCount;
      var hpBefore = near.hp;
      var dropAtBurst = 0.0;
      for (
        var f = 0;
        f < 240 && game.mysticCrystalBurstCount == burstsBefore;
        f++
      ) {
        near.position = game.ship.position + const Offset(40, 0);
        hpBefore = near.hp;
        keepAlive(game);
        game.update(1 / 60);
        dropAtBurst = hpBefore - near.hp;
      }
      expect(
        game.mysticCrystalBurstCount,
        greaterThan(burstsBefore),
        reason: 'a shard was taken and nothing burst',
      );
      expect(
        dropAtBurst,
        greaterThanOrEqualTo(burst * 0.5),
        reason: 'the burst did not reach the body beside the ship',
      );
      expect(game.alchemicalMeter, greaterThan(0));
    });
  });

  // ── Light Mask ──────────────────────────────────────────────────────────

  List<Projectile> lightVoids({
    required double beauty,
    double potential = 50,
  }) =>
      createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 0,
        family: 'mask',
        element: 'Light',
        damage: 40,
        maxHp: 100,
        casterPower: beauty,
        casterBeauty: beauty,
        casterIntelligence: 4,
        casterStrength: 4,
        casterBeautyPotential: potential,
        targetPos: const Offset(300, 0),
      ).projectiles..forEach((p) => p.sourceSlotIndex = 0);

  group('Light Mask', () {
    test('throws three voids at a low stat, up to seven at Potential 95', () {
      expect(lightVoids(beauty: 2.0).length, 3);
      expect(lightVoids(beauty: kAbilityStatAverage).length, 4);
      expect(lightVoids(beauty: 7.5, potential: 80).length, 5);
      expect(lightVoids(beauty: 7.5, potential: 95).length, 7);
      expect(lightVoids(beauty: 20).length, 7);
      for (final p in lightVoids(beauty: 7.5)) {
        expect(p.hitEffect, AbilityEffectKind.execute);
        expect(p.abilityFamily, 'mask');
      }
    });

    test('the voids are laid across the orb approach, apart', () {
      final voids = lightVoids(beauty: 7.5, potential: 95);
      placeMaskTraps(
        traps: voids,
        caster: Offset.zero,
        ship: Offset.zero,
        allies: const [Offset.zero],
        target: const Offset(450, 0),
        arenaCenter: Offset.zero,
        arenaRadius: 1100,
        guard: Offset.zero,
      );
      for (var i = 0; i < voids.length; i++) {
        for (var j = i + 1; j < voids.length; j++) {
          expect(
            (voids[i].position - voids[j].position).distance,
            greaterThan(10),
          );
        }
      }
    });

    test('a void lets the small walk over it and waits for a heavy body', () async {
      // User, 2026-10-21, choosing it: the first wisps to arrive spent every
      // void a cast laid.
      final game = CosmicSurvivalGame(
        party: [
          CosmicPartyMember(
            instanceId: 'mask-light',
            baseId: 'MSK01',
            displayName: 'Mask Light',
            family: 'Mask',
            element: 'Light',
            level: 10,
            slotIndex: 0,
            statSpeed: 4,
            statIntelligence: 4,
            statStrength: 4,
            statBeauty: 4,
            staminaBars: 5,
            staminaMax: 5,
          ),
        ],
        onGameOver: () {},
        random: Random(5),
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      game.activeCompanions[0]!.specialCooldown = 99999;
      game.activeCompanions[0]!.basicCooldown = 99999;
      game.enemies.clear();
      game.companionProjectiles.clear();

      final lightVoid = lightVoids(beauty: 2.0).first;
      final at = game.orb.position + const Offset(420, 0);
      lightVoid.position = at;
      game.companionProjectiles.add(lightVoid);
      final small = [
        body(at),
        body(at, tier: EnemyTier.drone),
        body(at, tier: EnemyTier.sentinel),
      ];
      game.enemies.addAll(small);
      void hold(List<CosmicSurvivalEnemy> bodies, int frames) {
        for (var f = 0; f < frames; f++) {
          for (final b in bodies) {
            if (!b.isDead) b.position = at;
          }
          keepAlive(game);
          game.update(1 / 60);
        }
      }

      hold(small, 30);
      expect(small.where((b) => b.isDead), isEmpty);
      expect(game.companionProjectiles, contains(lightVoid));

      final brute = body(at, tier: EnemyTier.brute);
      game.enemies.add(brute);
      hold([...small, brute], 30);
      expect(brute.isDead, isTrue, reason: 'the heavy body it waited for');
      expect(small.where((b) => b.isDead), isEmpty);
    });

    test('each void kills one body and is spent', () async {
      final game = CosmicSurvivalGame(
        party: [
          CosmicPartyMember(
            instanceId: 'mask-light',
            baseId: 'MSK01',
            displayName: 'Mask Light',
            family: 'Mask',
            element: 'Light',
            level: 10,
            slotIndex: 0,
            statSpeed: 4,
            statIntelligence: 4,
            statStrength: 4,
            statBeauty: 4,
            staminaBars: 5,
            staminaMax: 5,
          ),
        ],
        onGameOver: () {},
        random: Random(5),
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      game.activeCompanions[0]!.specialCooldown = 99999;
      game.activeCompanions[0]!.basicCooldown = 99999;
      game.enemies.clear();
      game.companionProjectiles.clear();

      final voids = lightVoids(beauty: 2.0);
      expect(voids.length, 3);
      final victims = <CosmicSurvivalEnemy>[];
      for (var i = 0; i < voids.length; i++) {
        final at =
            game.orb.position +
            Offset(cos(i * 2.1), sin(i * 2.1)) * (400.0 + 60 * i);
        voids[i].position = at;
        game.companionProjectiles.add(voids[i]);
        // Two bodies on every void, a heavy elite among them.
        victims
          ..add(body(at, tier: EnemyTier.brute, elite: true))
          ..add(body(at));
      }
      game.enemies.addAll(victims);
      for (var f = 0; f < 30; f++) {
        for (final v in victims) {
          if (!v.isDead) v.position = voids[victims.indexOf(v) ~/ 2].position;
        }
        keepAlive(game);
        game.update(1 / 60);
      }
      expect(
        victims.where((v) => v.isDead).length,
        voids.length,
        reason: 'every void kills one body, and only one',
      );
      for (var i = 0; i < voids.length; i++) {
        expect(
          victims[2 * i].isDead || victims[2 * i + 1].isDead,
          isTrue,
          reason: 'void $i killed nothing',
        );
        expect(voids[i].trapSpent, isTrue);
      }
    });
  });
}
