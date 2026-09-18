import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_kin.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kin's three paths, driven through the real game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember kin(String element, {int slotIndex = 0}) =>
      CosmicPartyMember(
        instanceId: 'kin-$slotIndex',
        baseId: 'KIN01',
        displayName: 'Kin $element',
        family: 'Kin',
        element: element,
        level: 10,
        slotIndex: slotIndex,
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
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.kin, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'kin-0',
        family: CreatureFamily.kin,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> arena({
    String element = 'Dark',
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [kin(element)],
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

  group('Longline reaches further', () {
    test('the fired laser is longer with the path than without', () async {
      Future<double> longestBeam({
        SurvivalFamilyMasterySnapshot? snapshot,
      }) async {
        final game = await arena(snapshot: snapshot);
        final comp = game.activeCompanions[0]!;
        var longest = 0.0;
        for (var i = 0; i < 60 * 20; i++) {
          comp.specialCooldown = 99999;
          game.update(1 / 60);
          for (final beam in game.debugKinLaserLengths) {
            if (beam > longest) longest = beam;
          }
        }
        return longest;
      }

      final plain = await longestBeam();
      final long = await longestBeam(
        snapshot: equip(KinNodes.longlinePath, throughTier: 2),
      );
      expect(plain, greaterThan(0), reason: 'the Kin never fired');
      expect(long, greaterThan(plain));
    });
  });

  group('Conduction helps what the line crosses', () {
    test('the ship on the line is healed by a Lifeline Kin', () async {
      Future<double> shipRecovery({
        SurvivalFamilyMasterySnapshot? snapshot,
      }) async {
        final game = await arena(snapshot: snapshot);
        final caster = game.activeCompanions[0]!;
        game.ship.currentHp = game.ship.maxHp * 0.2;
        var gained = 0.0;
        for (var i = 0; i < 60 * 25; i++) {
          caster.specialCooldown = 99999;
          // Stand the ship between the Kin and whatever it is shooting.
          final target = game.enemies.firstWhere(
            (e) => !e.isDead,
            orElse: () => game.enemies.first,
          );
          final dir = target.position - caster.position;
          final len = dir.distance;
          if (len > 1) game.ship.position = caster.position + dir / len * 60;
          final before = game.ship.currentHp;
          game.update(1 / 60);
          final delta = game.ship.currentHp - before;
          if (delta > 0) gained += delta;
        }
        return gained;
      }

      final plain = await shipRecovery();
      final conducted = await shipRecovery(
        snapshot: equip(KinNodes.conductionPath, throughTier: 2),
      );
      expect(conducted, greaterThan(plain));
    });

    test('an unequipped Kin gives the line nothing', () async {
      final game = await arena();
      for (var i = 0; i < 60 * 15; i++) {
        game.update(1 / 60);
      }
      expect(game.kinMasteryFor(0)?.shieldGranted ?? 0, 0);
    });
  });

  group('Benediction deepens the support', () {
    test('Devotion stretches the support window', () async {
      Future<double> cloak({SurvivalFamilyMasterySnapshot? snapshot}) async {
        final game = await arena(snapshot: snapshot);
        final comp = game.activeCompanions[0]!;
        comp.specialCooldown = 0;
        var peak = 0.0;
        for (var i = 0; i < 60 * 12; i++) {
          game.update(1 / 60);
          peak = max(peak, comp.kinDarkCloakTimer);
        }
        return peak;
      }

      final plain = await cloak();
      final devoted = await cloak(
        snapshot: equip(KinNodes.benedictionPath, throughTier: 1),
      );
      expect(plain, greaterThan(0), reason: 'the Dark cloak never went up');
      expect(devoted, greaterThan(plain));
      expect(devoted / plain, closeTo(KinTuning.devotionDuration, 0.05));
    });

    test('Unbroken keeps a downed Kin\'s support running', () async {
      final game = await arena(
        snapshot: equip(KinNodes.benedictionPath, throughTier: 3),
      );
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;
      for (var i = 0; i < 60 * 12 && comp.kinDarkCloakTimer <= 0; i++) {
        game.update(1 / 60);
      }
      expect(comp.kinDarkCloakTimer, greaterThan(0));

      // Down the Kin; the cloak must keep ticking down rather than freezing
      // or being abandoned.
      comp.isDead = true;
      final before = comp.kinDarkCloakTimer;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(
        comp.kinDarkCloakTimer,
        lessThan(before),
        reason: 'the support stopped running when the Kin went down',
      );
    });
  });
}
