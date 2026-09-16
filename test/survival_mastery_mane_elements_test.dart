import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mane.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3 item 2: Mane validated across Fire, Ice, Lightning, Blood and a
/// control-heavy element.
///
/// The exit criterion is that the five feel meaningfully different while
/// sharing one selected path. "Feel" is not testable, but its precondition is:
/// each element has to reach combat through the same nodes and leave a
/// different mark when it does. These tests check the marks are real and that
/// no two of them are the same.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tested = ['Fire', 'Ice', 'Lightning', 'Blood', 'Mud'];

  CosmicPartyMember mane(String element) => CosmicPartyMember(
    instanceId: 'mane',
    baseId: 'MAN01',
    displayName: 'Mane $element',
    family: 'Mane',
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    statSpeedPotential: 80,
    statIntelligencePotential: 80,
    statStrengthPotential: 80,
    statBeautyPotential: 80,
    staminaBars: 3,
    staminaMax: 3,
  );

  SurvivalFamilyMasterySnapshot equip(String pathId) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.mane, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'mane',
        family: CreatureFamily.mane,
        pathId: path.id,
        activeNodeIds: path.nodes.map((n) => n.id),
      ),
    });
  }

  Future<CosmicSurvivalGame> start(String element, String pathId) async {
    final game = CosmicSurvivalGame(
      party: [mane(element)],
      onGameOver: () {},
      masterySnapshot: equip(pathId),
      random: Random(7),
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

  CosmicSurvivalEnemy dummy(CosmicSurvivalGame game, Offset at) {
    final template = game.enemies.first;
    final body = CosmicSurvivalEnemy(
      position: at,
      hp: 500000,
      maxHp: 500000,
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

  /// What one payload of [element] leaves behind, as a comparable fingerprint.
  ///
  /// Taken with a lone body and again with a neighbour, because two elements
  /// that look identical on a single target need not be — Lightning does all
  /// of its work on somebody else.
  Future<Map<String, bool>> fingerprint(
    String element, {
    required bool withNeighbour,
  }) async {
    final game = await start(element, ManeNodes.controlPath);
    for (final e in game.enemies) {
      e.isDead = true;
    }
    final comp = game.activeCompanions[0]!;
    comp.currentHp = (comp.maxHp * 0.5).round();

    final body = dummy(game, comp.position + const Offset(120, 0));
    final neighbour = withNeighbour
        ? dummy(game, body.position + const Offset(40, 0))
        : null;

    // The Mane must not attack through any of this: a second and third Ice
    // payload would freeze the body and clear the very stacks being measured,
    // and stray basics would muddy the damage delta.
    void holdFire() {
      comp.basicCooldown = 9999;
      comp.specialCooldown = 9999;
    }

    // One settling frame before the payload. Enemy lookups go through a
    // spatial grid rebuilt each frame, so a body added since the last update
    // is invisible — which silently made Lightning's arc find nobody.
    holdFire();
    game.update(1 / 60);

    final stats = game.mastery.telemetryFor(0);
    final healedBefore = stats.healing;
    final masteryBefore = stats.masteryDamage;
    final neighbourHpBefore = neighbour?.hp ?? 0;

    expect(
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'validation',
        enemy: body,
        triggeringDamage: 200,
      ),
      isTrue,
      reason: '$element produced no payload at all',
    );
    // Spirit-style delays and damage-over-time need a moment to show.
    for (var i = 0; i < 60; i++) {
      holdFire();
      game.update(1 / 60);
    }

    return {
      'burns': body.masteryDotStacks > 0 || body.masteryDotTimer > 0,
      'chills': body.masteryChillStacks > 0,
      'slows': body.slowTimer > 0,
      'exposes': body.masteryVulnerableTimer > 0,
      'illuminates': body.masteryAmpTimer > 0,
      'hazes': body.masteryHazeTimer > 0,
      'heals': stats.healing > healedBefore,
      'damages': stats.masteryDamage > masteryBefore,
      'reachesNeighbour': neighbour != null && neighbour.hp < neighbourHpBefore,
    };
  }

  group('each tested element leaves its own mark', () {
    test('Fire burns the body it lands on and nothing else', () async {
      final print = await fingerprint('Fire', withNeighbour: true);
      expect(print['burns'], isTrue);
      expect(print['damages'], isTrue);
      expect(print['slows'], isFalse);
      expect(print['heals'], isFalse);
      expect(
        print['reachesNeighbour'],
        isFalse,
        reason: 'A scorch is on one body, not a splash.',
      );
    });

    test('Ice stacks cold rather than dealing damage', () async {
      final print = await fingerprint('Ice', withNeighbour: false);
      expect(print['chills'], isTrue);
      expect(print['slows'], isTrue);
      expect(
        print['damages'],
        isFalse,
        reason: 'Ice pays in control, not in a damage number.',
      );
    });

    test('Lightning does all its work on somebody else', () async {
      final alone = await fingerprint('Lightning', withNeighbour: false);
      expect(
        alone.values.any((v) => v),
        isFalse,
        reason: 'With nothing nearby, an arc has nowhere to go.',
      );

      final crowded = await fingerprint('Lightning', withNeighbour: true);
      expect(crowded['reachesNeighbour'], isTrue);
      expect(crowded['damages'], isTrue);
      expect(crowded['burns'], isFalse);
    });

    test('Mud slows hard and does nothing else', () async {
      final print = await fingerprint('Mud', withNeighbour: true);
      expect(print['slows'], isTrue);
      expect(print['chills'], isFalse);
      expect(print['burns'], isFalse);
      expect(print['damages'], isFalse);
      expect(print['reachesNeighbour'], isFalse);
    });

    test('Blood pays the caster, not the target', () async {
      final print = await fingerprint('Blood', withNeighbour: true);
      expect(print['heals'], isTrue);
      expect(print['damages'], isFalse);
      expect(print['slows'], isFalse);
      expect(print['burns'], isFalse);
    });

    test('no two of the five leave the same mark', () async {
      final prints = <String, String>{};
      for (final element in tested) {
        final print = await fingerprint(element, withNeighbour: true);
        final signature = print.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .join(',');
        for (final seen in prints.entries) {
          if (seen.value != signature) continue;
          fail(
            '$element is indistinguishable from ${seen.key}: '
            'both read as "$signature". Two elements that do the same thing '
            'through the same nodes are one element with two names.',
          );
        }
        prints[element] = signature;
      }
      expect(prints.length, tested.length);
    });
  });

  group('every path drives its element in a real fight', () {
    /// Twenty seconds against a standing crowd, the way a wave actually goes.
    Future<void> expectPathContributes(String pathId, String element) async {
      final game = await start(element, pathId);
      for (final e in game.enemies) {
        e.isDead = true;
      }
      final comp = game.activeCompanions[0]!;
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        dummy(game, comp.position + Offset(cos(a) * 110, sin(a) * 110));
      }
      for (var f = 0; f < 60 * 12; f++) {
        game.update(1 / 60);
      }

      final stats = game.mastery.telemetryFor(0);
      expect(
        stats.basicCasts,
        greaterThan(10),
        reason: '$pathId: the Mane barely attacked; the scenario is wrong',
      );
      expect(
        stats.payloadApplications,
        greaterThan(0),
        reason: '$pathId with $element never got its element into the fight',
      );
      expect(
        stats.masteryShare,
        greaterThan(0.02),
        reason:
            '$pathId contributed ${(stats.masteryShare * 100).toStringAsFixed(1)}% '
            'of its own damage — a path that cannot be measured cannot be tuned',
      );
    }

    test(
      'Twin Fang',
      () => expectPathContributes(ManeNodes.assaultPath, 'Fire'),
    );
    test(
      'Tempest Claw',
      () => expectPathContributes(ManeNodes.controlPath, 'Mud'),
    );
    test(
      'War Rhythm',
      () => expectPathContributes(ManeNodes.resonancePath, 'Fire'),
    );
  });

  group('a path that empowers the basic is still measurable', () {
    test('an empowered cast attributes its uplift to mastery', () async {
      final game = await start('Fire', ManeNodes.assaultPath);
      for (final e in game.enemies) {
        e.isDead = true;
      }
      final comp = game.activeCompanions[0]!;
      final body = dummy(game, comp.position + const Offset(60, 0));
      comp.basicCooldown = 0;
      comp.specialCooldown = 999;
      game.update(1 / 60);
      comp.basicCooldown = 999;
      for (var i = 0; i < 40; i++) {
        game.update(1 / 60);
      }

      final stats = game.mastery.telemetryFor(0);
      expect(body.hp, lessThan(body.maxHp), reason: 'setup: nothing landed');
      expect(
        stats.masteryDamage,
        greaterThan(0),
        reason:
            'Honed Pair raises each slash from 65% to 70%; that difference is '
            'the path working and has to show up as the path working.',
      );
      expect(stats.basicDamage, greaterThan(stats.masteryDamage));
    });
  });
}
