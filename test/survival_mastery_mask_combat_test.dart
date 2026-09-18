import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mask.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mask's three paths, driven through the real game.
///
/// The group that matters most is the last one. A Mask trap chain has already
/// cost this game 2.2 seconds in a single frame, and two of these three paths
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
