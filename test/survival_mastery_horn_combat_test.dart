import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_horn.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Horn's two paths, driven through the real game rather than the resolvers.
///
/// Horn is the family whose cast pattern changes with its element — a charge,
/// a wind-up, an always-on passive, or a stationary channel — so the tests
/// that matter most here are the ones that check a path still pays for the
/// elements that never charge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember horn(String element) => CosmicPartyMember(
    instanceId: 'horn-0',
    baseId: 'HRN01',
    displayName: 'Horn $element',
    family: 'Horn',
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
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.horn, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'horn-0',
        family: CreatureFamily.horn,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  CosmicSurvivalEnemy dummy(
    CosmicSurvivalEnemy template,
    Offset at, {
    double hp = 1000000,
  }) => CosmicSurvivalEnemy(
    position: at,
    hp: hp,
    maxHp: 1000000,
    speed: 0,
    damage: 0,
    radius: 14,
    tier: template.tier,
    element: template.element,
    conduct: template.conduct,
    target: template.target,
  );

  Future<(CosmicSurvivalGame, CosmicSurvivalEnemy)> arena({
    String element = 'Fire',
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [horn(element)],
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
    final template = game.enemies.first;
    for (final e in game.enemies) {
      e.isDead = true;
    }
    final target = dummy(template, game.orb.position + const Offset(300, 0));
    game.enemies.add(target);
    return (game, target);
  }

  /// Damage one auto-attack lands on [target], with the special held off.
  Future<double> autoAttackDamage({
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final (game, target) = await arena(snapshot: snapshot);
    final comp = game.activeCompanions[0]!;
    comp.position = target.position - const Offset(120, 0);
    comp.specialCooldown = 99999;
    comp.basicCooldown = 0;
    final before = target.hp;
    for (var i = 0; i < 240 && target.hp == before; i++) {
      comp.specialCooldown = 99999;
      game.update(1 / 60);
    }
    return before - target.hp;
  }

  group('Bulwark turns bulk into damage', () {
    test('a Horn holding Ironhead hits harder than one without', () async {
      final plain = await autoAttackDamage();
      final bulwark = await autoAttackDamage(
        snapshot: equip(HornNodes.bulwarkPath, throughTier: 1),
      );
      expect(plain, greaterThan(0));
      expect(bulwark, greaterThan(plain));
    });

    test('the weight goes into the charge once, not once per body', () async {
      final (game, target) = await arena(
        snapshot: equip(HornNodes.bulwarkPath, throughTier: 2),
      );
      final comp = game.activeCompanions[0]!;

      // Bulwark's special share is a fixed 60% of 2.5% of max HP, folded in
      // at cast. A charge that ploughs through six bodies must not add a
      // Horn's whole bulk six times — that is how a tank path quietly
      // becomes the best damage path in the game.
      comp.position = target.position - const Offset(120, 0);
      comp.specialCooldown = 0;
      final expected =
          comp.maxHp *
          HornTuning.ironheadMaxHpFraction *
          HornTuning.specialWeightScale;
      for (var i = 0; i < 300 && comp.chargeDamage == 0; i++) {
        game.update(1 / 60);
      }
      expect(comp.chargeDamage, greaterThan(0));

      final baseline = comp.chargeDamage - expected;
      expect(baseline, greaterThan(0), reason: 'the weight swallowed the cast');

      // Run the charge out; the banked damage must not grow per contact.
      final atCast = comp.chargeDamage;
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      expect(comp.chargeDamage, lessThanOrEqualTo(atCast));
    });
  });

  group('Bastion takes the hits', () {
    test('attacking banks a shield toward its ceiling', () async {
      final (game, target) = await arena(
        snapshot: equip(HornNodes.bastionPath, throughTier: 1),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);

      for (var i = 0; i < 600; i++) {
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      final state = game.hornMasteryFor(0)!;
      expect(state.guardShield, greaterThan(0));
      expect(
        state.guardShield,
        lessThanOrEqualTo(comp.maxHp * HornTuning.guardCap + 0.001),
      );
    });

    test('the orb takes less while a Bastion stands near it', () async {
      Future<double> orbLoss({SurvivalFamilyMasterySnapshot? snapshot}) async {
        final (game, _) = await arena(snapshot: snapshot);
        final comp = game.activeCompanions[0]!;
        comp.position = game.orb.position + const Offset(40, 0);
        game.orb.shieldHp = 0;
        final before = game.orb.currentHp;
        game.debugDamageOrb(400);
        return before - game.orb.currentHp;
      }

      final plain = await orbLoss();
      final guarded = await orbLoss(
        snapshot: equip(HornNodes.bastionPath, throughTier: 2),
      );
      expect(plain, closeTo(400, 1));
      expect(guarded, lessThan(plain));
    });

    test('a Bastion out of position guards nothing', () async {
      final (game, _) = await arena(
        snapshot: equip(HornNodes.bastionPath, throughTier: 2),
      );
      final comp = game.activeCompanions[0]!;
      comp.position =
          game.orb.position + const Offset(HornTuning.bodyguardRange + 50, 0);
      game.orb.shieldHp = 0;
      final before = game.orb.currentHp;
      game.debugDamageOrb(400);
      expect(before - game.orb.currentHp, closeTo(400, 1));
    });
  });
}
