import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_let.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 4: the Let slice. Twelve nodes across three paths, checked against
/// the real combat loop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member({
    required String family,
    required String baseId,
    String element = 'Earth',
    int slotIndex = 0,
  }) => CosmicPartyMember(
    instanceId: '$family-$slotIndex',
    baseId: baseId,
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: slotIndex,
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

  /// Equips a Let path up to and including [throughTier] in slot 0.
  SurvivalFamilyMasterySnapshot equip(String pathId, {int throughTier = 4}) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.let, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'Let-0',
        family: CreatureFamily.let,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  late CosmicSurvivalEnemy template;

  /// A motionless, effectively immortal body at [at].
  CosmicSurvivalEnemy dummy(Offset at, {double hp = 1000000}) =>
      CosmicSurvivalEnemy(
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

  /// A started run with the party out and the arena emptied, plus one parked
  /// body 300 units right of the orb.
  Future<(CosmicSurvivalGame, CosmicSurvivalEnemy)> arena({
    String element = 'Earth',
    SurvivalFamilyMasterySnapshot? snapshot,
    List<CosmicPartyMember>? party,
  }) async {
    final game = CosmicSurvivalGame(
      party:
          party ?? [member(family: 'Let', baseId: 'LET01', element: element)],
      onGameOver: () {},
      masterySnapshot: snapshot,
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    // The run starts with room for one companion out at a time.
    for (var i = 1; i < game.party.length; i++) {
      game.powerUps.apply(kRarePerks.firstWhere((d) => d.id == 'pack_leader'));
    }
    for (final m in game.party) {
      game.summonCompanion(m.slotIndex);
    }
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    template = game.enemies.firstWhere((e) => !e.isDead);
    for (final enemy in game.enemies) {
      enemy.isDead = true;
    }
    final target = dummy(game.orb.position + const Offset(300, 0));
    game.enemies.add(target);
    return (game, target);
  }

  /// Holds every companion's cooldowns so nothing fires on its own.
  void hold(CosmicSurvivalGame game) {
    for (final comp in game.activeCompanions.values) {
      comp.basicCooldown = 99999;
      comp.specialCooldown = 99999;
    }
  }

  /// Fires one Let auto-attack at [target] from [gap] away and returns what
  /// it launched, still in flight.
  List<Projectile> throwRock(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy target, {
    double gap = 120,
  }) {
    final comp = game.activeCompanions[0]!;
    hold(game);
    comp.position = target.position - Offset(gap, 0);
    comp.basicCooldown = 0;
    final before = game.companionProjectiles.toSet();
    game.update(1 / 60);
    hold(game);
    return game.companionProjectiles
        .where((p) => p.sourceSlotIndex == 0 && !before.contains(p))
        .toList();
  }

  /// Runs frames until [body] has lost health or [frames] pass, keeping it
  /// in place, and returns what it lost.
  double settle(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy body, {
    int frames = 120,
  }) {
    final where = body.position;
    final before = body.hp;
    for (var i = 0; i < frames; i++) {
      body.position = where;
      hold(game);
      game.update(1 / 60);
      if (body.hp < before) {
        // One more frame so a crater resolving this frame has landed too.
        body.position = where;
        game.update(1 / 60);
        break;
      }
    }
    return before - body.hp;
  }

  /// Damage one auto-attack deals to [target].
  double oneHit(CosmicSurvivalGame game, CosmicSurvivalEnemy target) {
    throwRock(game, target);
    return settle(game, target);
  }

  group('Falling Star', () {
    test('Dense Core throws a heavier, smaller, slower rock', () async {
      final (bare, bareTarget) = await arena();
      final plain = throwRock(bare, bareTarget).single;

      final (dense, denseTarget) = await arena(
        snapshot: equip(LetNodes.fallingStarPath, throughTier: 1),
      );
      final heavy = throwRock(dense, denseTarget).single;

      expect(
        heavy.damage / plain.damage,
        closeTo(
          LetTuning.denseCoreFraction / LetTuning.baseMeteorFraction,
          1e-6,
        ),
      );
      expect(heavy.radiusMultiplier, lessThan(plain.radiusMultiplier));
      expect(heavy.speedMultiplier, lessThan(plain.speedMultiplier));
      expect(heavy.isDescending, isFalse, reason: 'Falling Star still throws.');
    });

    test(
      'Cratermaker: the second rock on a cracked body lands harder',
      () async {
        final (game, target) = await arena(
          snapshot: equip(LetNodes.fallingStarPath, throughTier: 2),
        );
        final first = oneHit(game, target);
        expect(first, greaterThan(0));
        expect(
          target.letFractureTimer,
          greaterThan(0),
          reason: 'No crack left.',
        );
        final second = oneHit(game, target);
        expect(second / first, closeTo(1 + LetTuning.fractureBonus, 0.01));
      },
    );

    test('Dead Weight hits healthy bodies harder, and only those', () async {
      final (plain, plainTarget) = await arena(
        snapshot: equip(LetNodes.fallingStarPath, throughTier: 1),
      );
      final base = oneHit(plain, plainTarget);

      final (game, healthy) = await arena(
        snapshot: equip(LetNodes.fallingStarPath, throughTier: 3),
      );
      // A fresh body each time so Cratermaker's crack is not in play.
      final healthyHit = oneHit(game, healthy);
      expect(healthyHit / base, closeTo(1 + LetTuning.deadWeightBonus, 0.01));

      final wounded = dummy(
        game.orb.position + const Offset(0, 260),
        hp: 300000,
      );
      game.enemies.add(wounded);
      healthy.isDead = true;
      final woundedHit = oneHit(game, wounded);
      expect(woundedHit / base, closeTo(1.0, 0.01));
    });

    test(
      'Extinction Event: every fifth rock is a comet that craters',
      () async {
        final (game, target) = await arena(
          snapshot: equip(LetNodes.fallingStarPath),
        );
        final neighbour = dummy(target.position + const Offset(0, 60));
        game.enemies.add(neighbour);

        final sizes = <double>[];
        for (var i = 0; i < 5; i++) {
          final rock = throwRock(game, target).single;
          sizes.add(rock.radiusMultiplier);
          if (i < 4) {
            settle(game, target);
            target.letFractureTimer = 0;
          }
        }
        expect(sizes.last, greaterThan(sizes.first * 1.5));
        final neighbourBefore = neighbour.hp;
        settle(game, target);
        expect(
          neighbour.hp,
          lessThan(neighbourBefore),
          reason: 'The comet should crater the body beside its target.',
        );
        expect(game.mastery.telemetryFor(0).capstoneActivations, 1);
      },
    );
  });

  group('Bombardment', () {
    test('Deadfall drops the rock onto its target and craters', () async {
      final (game, target) = await arena(
        snapshot: equip(LetNodes.bombardmentPath, throughTier: 1),
      );
      final inside = dummy(target.position + const Offset(0, 40));
      final outside = dummy(target.position + const Offset(0, 140));
      game.enemies
        ..add(inside)
        ..add(outside);

      final rock = throwRock(game, target, gap: 200).single;
      expect(rock.isDescending, isTrue);
      expect(rock.letDeadfall, isTrue);
      expect(
        rock.skyfallImpact,
        target.position,
        reason: 'It falls on the body, not where the Let stands.',
      );

      final direct = settle(game, target);
      expect(direct, greaterThan(0));
      expect(
        (1000000 - inside.hp) / direct,
        closeTo(LetTuning.craterSplashShare, 0.02),
      );
      expect(outside.hp, 1000000, reason: 'Outside the crater.');
    });

    test('a falling rock carries no element behaviour', () async {
      // Air's special shoves; its auto-attack under Deadfall must not.
      final (game, target) = await arena(
        element: 'Air',
        snapshot: equip(LetNodes.bombardmentPath, throughTier: 1),
      );
      final neighbour = dummy(target.position + const Offset(0, 40));
      game.enemies.add(neighbour);
      throwRock(game, target);
      settle(game, target);
      expect(neighbour.knockbackVelocity, Offset.zero);

      // Dark's special throws follow-up meteors on a kill; a killing
      // auto-attack under Deadfall must not.
      final (dark, darkTarget) = await arena(
        element: 'Dark',
        snapshot: equip(LetNodes.bombardmentPath, throughTier: 1),
      );
      final beside = dummy(darkTarget.position + const Offset(0, 90));
      dark.enemies.add(beside);
      throwRock(dark, darkTarget);
      // Wounded only once the rock is committed to it: a Let aims at the
      // healthiest body in reach, which would otherwise be the one beside.
      darkTarget.hp = 1;
      settle(dark, darkTarget);
      expect(darkTarget.isDead, isTrue, reason: 'test setup');
      expect(
        dark.companionProjectiles.where((p) => p.isDescending),
        isEmpty,
        reason: 'A killing auto-attack must not call Dark follow-ups.',
      );
    });

    test('Heavy Ordnance widens the crater and deepens it', () async {
      final (game, target) = await arena(
        snapshot: equip(LetNodes.bombardmentPath, throughTier: 2),
      );
      final rock = throwRock(game, target).single;
      expect(
        rock.letCraterRadius,
        closeTo(
          LetTuning.deadfallCraterRadius * LetTuning.heavyOrdnanceRadiusScale,
          1e-6,
        ),
      );
      final inside = dummy(target.position + const Offset(0, 58));
      game.enemies.add(inside);
      final direct = settle(game, target);
      expect(
        (1000000 - inside.hp) / direct,
        closeTo(LetTuning.heavyOrdnanceSplashShare, 0.02),
      );
    });

    test('Ranging Shots reaches further and rewards a steady target', () async {
      final (bare, bareTarget) = await arena(
        snapshot: equip(LetNodes.bombardmentPath, throughTier: 2),
      );
      final comp = bare.activeCompanions[0]!;
      final beyond = comp.attackRange * 1.15;
      expect(
        throwRock(bare, bareTarget, gap: beyond),
        isEmpty,
        reason: 'test setup: out of reach without the node',
      );

      final (game, target) = await arena(
        snapshot: equip(LetNodes.bombardmentPath, throughTier: 3),
      );
      expect(throwRock(game, target, gap: beyond), isNotEmpty);
      settle(game, target);

      final hits = <double>[];
      for (var i = 0; i < 5; i++) {
        hits.add(oneHit(game, target));
      }
      // The first drop above counted as the start of the streak.
      expect(hits[0] / hits[4], lessThan(1.0));
      expect(
        hits[4] / (hits[0] / (1 + LetTuning.rangingStreakBonus)),
        closeTo(
          1 + LetTuning.rangingStreakBonus * LetTuning.rangingStreakMax,
          0.02,
        ),
      );
    });

    test('Skyreach drops on the toughest body anywhere', () async {
      final (game, near) = await arena(
        snapshot: equip(LetNodes.bombardmentPath),
      );
      final comp = game.activeCompanions[0]!;
      near.hp = 1000;
      final far = dummy(game.orb.position + const Offset(-520, 180));
      game.enemies.add(far);

      hold(game);
      comp.position = game.orb.position + const Offset(320, 0);
      comp.basicCooldown = 0;
      game.update(1 / 60);
      final rocks = game.companionProjectiles
          .where((p) => p.sourceSlotIndex == 0 && p.letDeadfall)
          .toList();
      expect(rocks, hasLength(1));
      expect(
        (rocks.single.skyfallImpact - far.position).distance,
        lessThan(1),
        reason: 'It should fall on the healthiest body, however far away.',
      );
      expect(game.mastery.telemetryFor(0).capstoneActivations, 1);
    });
  });

  group('Ground Zero', () {
    /// Casts the Let's special on [target] and lets it land.
    void dropSpecial(CosmicSurvivalGame game, CosmicSurvivalEnemy target) {
      final comp = game.activeCompanions[0]!;
      hold(game);
      comp.position = target.position - const Offset(160, 0);
      comp.specialCooldown = 0;
      game.update(1 / 60);
      for (var i = 0; i < 90; i++) {
        hold(game);
        game.update(1 / 60);
        if (target.isLetSighted) break;
      }
    }

    test('Sighted: the special marks what it lands on', () async {
      final (game, target) = await arena(
        snapshot: equip(LetNodes.groundZeroPath, throughTier: 1),
      );
      final (bare, bareTarget) = await arena(
        snapshot: equip(LetNodes.groundZeroPath, throughTier: 1),
      );
      final unmarked = oneHit(bare, bareTarget);

      dropSpecial(game, target);
      expect(target.isLetSighted, isTrue);
      expect(target.letSightTimer, lessThanOrEqualTo(LetTuning.sightDuration));
      final marked = oneHit(game, target);
      expect(marked / unmarked, closeTo(1 + LetTuning.sightedBonus, 0.01));
    });

    test('Walking Fire chases the Sight and keeps it burning', () async {
      final (game, target) = await arena(
        snapshot: equip(LetNodes.groundZeroPath, throughTier: 2),
      );
      dropSpecial(game, target);
      expect(target.isLetSighted, isTrue);
      final before = target.letSightTimer;
      oneHit(game, target);
      // The flight costs a fraction of a second; the hit gives back a whole one.
      expect(target.letSightTimer, greaterThan(before + 0.5));

      // A healthier, unmarked body right beside the Let loses to the Sight.
      final comp = game.activeCompanions[0]!;
      // Close enough to the Let to beat the sticky-target bonus on distance.
      final decoy = dummy(target.position + const Offset(-110, 0));
      game.enemies.add(decoy);
      hold(game);
      comp.position = target.position - const Offset(120, 0);
      comp.basicCooldown = 0;
      game.update(1 / 60);
      expect(identical(comp.stickyTarget, target), isTrue);
    });

    test('Called Shot: the whole team hits a Sighted body harder', () async {
      final party = [
        member(family: 'Let', baseId: 'LET01'),
        member(family: 'Pip', baseId: 'PIP01', element: 'Fire', slotIndex: 1),
      ];
      final (game, target) = await arena(
        snapshot: equip(LetNodes.groundZeroPath, throughTier: 3),
        party: party,
      );
      final pip = game.activeCompanions[1]!;

      double pipVolley() {
        hold(game);
        pip.position = target.position - const Offset(90, 0);
        pip.basicCooldown = 0;
        game.update(1 / 60);
        return settle(game, target, frames: 40);
      }

      final plain = pipVolley();
      dropSpecial(game, target);
      expect(target.letSightCalledShot, isTrue);
      final called = pipVolley();
      expect(called / plain, closeTo(1 + LetTuning.calledShotBonus, 0.02));
    });

    test('Fire for Effect: faster while anything is Sighted, and the Sight '
        'survives a death', () async {
      final (game, target) = await arena(
        snapshot: equip(LetNodes.groundZeroPath),
      );
      final comp = game.activeCompanions[0]!;
      final next = dummy(target.position + const Offset(0, 200));
      game.enemies.add(next);

      throwRock(game, target);
      final coldCooldown = comp.basicCooldown;
      settle(game, target);

      dropSpecial(game, target);
      expect(target.isLetSighted, isTrue);
      comp.basicCooldown = 0;
      comp.position = target.position - const Offset(120, 0);
      game.update(1 / 60);
      expect(
        comp.basicCooldown,
        lessThan(coldCooldown * 0.8),
        reason: 'Sighted enemies should speed the Let up.',
      );

      target.hp = 1;
      oneHit(game, target);
      expect(target.isDead, isTrue, reason: 'test setup');
      expect(next.isLetSighted, isTrue, reason: 'The Sight should hop.');
    });
  });

  test('no Let node changes an unequipped Let', () async {
    final (game, target) = await arena();
    final rock = throwRock(game, target).single;
    expect(rock.isDescending, isFalse);
    expect(rock.letCraterRadius, 0);
    expect(game.letMasteryFor(0), isNull);
    expect(max(0, target.letFractureTimer), 0);
  });
}
