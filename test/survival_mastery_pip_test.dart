import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_pip.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pip's two paths. The family throws three fast darts, and each path is a
/// different answer to where those darts go: one into each of three bodies,
/// or more of them loaded into the special — thrown a beat late as a second
/// volley, and fanned wide across the crowd.
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

  group('the chassis and its re-cut', () {
    test('an unequipped Pip throws the untouched three darts', () async {
      final (game, target) = await arena();
      final darts = castVolley(game, target);
      expect(darts, hasLength(PipTuning.baseDartCount));
      expect(darts.every((d) => d.masteryCastId == 0), isTrue);
      expect(darts.every((d) => !d.homing), isTrue);
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
    /// One special, thrown at [target] from 150 to its left, then the
    /// frames a Second Volley needs to come due. Each dart is read (copied)
    /// the frame it first appears, before it has flown or struck anything.
    ({
      List<Projectile> authored,
      List<Projectile> extras,
      int extrasAtCast,
      int pendingAtCast,
      Offset pipAt,
    })
    throwSpecial(
      CosmicSurvivalGame game,
      CosmicSurvivalEnemy target, {
      void Function()? afterCast,
    }) {
      final comp = game.activeCompanions[0]!;
      final pipAt = target.position - const Offset(150, 0);
      comp.position = pipAt;
      comp.basicCooldown = 99999;
      comp.specialCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      comp.specialCooldown = 99999;
      final seen = <Projectile>{};
      final authored = <Projectile>[];
      final extras = <Projectile>[];
      for (final p in game.companionProjectiles) {
        if (p.sourceSlotIndex != 0 || !seen.add(p)) continue;
        final copy = copyProjectile(p)
          ..homingRescanTimer = p.homingRescanTimer;
        (p.masteryGenerated ? extras : authored).add(copy);
      }
      final extrasAtCast = extras.length;
      final pendingAtCast = game.pipSecondVolleyDartsPending;
      afterCast?.call();
      for (var i = 0; i < 30; i++) {
        final pip = game.activeCompanions[0];
        if (pip != null) {
          pip.position = pipAt;
          pip.basicCooldown = 99999;
          pip.specialCooldown = 99999;
        }
        game.update(1 / 60);
        for (final p in game.companionProjectiles) {
          if (!p.masteryGenerated || p.sourceSlotIndex != 0) continue;
          if (seen.add(p)) {
            extras.add(
              copyProjectile(p)..homingRescanTimer = p.homingRescanTimer,
            );
          }
        }
      }
      return (
        authored: authored,
        extras: extras,
        extrasAtCast: extrasAtCast,
        pendingAtCast: pendingAtCast,
        pipAt: pipAt,
      );
    }

    /// How far each extra left from the line to [aimAt], in radians.
    List<double> offsets(List<Projectile> extras, Offset from, Offset aimAt) {
      final aim = atan2(aimAt.dy - from.dy, aimAt.dx - from.dx);
      return [
        for (final p in extras) atan2(sin(p.angle - aim), cos(p.angle - aim)),
      ];
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
        final thrown = throwSpecial(game, target);
        counts.add(thrown.authored.length + thrown.extras.length);
        expect(game.pipSecondVolleyDartsPending, 0);
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
      final before = throwSpecial(three, threeTarget);
      expect(before.extras, isNotEmpty);
      expect(before.authored, isNotEmpty);
      expect(
        before.extras.first.damage,
        closeTo(
          before.authored.first.damage * PipTuning.salvoExtraFraction,
          0.01,
        ),
        reason: 'Before the capstone the extras hit at 60%.',
      );

      final (four, fourTarget) = await arena(
        element: 'Ice',
        snapshot: equip(PipNodes.salvoPath),
      );
      final after = throwSpecial(four, fourTarget);
      expect(
        after.extras.first.damage,
        closeTo(
          after.authored.first.damage * PipTuning.salvoPerfectFraction,
          0.01,
        ),
        reason: 'The capstone brings every extra up to 75%.',
      );
    });

    test('an extra dart is the element\'s own dart, not a plain one', () async {
      final (game, target) = await arena(
        element: 'Lightning',
        snapshot: equip(PipNodes.salvoPath),
      );
      final thrown = throwSpecial(game, target);
      expect(thrown.extras, isNotEmpty);
      expect(thrown.authored, isNotEmpty);
      // Lightning's identity is its bounce count; a copied dart keeps it.
      expect(
        thrown.extras.first.bounceCount,
        thrown.authored.first.bounceCount,
      );
      expect(
        thrown.extras.first.abilityFamily,
        thrown.authored.first.abilityFamily,
      );
    });

    test('a Dark Pip throws no special for Salvo to load', () async {
      // Its hole is loaded instead (survival_family_audit_fixes_2_test).
      final (game, target) = await arena(
        element: 'Dark',
        snapshot: equip(PipNodes.salvoPath),
      );
      final thrown = throwSpecial(game, target);
      expect(thrown.authored, isEmpty);
      expect(thrown.extras, isEmpty);
      expect(game.mastery.telemetryFor(0).specialCasts, 0);
    });

    group('Second Volley', () {
      test('before it, the extra dart leaves with the special', () async {
        final (game, target) = await arena(
          element: 'Ice',
          snapshot: equip(PipNodes.salvoPath, throughTier: 1),
        );
        final thrown = throwSpecial(game, target);
        expect(thrown.extrasAtCast, 1);
        expect(thrown.pendingAtCast, 0);
      });

      test(
        'the extras are held back, then thrown a beat later at the target',
        () async {
          final (game, target) = await arena(
            element: 'Ice',
            snapshot: equip(PipNodes.salvoPath, throughTier: 2),
          );
          final thrown = throwSpecial(game, target);
          expect(thrown.extrasAtCast, 0, reason: 'they left with the special');
          expect(thrown.pendingAtCast, 2);
          expect(thrown.extras, hasLength(2), reason: 'never thrown');
          for (final o in offsets(
            thrown.extras,
            thrown.pipAt,
            target.position,
          )) {
            expect(o.abs(), lessThan(0.4), reason: 'thrown off the target');
          }
        },
      );

      test(
        'a target the special killed hands the volley to the nearest body',
        () async {
          final (game, target) = await arena(
            element: 'Ice',
            snapshot: equip(PipNodes.salvoPath, throughTier: 2),
          );
          late CosmicSurvivalEnemy next;
          final thrown = throwSpecial(
            game,
            target,
            afterCast: () {
              target.isDead = true;
              final pipAt = game.activeCompanions[0]!.position;
              next = dummy(target, pipAt + const Offset(0, 200));
              game.enemies.add(next);
            },
          );
          expect(thrown.extras, hasLength(2));
          for (final o in offsets(thrown.extras, thrown.pipAt, next.position)) {
            expect(o.abs(), lessThan(0.4), reason: 'not at the next body');
          }
        },
      );

      test('a Pip lost before the beat throws nothing', () async {
        final (game, target) = await arena(
          element: 'Ice',
          snapshot: equip(PipNodes.salvoPath, throughTier: 2),
        );
        final thrown = throwSpecial(
          game,
          target,
          afterCast: () => game.activeCompanions[0]!.isDead = true,
        );
        expect(thrown.pendingAtCast, 2);
        expect(thrown.extras, isEmpty);
        expect(game.pipSecondVolleyDartsPending, 0);
      });
    });

    group('Wide Load', () {
      test('the extras leave both flanks, wider than the volley', () async {
        Future<List<double>> fan(int tier) async {
          final (game, target) = await arena(
            element: 'Ice',
            snapshot: equip(PipNodes.salvoPath, throughTier: tier),
          );
          final thrown = throwSpecial(game, target);
          expect(thrown.extras, hasLength(tier));
          return offsets(thrown.extras, thrown.pipAt, target.position);
        }

        double reach(List<double> o) => o.map((v) => v.abs()).reduce(max);
        final narrow = await fan(2);
        final wide = await fan(3);
        final widest = await fan(4);
        // Without Wide Load the extras carry the fan on past one edge.
        expect(
          narrow.every((o) => o > 0) || narrow.every((o) => o < 0),
          isTrue,
          reason: '$narrow',
        );
        expect(
          wide.any((o) => o > 0) && wide.any((o) => o < 0),
          isTrue,
          reason: '$wide',
        );
        expect(reach(wide), greaterThan(reach(narrow) * 2));
        expect(
          widest.where((o) => o.abs() >= PipTuning.wideLoadStart - 0.01),
          hasLength(4),
          reason: 'every extra leaves outside the authored volley: $widest',
        );
      });

      test('a fanned dart flies straight before it seeks', () async {
        final (game, target) = await arena(
          element: 'Ice',
          snapshot: equip(PipNodes.salvoPath, throughTier: 3),
        );
        final thrown = throwSpecial(game, target);
        expect(thrown.extras, isNotEmpty);
        for (final p in thrown.extras) {
          expect(p.homingRescanTimer, PipTuning.wideLoadHold);
        }
        final (plain, plainTarget) = await arena(
          element: 'Ice',
          snapshot: equip(PipNodes.salvoPath, throughTier: 2),
        );
        for (final p in throwSpecial(plain, plainTarget).extras) {
          expect(p.homingRescanTimer, 0);
        }
      });

      test('every throwing element fans the same way, rings included', () async {
        // Air's and Light's specials leave as a ring around the Pip, and
        // Steam's do not seek at all; the extras still leave from the aim.
        for (final element in ['Air', 'Light', 'Steam', 'Lava', 'Blood']) {
          final (game, target) = await arena(
            element: element,
            snapshot: equip(PipNodes.salvoPath, throughTier: 3),
          );
          final thrown = throwSpecial(game, target);
          expect(thrown.extras, hasLength(3), reason: element);
          final o = offsets(thrown.extras, thrown.pipAt, target.position);
          expect(
            o.any((v) => v > 0.3) && o.any((v) => v < -0.3),
            isTrue,
            reason: '$element: $o',
          );
        }
      });
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
