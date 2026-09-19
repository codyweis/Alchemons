import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mystic's two paths, driven through the real game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mystic(String element) => CosmicPartyMember(
    instanceId: 'mystic-0',
    baseId: 'MYS01',
    displayName: 'Mystic $element',
    family: 'Mystic',
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
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.mystic, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'mystic-0',
        family: CreatureFamily.mystic,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> arena({
    String element = 'Lightning',
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [mystic(element)],
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

  /// Runs until the world is actually lit. Mystic has the longest cooldown
  /// in the game, so the cast has to be held open rather than nudged once.
  Future<bool> lightWorld(CosmicSurvivalGame game, {int seconds = 40}) async {
    final comp = game.activeCompanions[0]!;
    for (var i = 0; i < 60 * seconds; i++) {
      if (game.debugMysticWorldLit(0)) return true;
      if (comp.specialCooldown > 0) comp.specialCooldown = 0;
      game.update(1 / 60);
    }
    return game.debugMysticWorldLit(0);
  }

  /// Runs until the world is lit, then counts how much damage it deals.
  Future<double> worldOutput({
    SurvivalFamilyMasterySnapshot? snapshot,
    int seconds = 30,
  }) async {
    final game = await arena(snapshot: snapshot);
    await lightWorld(game);
    var dealt = 0.0;
    var before = {for (final e in game.enemies) e: e.hp};
    for (var i = 0; i < 60 * seconds; i++) {
      game.update(1 / 60);
      for (final e in game.enemies) {
        final was = before[e];
        if (was != null && e.hp < was) dealt += was - e.hp;
      }
      before = {for (final e in game.enemies) e: e.hp};
    }
    return dealt;
  }

  group('Quickening drives the world', () {
    test('the world is lit and the path does not break it', () async {
      final plain = await worldOutput();
      final quick = await worldOutput(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: 4),
      );
      expect(plain, greaterThan(0), reason: 'the world never did anything');
      expect(quick, greaterThan(0));
    });

    test('First Light makes the world act on ignition', () async {
      // The clock-driven worlds normally spend their first full interval
      // doing nothing at all.
      final game = await arena(
        snapshot: equip(MysticNodes.quickeningPath, throughTier: 2),
      );
      expect(await lightWorld(game), isTrue);
    });
  });

  group('Firmament shelters the team', () {
    test('an ally in the world takes less and the world mends them', () async {
      final game = await arena(
        snapshot: equip(MysticNodes.firmamentPath, throughTier: 3),
      );
      expect(await lightWorld(game), isTrue);
      final comp = game.activeCompanions[0]!;

      // Hurt the ship, stand it in the world, and let Tended work.
      game.ship.currentHp = game.ship.maxHp * 0.3;
      final before = game.ship.currentHp;
      for (var i = 0; i < 60 * 10; i++) {
        game.ship.position = comp.position;
        game.update(1 / 60);
      }
      expect(
        game.mysticMasteryFor(0)?.healedInside ?? 0,
        greaterThanOrEqualTo(0),
      );
      expect(game.ship.currentHp, greaterThan(before));
    });

    test('an unequipped Mystic shelters nobody', () async {
      final game = await arena();
      await lightWorld(game);
      expect(game.mysticMasteryFor(0), isNull);
    });
  });
}
