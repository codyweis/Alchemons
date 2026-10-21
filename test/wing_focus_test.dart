import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/stadium/battle_ladder.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wing focus (the 2026-10-20 rebuild, the user's "maybe wings have really
/// low damage but the longer they are in a target it gets stronger", for
/// every Wing): a line beam starts cold on a body and heats while it stays
/// there, runs on through that body to its full range, and a held Ice beam
/// freezes. Driven through the real games: survival, and open space, whose
/// beam runtime the PvP battle runs.
/// A plain line beam: Dark's carries no rider, so a tick is only its damage.
const darkBeam = WingBeamEffect(
  element: 'Dark',
  targetPolicy: WingBeamTargetPolicy.nearestEnemy,
  duration: 3.2,
  tickInterval: 0.2,
  damagePerTick: 40,
  range: 520,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rule', () {
    test('heat climbs from the floor to the peak, and a switch starts over', () {
      final heat = WingBeamHeat();
      final a = Object(), b = Object();
      final seen = <double>[];
      for (var i = 0; i < 14; i++) {
        seen.add(heat.tick(a, 0.2));
      }
      expect(seen.first, WingBeamRules.heatFloor);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
      expect(seen[5], closeTo(WingBeamRules.heatAt(1.0), 1e-9));
      expect(seen.last, WingBeamRules.heatPeak, reason: 'never reached peak');
      expect(heat.on, same(a));
      // Another body, or none: back to the floor.
      expect(heat.tick(b, 0.2), WingBeamRules.heatFloor);
      expect(heat.on, same(b));
      expect(heat.tick(b, 0.2), greaterThan(WingBeamRules.heatFloor));
      expect(heat.tick(null, 0.2), WingBeamRules.heatFloor);
      expect(heat.tick(b, 0.2), WingBeamRules.heatFloor);
    });

    test('only line beams heat, and only the nearest-body ones sweep', () {
      WingBeamEffect beam(
        WingBeamTargetPolicy policy, {
        double charge = 0,
      }) => WingBeamEffect(
        element: 'Dark',
        targetPolicy: policy,
        duration: 2,
        tickInterval: 0.2,
        damagePerTick: 1,
        chargeTime: charge,
      );
      expect(WingBeamRules.heats(beam(WingBeamTargetPolicy.nearestEnemy)), isTrue);
      expect(
        WingBeamRules.heats(beam(WingBeamTargetPolicy.lowestHealthEnemy)),
        isTrue,
      );
      expect(WingBeamRules.heats(beam(WingBeamTargetPolicy.ring)), isFalse);
      expect(
        WingBeamRules.heats(
          beam(WingBeamTargetPolicy.nearestEnemy, charge: 3),
        ),
        isFalse,
        reason: "Lightning's charged blast is one hit",
      );
      expect(WingBeamRules.sweeps(beam(WingBeamTargetPolicy.nearestEnemy)), isTrue);
      expect(
        WingBeamRules.sweeps(beam(WingBeamTargetPolicy.lowestHealthEnemy)),
        isFalse,
        reason: "Blood's line ends on the body it has locked",
      );
      // Through the target, out to range.
      final end = WingBeamRules.sweepEnd(
        Offset.zero,
        const Offset(100, 0),
        400,
        0,
      );
      expect(end.dx, closeTo(400, 1e-9));
      expect(end.dy, closeTo(0, 1e-9));
    });
  });

  group('survival', () {
    CosmicPartyMember wing(String element) => CosmicPartyMember(
      instanceId: 'wing-0',
      baseId: 'WNG01',
      displayName: 'Wing $element',
      family: 'Wing',
      element: element,
      level: 10,
      slotIndex: 0,
      statSpeed: 4.25,
      statIntelligence: 4.25,
      statStrength: 4.25,
      statBeauty: 4.25,
      statSpeedPotential: 50,
      statIntelligencePotential: 50,
      statStrengthPotential: 50,
      statBeautyPotential: 50,
      staminaBars: 3,
      staminaMax: 3,
    );

    /// A cleared arena with the Wing out and its own attacks held.
    Future<CosmicSurvivalGame> arena(String element) async {
      final game = CosmicSurvivalGame(
        party: [wing(element)],
        onGameOver: () {},
        random: Random(5),
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      for (
        var i = 0;
        i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
        i++
      ) {
        game.update(1 / 60);
      }
      for (final e in game.enemies) {
        e.isDead = true;
      }
      game.orb.shieldHp = 0;
      game.ship.position = game.orb.position + const Offset(0, 900);
      game.ship.fireTimer = -1e9;
      return game;
    }

    CosmicSurvivalEnemy body(
      CosmicSurvivalGame game,
      Offset at, {
      double hp = 1e7,
      double speed = 0,
    }) {
      final e = CosmicSurvivalEnemy(
        position: at,
        hp: hp,
        maxHp: hp,
        speed: speed,
        damage: 0,
        radius: 11,
        tier: EnemyTier.drone,
        element: 'Fire',
        target: CosmicEnemyTarget.orb,
        conduct: EnemyConduct.stalk,
      );
      game.enemies.add(e);
      return e;
    }

    /// One frame with the Wing pinned at [at], its attacks held, and every
    /// body but [keep] put down; [pin] holds the kept bodies in place.
    void frame(
      CosmicSurvivalGame game,
      Offset at,
      Set<CosmicSurvivalEnemy> keep, {
      Map<CosmicSurvivalEnemy, Offset> pin = const {},
    }) {
      final comp = game.activeCompanions[0]!;
      comp
        ..position = at
        ..specialCooldown = 99999
        ..basicCooldown = 99999;
      for (final e in game.enemies) {
        if (!keep.contains(e)) e.isDead = true;
      }
      for (final entry in pin.entries) {
        entry.key.position = entry.value;
      }
      game.update(1 / 60);
      for (final entry in pin.entries) {
        entry.key.position = entry.value;
      }
    }

    test('heat rises on a held body and starts over on a switch', () async {
      final game = await arena('Dark');
      final at = game.activeCompanions[0]!.position;
      final aAt = at + const Offset(140, 0);
      final a = body(game, aAt);
      game.debugCastWingBeam(0, darkBeam.scaled(durationMultiplier: 1.6));
      final ticks = <double>[];
      var last = a.hp;
      for (var f = 0; f < 60 * 2 + 20; f++) {
        frame(game, at, {a}, pin: {a: aAt});
        if (a.hp < last) {
          ticks.add(last - a.hp);
          last = a.hp;
        }
      }
      expect(ticks.length, greaterThanOrEqualTo(10));
      // Each tick on the held body is hotter than the one before, by the
      // rule's own curve (whatever multipliers the hit picks up on the way).
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i], greaterThan(ticks[i - 1] - 1e-9));
        expect(
          ticks[i] / ticks.first,
          closeTo(
            WingBeamRules.heatAt(i * darkBeam.tickInterval) /
                WingBeamRules.heatFloor,
            1e-6,
          ),
          reason: 'tick $i',
        );
      }
      expect(game.debugWingBeams.single.heldOn, same(a));
      // A nearer body takes the beam: its first tick is cold again, and the
      // body behind it, now only on the line, takes the unheated tick.
      final bAt = at + const Offset(70, 0);
      final b = body(game, bAt);
      var aBefore = a.hp, bBefore = b.hp;
      for (var f = 0; f < 60 && b.hp == bBefore; f++) {
        frame(game, at, {a, b}, pin: {a: aAt, b: bAt});
      }
      expect(game.debugWingBeams.single.heldOn, same(b));
      expect(game.debugWingBeams.single.heat, WingBeamRules.heatFloor);
      expect(bBefore - b.hp, closeTo(ticks.first, 1e-6));
      expect(
        aBefore - a.hp,
        closeTo(
          ticks.first * WingBeamRules.lineShare / WingBeamRules.heatFloor,
          1e-6,
        ),
      );
      // Held a while, then gone: the beam goes back to the first, cold.
      for (var f = 0; f < 30; f++) {
        frame(game, at, {a, b}, pin: {a: aAt, b: bAt});
      }
      expect(game.debugWingBeams.single.heat, greaterThan(WingBeamRules.heatFloor));
      b.isDead = true;
      aBefore = a.hp;
      for (var f = 0; f < 60 && a.hp == aBefore; f++) {
        frame(game, at, {a}, pin: {a: aAt});
      }
      expect(game.debugWingBeams.single.heldOn, same(a));
      expect(game.debugWingBeams.single.heat, WingBeamRules.heatFloor);
      expect(aBefore - a.hp, closeTo(ticks.first, 1e-6));
    });

    test(
      'a line beam runs through its body and strikes those behind at the '
      'unheated tick',
      () async {
        final game = await arena('Dark');
        final at = game.activeCompanions[0]!.position;
        final aAt = at + const Offset(120, 0);
        final bAt = at + const Offset(320, 0);
        final cAt = at + const Offset(320, 140);
        final a = body(game, aAt);
        final behind = body(game, bAt);
        final aside = body(game, cAt);
        final keep = {a, behind, aside};
        final pins = {a: aAt, behind: bAt, aside: cAt};
        game.debugCastWingBeam(0, darkBeam);
        final aTicks = <double>[], bTicks = <double>[];
        var aLast = a.hp, bLast = behind.hp;
        for (var f = 0; f < 60 * 2; f++) {
          frame(game, at, keep, pin: pins);
          if (a.hp < aLast) {
            aTicks.add(aLast - a.hp);
            aLast = a.hp;
          }
          if (behind.hp < bLast) {
            bTicks.add(bLast - behind.hp);
            bLast = behind.hp;
          }
        }
        // The line runs on to the beam's full range, past the body it is on.
        final end = game.debugWingBeams.single.end!;
        expect((end - at).distance, closeTo(darkBeam.range, 1.0));
        expect(game.debugWingBeams.single.heldOn, same(a));
        expect(bTicks, hasLength(aTicks.length), reason: 'missed behind');
        expect(aside.hp, aside.maxHp, reason: 'a body off the line was hit');
        // The body behind takes the same unheated tick every time; the held
        // one climbs well past it.
        for (final t in bTicks) {
          expect(
            t,
            closeTo(
              aTicks.first * WingBeamRules.lineShare / WingBeamRules.heatFloor,
              1e-6,
            ),
          );
        }
        expect(aTicks.last, greaterThan(bTicks.last * 3));
      },
    );

    test(
      'an Ice beam held on a body freezes it; frost thaws only off the beam',
      () async {
        final game = await arena('Ice');
        final at = game.activeCompanions[0]!.position;
        final eAt = at + const Offset(150, 0);
        final e = body(game, eAt, speed: 40);
        game.debugCastWingBeam(
          0,
          const WingBeamEffect(
            element: 'Ice',
            targetPolicy: WingBeamTargetPolicy.nearestEnemy,
            duration: 2.4,
            tickInterval: 0.2,
            damagePerTick: 1,
            range: 520,
          ),
        );
        var frozeAt = -1;
        var lastFrost = 0.0;
        for (var f = 0; f < 60 * 2 + 20 && frozeAt < 0; f++) {
          frame(game, at, {e}, pin: {e: eAt});
          if (e.slowMultiplier <= WingBeamRules.freezeSlow + 1e-9) {
            frozeAt = f;
          } else {
            expect(
              e.frostBuildup,
              greaterThanOrEqualTo(lastFrost),
              reason: 'frost thawed under the beam at frame $f',
            );
            lastFrost = e.frostBuildup;
          }
        }
        expect(frozeAt, greaterThan(0), reason: 'a held Ice beam never froze');
        expect(e.slowTimer, greaterThan(2.0));
        // Off the beam, the frost goes.
        e.frostBuildup = 0.6;
        final away = at + const Offset(0, -700);
        for (var f = 0; f < 60; f++) {
          frame(game, at, {e}, pin: {e: away});
        }
        expect(e.frostBuildup, lessThan(0.6));
      },
    );

    test('a boss under a held Ice beam is chilled, not frozen', () async {
      final game = await arena('Ice');
      final at = game.activeCompanions[0]!.position;
      final bossAt = at + const Offset(170, 0);
      final boss = game.spawner.createBossForWave(5, bossAt)!
        ..spawnIntroTimer = 0
        ..shieldUp = false
        ..shieldTimer = 1e9;
      game.activeBoss = boss;
      game.debugCastWingBeam(
        0,
        const WingBeamEffect(
          element: 'Ice',
          targetPolicy: WingBeamTargetPolicy.nearestEnemy,
          duration: 2.4,
          tickInterval: 0.2,
          damagePerTick: 1,
          range: 520,
        ),
      );
      var chilled = false;
      for (var f = 0; f < 60 * 2 && !chilled; f++) {
        boss.position = bossAt;
        frame(game, at, const {});
        if (boss.chillTimer > 0) chilled = true;
      }
      expect(chilled, isTrue, reason: 'a held Ice beam never chilled the boss');
      expect(boss.chillMultiplier, kBossChillFloor);
      expect(boss.chillMultiplier, greaterThan(WingBeamRules.freezeSlow));
    });
  });

  group('open space and the battle', () {
    /// Deep space, away from every planet (and so every garrison).
    Future<CosmicGame> deepSpace() async {
      final game = CosmicGame(
        world_: CosmicWorld.generate(seed: 37),
        onMeterChanged: () {},
      );
      game.ship = ShipComponent(pos: Offset.zero);
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      final world = game.world_;
      var home = Offset.zero;
      var best = -1.0;
      for (var gx = 1; gx < 20; gx++) {
        for (var gy = 1; gy < 20; gy++) {
          final p = Offset(
            world.worldSize.width * gx / 20,
            world.worldSize.height * gy / 20,
          );
          var nearest = double.infinity;
          for (final planet in world.planets) {
            nearest = min(nearest, (planet.position - p).distance);
          }
          if (nearest > best) {
            best = nearest;
            home = p;
          }
        }
      }
      game.teleportTo(home);
      game.enemies.clear();
      game.activeBoss = null;
      return game;
    }

    /// A catalog Wing of [element], bred to [potential] as the ladder does.
    CosmicPartyMember bred(String element, int potential) {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final row in json['creatures'] as List) {
        final c = Creature.fromJson(row as Map<String, dynamic>);
        if (c.mutationFamily == 'Wing' &&
            c.baseStats != null &&
            c.types.isNotEmpty &&
            c.types.first == element) {
          return ladderMember(
            c,
            potential: potential,
            id: 'wing-$element',
            sprites: false,
          );
        }
      }
      fail('no $element Wing in the catalog');
    }

    test(
      "a P80 beam held on one body deals at most 0.85 of what it dealt flat",
      () async {
        // The PvP battle's case: a 2v2 beam stays on one creature the whole
        // way, which is why Wings won 64% of battles. Focus must bring that
        // down, not up.
        for (final element in ['Dark', 'Ice', 'Mud', 'Air', 'Crystal']) {
          final game = await deepSpace();
          game.summonCompanion(bred(element, 80), slotIndex: 0);
          final comp = game.activeCompanions[0]!
            ..invincibleTimer = 0
            ..basicCooldown = 100
            ..specialCooldown = 0;
          final at = game.ship.pos + const Offset(170, 0);
          final target = CosmicEnemy(
            position: at,
            element: 'Fire',
            tier: EnemyTier.drone,
            radius: 14,
            health: 1e9,
            speed: 0,
          );
          game.enemies.add(target);
          void step() {
            game.enemies.removeWhere((e) => !identical(e, target));
            comp.basicCooldown = 100;
            game.update(1 / 60);
            target.position = at;
            // Only the Wing's own beam, not its co-beam from the ship or
            // the bolts its special also throws.
            game.companionProjectiles.removeWhere(
              (p) => p.abilityFamily == 'wing',
            );
          }

          WingBeamView? own;
          for (var f = 0; f < 600 && own == null; f++) {
            step();
            for (final b in game.debugWingBeams()) {
              if (b.anchor == 'caster') own = b;
            }
          }
          expect(own, isNotNull, reason: '$element never cast');
          comp.specialCooldown = 100;
          final dpt = own!.damagePerTick;
          var dealt = 0.0, ticks = 0;
          var last = target.health;
          for (var f = 0; f < 60 * 6 && game.debugWingBeams().isNotEmpty; f++) {
            step();
            if (target.health < last) {
              dealt += last - target.health;
              ticks++;
              last = target.health;
            }
          }
          expect(ticks, greaterThanOrEqualTo(8), reason: element);
          final flat = ticks * dpt;
          if (Platform.environment['WING_FOCUS_REPORT'] != null) {
            // ignore: avoid_print
            print(
              '$element: $ticks ticks, ${(dealt / flat).toStringAsFixed(3)} '
              'of the flat tick',
            );
          }
          expect(
            dealt,
            lessThanOrEqualTo(flat * 0.85 + 1e-6),
            reason: '$element: ${(dealt / flat).toStringAsFixed(3)} of flat',
          );
          expect(dealt, greaterThan(flat * 0.6), reason: element);
        }
      },
    );

    test('the open-space beam runs through its body to full range', () async {
      final game = await deepSpace();
      game.summonCompanion(bred('Dark', 50), slotIndex: 0);
      final comp = game.activeCompanions[0]!
        ..basicCooldown = 100
        ..specialCooldown = 100;
      final aAt = game.ship.pos + const Offset(140, 0);
      final bAt = game.ship.pos + const Offset(300, 0);
      CosmicEnemy foe(Offset at) {
        final e = CosmicEnemy(
          position: at,
          element: 'Fire',
          tier: EnemyTier.drone,
          radius: 10,
          health: 1e9,
          speed: 0,
        );
        game.enemies.add(e);
        return e;
      }

      final a = foe(aAt), behind = foe(bAt);
      game.debugCastWingBeam(comp, darkBeam);
      final aTicks = <double>[], bTicks = <double>[];
      var aLast = a.health, bLast = behind.health;
      for (var f = 0; f < 60 * 2; f++) {
        comp
          ..position = game.ship.pos
          ..basicCooldown = 100;
        game.enemies.removeWhere((e) => !identical(e, a) && !identical(e, behind));
        game.update(1 / 60);
        a.position = aAt;
        behind.position = bAt;
        if (a.health < aLast) {
          aTicks.add(aLast - a.health);
          aLast = a.health;
        }
        if (behind.health < bLast) {
          bTicks.add(bLast - behind.health);
          bLast = behind.health;
        }
      }
      expect(aTicks.length, greaterThanOrEqualTo(8));
      expect(bTicks, hasLength(aTicks.length));
      expect(aTicks.first, closeTo(darkBeam.damagePerTick * WingBeamRules.heatFloor, 1e-6));
      for (final t in bTicks) {
        expect(t, closeTo(darkBeam.damagePerTick * WingBeamRules.lineShare, 1e-6));
      }
      expect(aTicks.last, greaterThan(bTicks.last * 3));
      expect(game.debugWingBeams().single.heldOn, same(a));
    });
  });
}
