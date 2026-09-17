import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_pip.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pip's three paths. The family throws three fast darts, and each path is a
/// different answer to where those darts go: all into one body, one into each
/// of three, or more of them loaded into the special.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember pip(String element, {int slotIndex = 0}) =>
      CosmicPartyMember(
        instanceId: 'pip-$slotIndex',
        baseId: 'PIP01',
        displayName: 'Pip $element',
        family: 'Pip',
        element: element,
        level: 10,
        slotIndex: slotIndex,
        statSpeed: 4.25,
        statIntelligence: 4.25,
        statStrength: 4.25,
        statBeauty: 4.31,
        statSpeedPotential: 50,
        statIntelligencePotential: 50,
        statStrengthPotential: 50,
        statBeautyPotential: 50,
        staminaBars: 3,
        staminaMax: 3,
      );

  SurvivalFamilyMasterySnapshot equip(String pathId, {int throughTier = 4}) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.pip, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'pip-0',
        family: CreatureFamily.pip,
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
      party: [pip(element)],
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

  /// One volley, left in flight.
  List<Projectile> castVolley(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy target, {
    double gap = 150,
  }) {
    final comp = game.activeCompanions[0]!;
    comp.position = target.position - Offset(gap, 0);
    comp.basicCooldown = 0;
    comp.specialCooldown = 99999;
    game.companionProjectiles.clear();
    game.update(1 / 60);
    return game.companionProjectiles
        .where((p) => p.sourceSlotIndex == 0)
        .toList();
  }

  /// Fires a volley and flies it into the body.
  void landVolley(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy target, {
    double gap = 45,
  }) {
    castVolley(game, target, gap: gap);
    final comp = game.activeCompanions[0]!;
    comp.basicCooldown = 99999;
    for (var i = 0; i < 40; i++) {
      comp.basicCooldown = 99999;
      comp.specialCooldown = 99999;
      game.update(1 / 60);
    }
  }

  group('the chassis and its two re-cuts', () {
    test('an unequipped Pip throws the untouched three darts', () async {
      final (game, target) = await arena();
      final darts = castVolley(game, target);
      expect(darts, hasLength(PipTuning.baseDartCount));
      expect(darts.every((d) => d.masteryCastId == 0), isTrue);
      expect(darts.every((d) => !d.homing), isTrue);
    });

    test('Tight Grouping narrows the fan and sharpens each dart', () async {
      final (bare, bareTarget) = await arena();
      final loose = castVolley(bare, bareTarget);
      final looseSpread = (loose.first.angle - loose.last.angle).abs();

      final (game, target) = await arena(
        snapshot: equip(PipNodes.needlepointPath, throughTier: 1),
      );
      final tight = castVolley(game, target);
      final tightSpread = (tight.first.angle - tight.last.angle).abs();

      expect(tight, hasLength(PipTuning.baseDartCount));
      expect(tightSpread, lessThan(looseSpread));
      expect(tight.first.damage, greaterThan(loose.first.damage));
    });

    test(
      'Wide Spray widens the fan and each dart seeks its own body',
      () async {
        final (bare, bareTarget) = await arena();
        final loose = castVolley(bare, bareTarget);
        final looseSpread = (loose.first.angle - loose.last.angle).abs();

        final (game, target) = await arena(
          snapshot: equip(PipNodes.scattershotPath, throughTier: 1),
        );
        final wide = castVolley(game, target);
        final wideSpread = (wide.first.angle - wide.last.angle).abs();

        expect(wideSpread, greaterThan(looseSpread));
        expect(
          wide.every((d) => d.homing),
          isTrue,
          reason: 'Darts that spread without seeking would simply miss.',
        );
      },
    );

    test('Fourth Barrel adds a dart to the ordinary volley', () async {
      final (game, target) = await arena(
        snapshot: equip(PipNodes.scattershotPath, throughTier: 3),
      );
      expect(castVolley(game, target), hasLength(PipTuning.baseDartCount + 1));
    });
  });

  group('Needlepoint', () {
    test('a full volley banks a Pin, and only one per volley', () async {
      final (game, target) = await arena(
        snapshot: equip(PipNodes.needlepointPath, throughTier: 2),
      );
      landVolley(game, target);
      final state = game.pipMasteryFor(0)!;
      expect(
        state.pinsOn(identityHashCode(target)),
        1,
        reason: 'Three darts on one body is one Pin, not three.',
      );

      landVolley(game, target);
      expect(state.pinsOn(identityHashCode(target)), 2);
    });

    test('Pins stop at five', () async {
      final (game, target) = await arena(
        snapshot: equip(PipNodes.needlepointPath, throughTier: 2),
      );
      for (var i = 0; i < 9; i++) {
        landVolley(game, target);
      }
      expect(
        game.pipMasteryFor(0)!.pinsOn(identityHashCode(target)),
        PipTuning.maxPins,
      );
    });

    test('Pluck the Pins spends a full set for a burst', () async {
      final (game, target) = await arena(
        snapshot: equip(PipNodes.needlepointPath, throughTier: 3),
      );
      for (var i = 0; i < 12; i++) {
        landVolley(game, target);
        final state = game.pipMasteryFor(0);
        if (state != null &&
            state.pinsOn(identityHashCode(target)) == 0 &&
            game.mastery.telemetryFor(0).masteryDamage > 0) {
          break;
        }
      }
      final state = game.pipMasteryFor(0)!;
      expect(
        game.mastery.telemetryFor(0).masteryDamage,
        greaterThan(0),
        reason: 'A full set of Pins should have detonated by now.',
      );
      expect(
        state.pinsOn(identityHashCode(target)),
        lessThan(PipTuning.maxPins),
      );
    });

    test('a boss keeps a residue so the loop can restart', () {
      final state = PipMasteryState();
      for (var i = 0; i < PipTuning.maxPins; i++) {
        state.addPin(7, 0);
      }
      expect(
        state.spendPins(7, isBoss: true),
        PipTuning.maxPins - PipTuning.pluckBossResidue,
      );
      expect(state.pinsOn(7), PipTuning.pluckBossResidue);

      for (var i = 0; i < PipTuning.maxPins; i++) {
        state.addPin(8, 0);
      }
      expect(state.spendPins(8, isBoss: false), PipTuning.maxPins);
      expect(state.pinsOn(8), 0);
    });

    test('Pins lapse on a body the Pip has stopped shooting', () {
      final state = PipMasteryState()..addPin(3, 0);
      expect(state.pinsOn(3), 1);
      state.expirePins(PipTuning.pinLifetime + 0.1);
      expect(state.pinsOn(3), 0);
    });

    test('Thousand Cuts throws a bonus volley that cannot bank Pins', () async {
      final (game, target) = await arena(
        snapshot: equip(PipNodes.needlepointPath),
      );
      for (var i = 0; i < PipTuning.thousandCutsCadence; i++) {
        landVolley(game, target);
      }
      // Let the queued beat come due.
      final comp = game.activeCompanions[0]!;
      for (var i = 0; i < 30; i++) {
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      expect(
        game.mastery.telemetryFor(0).capstoneActivations,
        greaterThan(0),
        reason: 'Four full volleys should have earned a bonus one.',
      );
    });
  });

  group('Scattershot', () {
    test('Three Fronts pays only when the darts split up', () async {
      final (game, target) = await arena(
        snapshot: equip(PipNodes.scattershotPath, throughTier: 2),
      );
      // All three into one body: the split bonus must not fire.
      landVolley(game, target);
      expect(game.mastery.telemetryFor(0).masteryDamage, 0);
    });

    test(
      'Scatter Storm fires on the fifth attack and is not a fifth cast',
      () async {
        final (game, target) = await arena(
          snapshot: equip(PipNodes.scattershotPath),
        );
        for (var i = 0; i < PipTuning.scatterStormCadence - 1; i++) {
          castVolley(game, target, gap: 150);
        }
        expect(
          game.companionProjectiles.where((p) => p.masteryGenerated),
          isEmpty,
          reason: 'Four attacks is not yet a storm.',
        );

        castVolley(game, target, gap: 150);
        final storm = game.companionProjectiles
            .where((p) => p.masteryGenerated)
            .toList();
        expect(storm, hasLength(PipTuning.scatterStormDarts));
        expect(storm.every((d) => d.homing), isTrue);
        expect(
          game.mastery.telemetryFor(0).basicCasts,
          PipTuning.scatterStormCadence,
          reason: 'The storm is the capstone firing, not another attack.',
        );
      },
    );
  });

  group('Salvo', () {
    int specialDarts(CosmicSurvivalGame game, CosmicSurvivalEnemy target) {
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(150, 0);
      comp.basicCooldown = 99999;
      comp.specialCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      comp.specialCooldown = 99999;
      return game.companionProjectiles
          .where((p) => p.sourceSlotIndex == 0)
          .length;
    }

    test('each node loads one more dart into the special', () async {
      final counts = <int>[];
      for (final tier in [0, 1, 2, 3, 4]) {
        final (game, target) = await arena(
          element: 'Ice',
          snapshot: tier == 0
              ? null
              : equip(PipNodes.salvoPath, throughTier: tier),
        );
        counts.add(specialDarts(game, target));
      }
      for (var i = 1; i < counts.length; i++) {
        expect(
          counts[i],
          counts[i - 1] + PipTuning.salvoDartsPerNode,
          reason: 'Salvo tier $i did not add a dart: $counts',
        );
      }
      expect(counts.last, counts.first + 4);
    });

    test('the extras are lighter until the capstone lifts them', () async {
      final (three, threeTarget) = await arena(
        element: 'Ice',
        snapshot: equip(PipNodes.salvoPath, throughTier: 3),
      );
      specialDarts(three, threeTarget);
      final beforeCapstone = three.companionProjectiles
          .where((p) => p.masteryGenerated)
          .map((p) => p.damage)
          .toList();
      final authored = three.companionProjectiles
          .where((p) => !p.masteryGenerated && p.sourceSlotIndex == 0)
          .map((p) => p.damage)
          .toList();
      expect(beforeCapstone, isNotEmpty);
      expect(authored, isNotEmpty);
      expect(
        beforeCapstone.first,
        lessThan(authored.first),
        reason: 'Before the capstone the extras hit at 70%.',
      );

      final (four, fourTarget) = await arena(
        element: 'Ice',
        snapshot: equip(PipNodes.salvoPath),
      );
      specialDarts(four, fourTarget);
      final afterCapstone = four.companionProjectiles
          .where((p) => p.masteryGenerated)
          .map((p) => p.damage)
          .toList();
      final authoredAfter = four.companionProjectiles
          .where((p) => !p.masteryGenerated && p.sourceSlotIndex == 0)
          .map((p) => p.damage)
          .toList();
      expect(
        afterCapstone.first,
        closeTo(authoredAfter.first, 0.01),
        reason: 'The capstone brings every extra up to full strength.',
      );
    });

    test('an extra dart is the element\'s own dart, not a plain one', () async {
      final (game, target) = await arena(
        element: 'Lightning',
        snapshot: equip(PipNodes.salvoPath),
      );
      specialDarts(game, target);
      final extras = game.companionProjectiles
          .where((p) => p.masteryGenerated)
          .toList();
      final authored = game.companionProjectiles
          .where((p) => !p.masteryGenerated && p.sourceSlotIndex == 0)
          .toList();
      expect(extras, isNotEmpty);
      expect(authored, isNotEmpty);
      // Lightning's identity is its bounce count; a copied dart keeps it.
      expect(extras.first.bounceCount, authored.first.bounceCount);
      expect(extras.first.abilityFamily, authored.first.abilityFamily);
    });

    test('Salvo gives a Dark Pip nothing, because it has no cast', () async {
      final (game, target) = await arena(
        element: 'Dark',
        snapshot: equip(PipNodes.salvoPath),
      );
      expect(specialDarts(game, target), 0);
      expect(game.mastery.telemetryFor(0).specialCasts, 0);
    });
  });

  group('the paths do not borrow an element\'s identity', () {
    test('no Pip node ricochets, freezes, pushes or hastes', () {
      final tree = FamilyMasteryCatalog.treeFor(CreatureFamily.pip);
      const claimed = [
        'ricochet',
        'bounce',
        'freeze',
        'frozen',
        'push',
        'knock',
        'attack speed',
        'slow',
        'burn',
        'poison',
        'heal',
        'taunt',
      ];
      for (final path in tree.paths) {
        for (final node in path.nodes) {
          final text = node.description.toLowerCase();
          for (final word in claimed) {
            expect(
              text.contains(word),
              isFalse,
              reason:
                  '${node.id} says "$word", which belongs to an element. '
                  'A path that hands it to every Pip erases that element.',
            );
          }
        }
      }
    });
  });
}
