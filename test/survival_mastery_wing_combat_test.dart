import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_wing.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wing's three paths, driven through the real game.
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

  group('Burn Through builds on a held target', () {
    test('dwell accumulates under a beam and decays off it', () async {
      final game = await arena(
        snapshot: equip(WingNodes.burnThroughPath, throughTier: 1),
      );
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;

      var peak = 0.0;
      for (var i = 0; i < 60 * 12; i++) {
        game.update(1 / 60);
        for (final e in game.enemies) {
          if (e.wingBeamDwell > peak) peak = e.wingBeamDwell;
        }
      }
      expect(peak, greaterThan(0), reason: 'no body ever took beam dwell');
    });

    test('an unequipped Wing earns no ramp', () async {
      final game = await arena();
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;
      for (var i = 0; i < 60 * 8; i++) {
        game.update(1 / 60);
      }
      // Dwell is only counted for a mastery Wing.
      expect(game.enemies.every((e) => e.wingBeamDwell == 0), isTrue);
    });
  });

  group('Longshot pays for the distance kept', () {
    test('the range nodes actually widen the attack range', () async {
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
      expect(
        long.debugAttackRangeMultiplier(0),
        greaterThan(plain.debugAttackRangeMultiplier(0)),
      );
      expect(
        long.debugAttackRangeMultiplier(0),
        closeTo(WingTuning.longLensRange * WingTuning.horizonRange, 0.001),
      );
    });
  });

  group('Tracer turns shots into beam time', () {
    test('landed attacks shave the special and bank beam time', () async {
      final game = await arena(
        snapshot: equip(WingNodes.tracerPath, throughTier: 2),
      );
      final comp = game.activeCompanions[0]!;
      // Hold the special out of reach so only Tracer moves the cooldown.
      comp.specialCooldown = 30;
      var banked = 0.0;
      for (var i = 0; i < 60 * 10; i++) {
        game.update(1 / 60);
        banked = max(banked, game.wingMasteryFor(0)?.bankedBeamTime ?? 0);
      }
      expect(comp.specialCooldown, lessThan(30));
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
      expect(game.wingMasteryFor(0)?.bankedBeamTime ?? 0, lessThan(
        WingTuning.rangingCap,
      ));
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
  });
}
