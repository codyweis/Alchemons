import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mask.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mask's two paths, driven through the real game.
///
/// The group that matters most is the last one. A Mask trap chain has already
/// cost this game 2.2 seconds in a single frame, and both of these paths
/// spawn things from kills. The ceilings are tested against a live arena, not
/// only against the resolvers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mask(String element) => CosmicPartyMember(
    instanceId: 'mask-0',
    baseId: 'MSK01',
    displayName: 'Mask $element',
    family: 'Mask',
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
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.mask, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'mask-0',
        family: CreatureFamily.mask,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> arena({
    String element = 'Lava',
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [mask(element)],
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

  int maskFixtures(CosmicSurvivalGame game) => game.companionProjectiles
      .where((p) => p.abilityFamily == 'mask' && p.stationary)
      .length;

  group('Deathmask leaves traps on kills', () {
    test('a dart kill leaves one, and an unequipped Mask leaves none', () async {
      Future<int> gravesAfterKills({
        SurvivalFamilyMasterySnapshot? snapshot,
      }) async {
        final game = await arena(snapshot: snapshot);
        final comp = game.activeCompanions[0]!;
        comp.specialCooldown = 99999;
        final before = maskFixtures(game);
        for (final enemy in List<CosmicSurvivalEnemy>.of(game.enemies)) {
          if (enemy.isDead) continue;
          game.debugKillByDart(0, enemy);
          for (var i = 0; i < 30; i++) {
            comp.specialCooldown = 99999;
            game.update(1 / 60);
          }
        }
        return maskFixtures(game) - before;
      }

      expect(await gravesAfterKills(), 0);
      expect(
        await gravesAfterKills(
          snapshot: equip(MaskNodes.deathmaskPath, throughTier: 1),
        ),
        greaterThan(0),
      );
    });

    test('the grave cap holds against a massacre', () async {
      final game = await arena(
        snapshot: equip(MaskNodes.deathmaskPath, throughTier: 4),
      );
      final comp = game.activeCompanions[0]!;

      // Kill everything the spawner produces, for a long time, and never let
      // the special place anything so every fixture on the field is a grave.
      for (var round = 0; round < 40; round++) {
        for (final enemy in List<CosmicSurvivalEnemy>.of(game.enemies)) {
          if (!enemy.isDead) game.debugKillByDart(0, enemy);
        }
        for (var i = 0; i < 30; i++) {
          comp.specialCooldown = 99999;
          game.update(1 / 60);
        }
      }
      final state = game.maskMasteryFor(0)!;
      expect(state.graves.length, lessThanOrEqualTo(MaskTuning.graveCap));
    });
  });

  group('Restless Graves', () {
    CosmicSurvivalEnemy still(CosmicSurvivalGame game, Offset at) {
      final template = game.enemies.first;
      final body = CosmicSurvivalEnemy(
        position: at,
        hp: 1e9,
        maxHp: 1e9,
        speed: 0,
        damage: 0,
        radius: 14,
        tier: template.tier,
        element: template.element,
        conduct: template.conduct,
        target: template.target,
      );
      game.enemies.add(body);
      return body;
    }

    /// Frames with the Mask's own attacks held and every body but [keep]
    /// put down as the spawner sends it in.
    void hold(
      CosmicSurvivalGame game,
      Set<CosmicSurvivalEnemy> keep,
      int frames,
    ) {
      final comp = game.activeCompanions[0]!;
      for (var f = 0; f < frames; f++) {
        comp.specialCooldown = 99999;
        comp.basicCooldown = 99999;
        for (final e in game.enemies) {
          if (!keep.contains(e)) e.isDead = true;
        }
        game.update(1 / 60);
      }
    }

    /// A grave left by a dart kill at [fell], with one standing body [gap]
    /// from it and nothing else on the field.
    Future<(CosmicSurvivalGame, Projectile, CosmicSurvivalEnemy)> graveBeside({
      required int tier,
      Offset gap = const Offset(90, 0),
    }) async {
      final game = await arena(
        snapshot: equip(MaskNodes.deathmaskPath, throughTier: tier),
      );
      for (final e in game.enemies) {
        e.isDead = true;
      }
      final fell = game.orb.position + const Offset(0, -220);
      final victim = still(game, fell)..hp = 1;
      final body = still(game, fell + gap);
      game.companionProjectiles.clear();
      game.debugKillByDart(0, victim);
      final graves = game.companionProjectiles
          .where((p) => p.abilityFamily == 'mask' && p.stationary)
          .toList();
      expect(graves, hasLength(1), reason: 'the kill left no grave');
      expect(graves.single.position, fell);
      return (game, graves.single, body);
    }

    test('a grave goes toward the bodies near it at a walking pace',
        () async {
      final (game, grave, body) = await graveBeside(
        tier: 2,
        gap: const Offset(300, 0),
      );
      final fell = grave.position;
      hold(game, {body}, 60);
      final moved = grave.position - fell;
      expect(
        moved.distance,
        closeTo(MaskTuning.restlessSpeed, 3),
        reason: 'a second of going',
      );
      // As fast as most of a wave walks, where it crept at 18 until
      // 2026-10-29.
      expect(MaskTuning.restlessSpeed, greaterThanOrEqualTo(60));
      expect(moved.dx, greaterThan(0), reason: 'it went away from the body');
      expect(moved.dy.abs(), lessThan(1));
      // It keeps the shape it was laid with as it goes.
      expect(grave.lookAnchor, fell);
    });

    test('it settles in the middle of what it reached, and keeps up as it '
        'walks', () async {
      final (game, grave, body) = await graveBeside(
        tier: 2,
        gap: const Offset(140, 0),
      );
      final comp = game.activeCompanions[0]!;
      var caught = -1;
      var stayed = 0;
      for (var f = 0; f < 60 * 6 && grave.life > 0; f++) {
        // The body walks away from the grave at 40 a second.
        body.position += const Offset(40 / 60, 0);
        comp.specialCooldown = 99999;
        comp.basicCooldown = 99999;
        for (final e in game.enemies) {
          if (!identical(e, body)) e.isDead = true;
        }
        game.update(1 / 60);
        if ((body.position - grave.position).distance <= body.radius) {
          if (caught < 0) caught = f;
          stayed++;
        }
      }
      expect(caught, greaterThanOrEqualTo(0), reason: 'it never caught up');
      expect(caught / 60, lessThan(6));
      expect(stayed, greaterThan(30));
    });

    /// A body that walks (so is not standing still) but is put back where
    /// it was every frame by [pinned].
    CosmicSurvivalEnemy walker(
      CosmicSurvivalGame game,
      Offset at, {
      EnemyTier tier = EnemyTier.wisp,
    }) {
      final body = CosmicSurvivalEnemy(
        position: at,
        hp: 1e9,
        maxHp: 1e9,
        speed: 50,
        damage: 0,
        radius: 14,
        tier: tier,
        element: 'Fire',
        conduct: EnemyConduct.stalk,
        target: CosmicEnemyTarget.orb,
      );
      game.enemies.add(body);
      return body;
    }

    /// [hold], with each of [bodies] put back where it stood every frame.
    void pinned(
      CosmicSurvivalGame game,
      List<CosmicSurvivalEnemy> bodies,
      int frames, {
      void Function()? each,
    }) {
      final at = [for (final b in bodies) b.position];
      for (var f = 0; f < frames; f++) {
        for (var i = 0; i < bodies.length; i++) {
          bodies[i].position = at[i];
        }
        each?.call();
        hold(game, bodies.toSet(), 1);
      }
    }

    test('with nothing standing still, it goes to the thickest crowd near '
        'it, not the nearest body', () async {
      final (game, grave, stand) = await graveBeside(tier: 2);
      stand.isDead = true;
      final fell = grave.position;
      final near = walker(game, fell + const Offset(-70, 0));
      // Four walking together, further off the other way.
      final crowd = [
        for (var i = 0; i < 4; i++)
          walker(game, fell + Offset(200.0 + 5 * (i % 2), 5.0 * (i ~/ 2))),
      ];
      pinned(game, [near, ...crowd], 60 * 4);
      final middle =
          crowd.fold(Offset.zero, (s, e) => s + e.position) / 4.0;
      expect(grave.position.dx, greaterThan(fell.dx + 100));
      expect((grave.position - middle).distance, lessThan(20));
    });

    test('it lies under a brute planted to fire, past a walking crowd',
        () async {
      final (game, grave, stand) = await graveBeside(tier: 2);
      stand.isDead = true;
      final fell = grave.position;
      final crowd = [
        for (var i = 0; i < 4; i++)
          walker(game, fell + Offset(-60.0 - 5 * (i % 2), 5.0 * (i ~/ 2))),
      ];
      final brute = walker(
        game,
        fell + const Offset(220, 0),
        tier: EnemyTier.brute,
      );
      pinned(
        game,
        [...crowd, brute],
        60 * 4,
        each: () => brute.action
          ..phase = EnemyActionPhase.windUp
          ..timer = 10,
      );
      expect((grave.position - brute.position).distance, lessThan(4));
    });

    test('without the node a grave stays where it fell', () async {
      final (game, grave, body) = await graveBeside(tier: 1);
      final fell = grave.position;
      hold(game, {body}, 120);
      expect(grave.position, fell);
      expect(game.maskRestlessGraves, isEmpty);
    });

    test('the traps the special places stay where it laid them', () async {
      final game = await arena(
        snapshot: equip(MaskNodes.deathmaskPath, throughTier: 4),
      );
      for (final e in game.enemies) {
        e.isDead = true;
      }
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      final body = still(game, at + const Offset(120, 0));
      game.companionProjectiles.clear();
      comp.specialCooldown = 0;
      List<Projectile> traps() => game.companionProjectiles
          .where((p) => p.abilityFamily == 'mask' && p.stationary)
          .toList();
      for (var f = 0; f < 60 * 4 && traps().isEmpty; f++) {
        comp.position = at;
        comp.basicCooldown = 99999;
        for (final e in game.enemies) {
          if (!identical(e, body)) e.isDead = true;
        }
        game.update(1 / 60);
      }
      final placed = traps();
      expect(placed, isNotEmpty, reason: 'the Mask never cast');
      final laid = [for (final p in placed) p.position];
      hold(game, {body}, 120);
      for (var i = 0; i < placed.length; i++) {
        if (placed[i].life <= 0) continue;
        expect(placed[i].position, laid[i]);
      }
      expect(game.maskRestlessGraves, isEmpty);
    });
  });

  group('Contagion spreads and then stops', () {
    test('an infection reaches bodies the trap never touched', () async {
      final game = await arena(
        snapshot: equip(MaskNodes.contagionPath, throughTier: 2),
      );
      final alive = game.enemies.where((e) => !e.isDead).toList();
      expect(alive.length, greaterThan(2));

      // Seed one body and huddle the rest around it.
      final seed = alive.first;
      game.debugInfect(0, seed);
      for (final other in alive.skip(1)) {
        other.position = seed.position + const Offset(30, 0);
      }
      for (var i = 0; i < 180; i++) {
        game.update(1 / 60);
        for (final other in alive.skip(1)) {
          if (!other.isDead) other.position = seed.position + const Offset(30, 0);
        }
      }
      expect(
        alive.skip(1).where((e) => e.isMaskInfected).length,
        greaterThan(0),
        reason: 'the infection never jumped',
      );
    });

    test('generations are capped, so a crowd cannot sustain it', () async {
      final game = await arena(
        snapshot: equip(MaskNodes.contagionPath, throughTier: 4),
      );
      final alive = game.enemies.where((e) => !e.isDead).toList();
      game.debugInfect(0, alive.first);
      for (var i = 0; i < 60 * 20; i++) {
        game.update(1 / 60);
      }
      for (final e in game.enemies) {
        expect(
          e.maskInfectionGeneration,
          lessThanOrEqualTo(MaskTuning.maxGenerations + 1),
          reason: 'an infection walked past its generation ceiling',
        );
      }
    });
  });

  test('an infection that kills a splitter does not trip over its shards', () async {
    // The infection walks the enemy list and damages as it goes; a splitter
    // it kills adds shards to that list mid-walk (2026-10-20: a real run
    // threw "concurrent modification during iteration" here).
    final game = await arena(
      snapshot: equip(MaskNodes.contagionPath, throughTier: 4),
    );
    final at = game.enemies.firstWhere((e) => !e.isDead).position;
    final splitters = [
      for (var i = 0; i < 6; i++)
        CosmicSurvivalEnemy(
          position: at + Offset(i * 4.0, 0),
          hp: 1,
          maxHp: 1,
          speed: 0,
          damage: 0,
          radius: 11,
          tier: EnemyTier.drone,
          element: 'Ice',
          target: CosmicEnemyTarget.orb,
          conduct: EnemyConduct.stalk,
          trait: EnemyTrait.splitter,
        ),
    ];
    game.enemies.addAll(splitters);
    expect(game.enemies.length, lessThan(220));
    for (final e in splitters) {
      game.debugInfect(0, e);
    }
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    expect(splitters.every((e) => e.isDead), isTrue);
  });

  group('the chain that cost 2.2 seconds cannot come back', () {
    test('fixtures do not grow without bound while everything dies', () async {
      // Deathmask and Contagion together: kills leave traps, traps infect,
      // infected deaths burst and infect more. This is the exact shape of
      // the bug, so the arena runs it hot and watches the object count.
      final game = await arena(
        snapshot: equip(MaskNodes.deathmaskPath, throughTier: 4),
      );
      final comp = game.activeCompanions[0]!;

      var peak = 0;
      for (var round = 0; round < 60; round++) {
        for (final enemy in List<CosmicSurvivalEnemy>.of(game.enemies)) {
          if (!enemy.isDead) game.debugKillByDart(0, enemy);
        }
        for (var i = 0; i < 20; i++) {
          comp.specialCooldown = 99999;
          game.update(1 / 60);
        }
        peak = max(peak, game.companionProjectiles.length);
      }
      // A doubling chain reaches thousands within a second or two. A bounded
      // one sits near the cap plus whatever the spawner is doing.
      expect(
        peak,
        lessThan(400),
        reason: 'companion projectiles ran away: $peak',
      );
    });
  });
}
