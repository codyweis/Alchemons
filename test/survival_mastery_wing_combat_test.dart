import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_wing.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wing's two paths, driven through the real game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  SurvivalFamilyMasterySnapshot equip(String pathId, {int throughTier = 4}) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.wing, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'wing-0',
        family: CreatureFamily.wing,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> arena({
    String element = 'Earth',
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [wing(element)],
      onGameOver: () {},
      masterySnapshot: snapshot,
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
    return game;
  }

  CosmicSurvivalEnemy body(Offset at, {double speed = 0}) =>
      CosmicSurvivalEnemy(
        position: at,
        hp: 1e9,
        maxHp: 1e9,
        speed: speed,
        damage: 0,
        radius: 11,
        tier: EnemyTier.drone,
        element: 'Ice',
        target: CosmicEnemyTarget.orb,
        conduct: EnemyConduct.stalk,
      );

  /// Every body but [keep] is put down, and the orb kept whole, so a test
  /// decides what the Wing shoots at.
  void only(CosmicSurvivalGame game, List<CosmicSurvivalEnemy> keep) {
    for (final e in game.enemies) {
      if (!keep.any((k) => identical(k, e))) e.isDead = true;
    }
    game.orb.currentHp = game.orb.maxHp;
  }

  /// The Wing's reach with whatever mastery it holds.
  double reach(CosmicSurvivalGame game) =>
      game.activeCompanions[0]!.attackRange * game.debugAttackRangeMultiplier(0);

  group('Longshot', () {
    test('Long Lens widens the range, and only Long Lens', () async {
      final plain = await arena();
      final long = await arena(
        snapshot: equip(WingNodes.longshotPath, throughTier: 4),
      );
      // Same chassis, so any difference is the path.
      expect(
        long.activeCompanions[0]!.attackRange,
        plain.activeCompanions[0]!.attackRange,
        reason: 'the base range should be untouched',
      );
      expect(plain.debugAttackRangeMultiplier(0), 1.0);
      expect(
        long.debugAttackRangeMultiplier(0),
        closeTo(WingTuning.longLensRange, 0.001),
      );
    });

    /// How far off the straight line to a far, moving body a Wing's first
    /// shot at it flies, in radians, with the Longshot nodes through [tier].
    Future<double> aimOffset(int tier) async {
      final game = await arena(
        snapshot: equip(WingNodes.longshotPath, throughTier: tier),
      );
      final comp = game.activeCompanions[0]!;
      final range = reach(game);
      // The body walks toward the orb; the Wing stands square to its walk,
      // far out, so leading it turns the shot sideways.
      final orb = game.orb.position;
      final start = orb + const Offset(360, 0);
      final wingAt = start + Offset(0, -range * 0.85);
      final target = body(start, speed: 90)..angle = pi;
      game.enemies.add(target);
      comp.specialCooldown = 99;
      final seen = <Object>{};
      for (var i = 0; i < 60 * 6; i++) {
        only(game, [target]);
        comp.position = wingAt;
        comp.specialCooldown = 99;
        game.update(1 / 60);
        for (final p in game.companionProjectiles) {
          if (p.sourceSlotIndex != 0 || !seen.add(p)) continue;
          if (p.abilityFamily.isNotEmpty) continue;
          final direct = atan2(
            target.position.dy - p.position.dy,
            target.position.dx - p.position.dx,
          );
          var diff = (p.angle - direct).abs();
          if (diff > pi) diff = 2 * pi - diff;
          return diff;
        }
      }
      fail('the Wing never shot at the far body');
    }

    test('Long Lens aims ahead of a far body, so the shot meets it', () async {
      final straight = await aimOffset(1);
      final led = await aimOffset(2);
      expect(straight, lessThan(0.03), reason: 'Rangefinder alone aims true');
      expect(led, greaterThan(straight + 0.04));
    });

    test('Overwatch: a body in the far reach takes one free shot, once',
        () async {
      Future<(int, int, int)> freeShots(int tier) async {
        final game = await arena(
          snapshot: equip(WingNodes.longshotPath, throughTier: tier),
        );
        final comp = game.activeCompanions[0]!;
        final at = comp.position;
        final range = reach(game);
        // Along the Wing's lane rather than toward the orb, where a body
        // is spent on reaching it.
        final toOrb = game.orb.position - at;
        final dir = Offset(-toOrb.dy, toOrb.dx) / toOrb.distance;
        final first = body(at + dir * range * 0.8);
        game.enemies.add(first);
        game.debugRebuildEnemyGrid();
        var generated = 0;
        final seen = <Object>{};
        void run(List<CosmicSurvivalEnemy> keep, int frames) {
          for (var i = 0; i < frames; i++) {
            only(game, keep);
            comp.position = at;
            // The Wing's own attack and special held off: anything it
            // fires is Overwatch's.
            comp.basicCooldown = 99;
            comp.specialCooldown = 99;
            game.update(1 / 60);
            for (final p in game.companionProjectiles) {
              if (p.sourceSlotIndex == 0 &&
                  p.masteryGenerated &&
                  seen.add(p)) {
                generated++;
              }
            }
          }
        }

        run([first], 60 * 3);
        final afterOne = game.wingMasteryFor(0)?.overwatchFired ?? 0;
        // A second body crossing in gets its own shot.
        final second = body(at - dir * range * 0.75);
        game.enemies.add(second);
        run([first, second], 60 * 3);
        return (
          afterOne,
          game.wingMasteryFor(0)?.overwatchFired ?? 0,
          generated,
        );
      }

      final (standoffOne, standoffTwo, standoffShots) = await freeShots(3);
      expect(standoffOne, 0, reason: 'only the capstone shoots for free');
      expect(standoffTwo, 0);
      expect(standoffShots, 0);
      final (one, two, shots) = await freeShots(4);
      expect(one, 1, reason: 'one shot, however long it stays in the band');
      expect(two, 2);
      // Each free shot is a Wing attack: its two bolts, in the air.
      expect(shots, 4);
    });

    test('Overwatch leaves a body inside 60% of range alone', () async {
      final game = await arena(
        snapshot: equip(WingNodes.longshotPath, throughTier: 4),
      );
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      final toOrb = game.orb.position - at;
      final lane = Offset(-toOrb.dy, toOrb.dx) / toOrb.distance;
      final near = body(at + lane * reach(game) * 0.4);
      game.enemies.add(near);
      for (var i = 0; i < 60 * 2; i++) {
        only(game, [near]);
        comp.position = at;
        comp.basicCooldown = 99;
        comp.specialCooldown = 99;
        game.update(1 / 60);
      }
      expect(game.wingMasteryFor(0)?.overwatchFired ?? 0, 0);
    });

    /// A Wing held at its post, its own attacks held off, and a brute at
    /// [bruteAt] times its range that begins to take aim [times] times.
    /// Returns what the brute lost and the free shots it drew.
    Future<(double, int)> takingAim({
      required int tier,
      double bruteAt = 1.7,
      int times = 3,
    }) async {
      final game = await arena(
        snapshot: equip(WingNodes.longshotPath, throughTier: tier),
      );
      final comp = game.activeCompanions[0]!;
      final range = reach(game);
      // The brute stands near the orb, so its beam is in reach of it; the
      // Wing stands off to one side, [bruteAt] times its range from it.
      final orb = game.orb.position;
      final at = orb - Offset(range * bruteAt - 100, 0);
      final brute = CosmicSurvivalEnemy(
        position: orb + const Offset(100, 0),
        hp: 1e9,
        maxHp: 1e9,
        speed: 0,
        damage: 0,
        radius: 20,
        tier: EnemyTier.brute,
        element: 'Earth',
        target: CosmicEnemyTarget.orb,
        conduct: EnemyConduct.stalk,
      );
      game.enemies.add(brute);
      for (var t = 0; t < times; t++) {
        // Idle and ready: it begins to charge its beam on the next frame,
        // if the orb is in its reach; it is put beside the orb's line of
        // fire by its own range, so the aim is forced here.
        for (var i = 0; i < 60 * 2; i++) {
          only(game, [brute]);
          if (i == 0) {
            brute.action
              ..phase = EnemyActionPhase.idle
              ..timer = 0;
            brute.attackCooldown = 0;
          } else if (brute.action.phase == EnemyActionPhase.idle) {
            brute.attackCooldown = 99;
          }
          comp.position = at;
          comp.basicCooldown = 99;
          comp.specialCooldown = 99;
          game.update(1 / 60);
        }
      }
      return (
        brute.maxHp - brute.hp,
        game.wingMasteryFor(0)?.overwatchAimShots ?? 0,
      );
    }

    test('Overwatch: a brute taking aim within twice the range draws a free '
        'shot each time it does', () async {
      final (hurt, shots) = await takingAim(tier: 4);
      expect(shots, 3);
      // The ship's guns reach it either way; the free shots are on top.
      final (shipOnly, none) = await takingAim(tier: 3);
      expect(none, 0);
      expect(hurt, greaterThan(shipOnly), reason: 'the shots never landed');
      final (_, beyond) = await takingAim(tier: 4, bruteAt: 2.3);
      expect(beyond, 0, reason: 'past twice the range');
    });
  });

  group('Tracer turns shots into beam time', () {
    /// A Wing held in place with one body in reach, and that body only.
    Future<(CosmicSurvivalGame, CosmicSurvivalEnemy)> onTarget(
      SurvivalFamilyMasterySnapshot? snapshot, {
      String element = 'Earth',
    }) async {
      final game = await arena(snapshot: snapshot, element: element);
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      // Toward the orb, which keeps it inside the arena from a rim lane.
      final toOrb = game.orb.position - at;
      final target = body(at + toOrb / toOrb.distance * 150);
      game.enemies.add(target);
      return (game, target);
    }

    test('landed attacks shave the special and bank beam time', () async {
      final (game, target) = await onTarget(
        equip(WingNodes.tracerPath, throughTier: 2),
      );
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      final reachAt = target.position;
      // Hold the special out of reach so only Tracer moves the cooldown.
      comp.specialCooldown = 30;
      var banked = 0.0;
      for (var i = 0; i < 60 * 10; i++) {
        only(game, [target]);
        comp.position = at;
        target.position = reachAt;
        game.update(1 / 60);
        banked = max(banked, game.wingMasteryFor(0)?.bankedBeamTime ?? 0);
      }
      // Ten seconds pass on their own; anything below that was shaved.
      expect(comp.specialCooldown, lessThan(20 - WingTuning.tracerShave));
      expect(banked, greaterThan(0));
      expect(banked, lessThanOrEqualTo(WingTuning.rangingCap + 0.001));
    });

    test('the bank is spent when a beam opens, not kept', () async {
      final game = await arena(
        snapshot: equip(WingNodes.tracerPath, throughTier: 2),
      );
      final comp = game.activeCompanions[0]!;
      final state = game.wingMasteryFor(0) ?? WingMasteryState();
      state.bankBeamTime(WingTuning.rangingCap, WingTuning.rangingCap);
      comp.specialCooldown = 0;
      for (var i = 0; i < 60 * 6; i++) {
        game.update(1 / 60);
      }
      expect(
        game.wingMasteryFor(0)?.bankedBeamTime ?? 0,
        lessThan(WingTuning.rangingCap),
      );
    });

    test('an unequipped Wing banks nothing', () async {
      final game = await arena();
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 30;
      for (var i = 0; i < 60 * 8; i++) {
        game.update(1 / 60);
      }
      expect(game.wingMasteryFor(0)?.bankedBeamTime ?? 0, 0);
    });

    /// The mean cooldown the Wing's auto-attacks set over ten seconds with
    /// the Tracer nodes through [tier]: with its special held off (no beam),
    /// or let go and counted only while a beam fires.
    Future<double> attackCooldown(int tier, {required bool beam}) async {
      final (game, target) = await onTarget(
        equip(WingNodes.tracerPath, throughTier: tier),
        element: 'Dark',
      );
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      final reachAt = target.position;
      final set = <double>[];
      var last = comp.basicCooldown;
      for (var i = 0; i < 60 * 10; i++) {
        only(game, [target]);
        comp.position = at;
        target.position = reachAt;
        if (!beam) comp.specialCooldown = 99;
        game.update(1 / 60);
        final firing = game.debugWingBeams.any((b) => b.slot == 0);
        if (!beam) expect(firing, isFalse);
        if (comp.basicCooldown > last + 0.05 && firing == beam) {
          set.add(comp.basicCooldown);
        }
        last = comp.basicCooldown;
      }
      expect(set, isNotEmpty, reason: 'no attack went (beam: $beam)');
      return set.reduce((a, b) => a + b) / set.length;
    }

    test('Hot Barrel: attacks come twice as fast while the beam fires',
        () async {
      final hotIdle = await attackCooldown(3, beam: false);
      final hotFiring = await attackCooldown(3, beam: true);
      expect(hotFiring / hotIdle, closeTo(WingTuning.hotBarrelCooldown, 0.1));
      // Without it the Wing keeps its pace with a beam up.
      final plainIdle = await attackCooldown(2, beam: false);
      final plainFiring = await attackCooldown(2, beam: true);
      expect(plainFiring / plainIdle, closeTo(1.0, 0.1));
    });
  });
}
