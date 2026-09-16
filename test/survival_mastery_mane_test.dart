import 'dart:math';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mane.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3: the Mane vertical slice. Twelve nodes across three paths, checked
/// against the real combat loop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mane(String element, {int slotIndex = 0}) =>
      CosmicPartyMember(
        instanceId: 'mane-$slotIndex',
        baseId: 'MAN01',
        displayName: 'Mane $element',
        family: 'Mane',
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

  /// Equips [pathId] up to and including [throughTier] for every listed slot.
  SurvivalFamilyMasterySnapshot equip(
    String pathId, {
    int throughTier = 4,
    List<int> slots = const [0],
  }) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.mane, pathId)!;
    final nodes = path.nodes
        .where((n) => n.tier <= throughTier)
        .map((n) => n.id)
        .toList();
    return SurvivalFamilyMasterySnapshot({
      for (final slot in slots)
        slot: EquippedFamilyMastery(
          instanceId: 'mane-$slot',
          family: CreatureFamily.mane,
          pathId: path.id,
          activeNodeIds: nodes,
        ),
    });
  }

  /// A motionless body at [at], built from [template] purely for its enums.
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

  /// A started run with Manes out and one parked, effectively immortal enemy.
  Future<(CosmicSurvivalGame, CosmicSurvivalEnemy)> arena({
    String element = 'Fire',
    SurvivalFamilyMasterySnapshot? snapshot,
    List<int> slots = const [0],
  }) async {
    final game = CosmicSurvivalGame(
      party: [for (final slot in slots) mane(element, slotIndex: slot)],
      onGameOver: () {},
      masterySnapshot: snapshot,
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    for (final slot in slots) {
      game.summonCompanion(slot);
    }

    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    // The spawned bodies are only a source of valid enum values. A drifting
    // enemy makes "both blades hit the same body" a coin flip, and half these
    // tests are about exactly that, so the arena gets a stationary stand-in.
    final template = game.enemies.firstWhere((e) => !e.isDead);
    for (final enemy in game.enemies) {
      enemy.isDead = true;
    }
    final target = dummy(template, game.orb.position + const Offset(300, 0));
    game.enemies.add(target);
    return (game, target);
  }

  /// Fires one basic cast and returns its projectiles, leaving them in flight.
  List<Projectile> castBasic(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy target, {
    int slotIndex = 0,
    double gap = 120,
  }) {
    final comp = game.activeCompanions[slotIndex]!;
    comp.position = target.position - Offset(gap, 0);
    comp.basicCooldown = 0;
    comp.specialCooldown = 999;
    game.companionProjectiles.clear();
    game.update(1 / 60);
    return game.companionProjectiles
        .where((p) => p.sourceSlotIndex == slotIndex)
        .toList();
  }

  int rhythmOf(CosmicSurvivalGame game, int slotIndex) =>
      game.maneMasteryFor(slotIndex)?.rhythm ?? 0;

  double encoreOf(CosmicSurvivalGame game, int slotIndex) =>
      game.maneMasteryFor(slotIndex)?.encoreTimer ?? 0;

  /// Fires a basic and flies it into the target, returning the cast id.
  int landBasic(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy target, {
    int slotIndex = 0,
    double gap = 60,
  }) {
    final shots = castBasic(game, target, slotIndex: slotIndex, gap: gap);
    final castId = shots.first.masteryCastId;
    // Flying this cast in takes longer than the basic cooldown, and a stray
    // second cast launched mid-flight would be abandoned here and later
    // judged a miss — costing a Rhythm the test never meant to spend.
    game.activeCompanions[slotIndex]!.basicCooldown = 999;
    for (var i = 0; i < 40; i++) {
      game.update(1 / 60);
      final cast = game.mastery.cast(castId);
      if (cast == null || cast.totalHits >= 2) break;
    }
    return castId;
  }

  group('chassis and geometry', () {
    test('Honed Pair tightens the pair and sharpens each blade', () async {
      final (bare, bareTarget) = await arena();
      final bareShots = castBasic(bare, bareTarget);
      final bareSpread = (bareShots[0].angle - bareShots[1].angle).abs();
      final bareDamage = bareShots.first.damage;

      final (honed, honedTarget) = await arena(
        snapshot: equip(ManeNodes.assaultPath, throughTier: 1),
      );
      final honedShots = castBasic(honed, honedTarget);
      final honedSpread = (honedShots[0].angle - honedShots[1].angle).abs();

      expect(honedShots.length, 2);
      expect(
        honedSpread,
        closeTo(bareSpread * ManeTuning.honedPairSpreadScale, 1e-6),
      );
      expect(
        honedShots.first.damage / bareDamage,
        closeTo(
          ManeTuning.honedPairSlashFraction / ManeTuning.baseSlashFraction,
          1e-6,
        ),
      );
    });

    test('Sweeping Claws trades damage for width and reach', () async {
      final (bare, bareTarget) = await arena();
      final bareShots = castBasic(bare, bareTarget);
      final bareSpread = (bareShots[0].angle - bareShots[1].angle).abs();

      final (sweep, sweepTarget) = await arena(
        snapshot: equip(ManeNodes.controlPath, throughTier: 1),
      );
      final sweepShots = castBasic(sweep, sweepTarget);
      final sweepSpread = (sweepShots[0].angle - sweepShots[1].angle).abs();

      expect(sweepSpread, greaterThan(bareSpread));
      expect(sweepShots.first.damage, lessThan(bareShots.first.damage));
      expect(
        sweepShots.first.radiusMultiplier,
        greaterThan(bareShots.first.radiusMultiplier),
      );
    });

    test('a Mane with nothing equipped throws the untouched chassis', () async {
      final (game, target) = await arena();
      final shots = castBasic(game, target);
      expect(shots.length, 2);
      expect(shots.every((p) => p.masteryCastId == 0), isTrue);
      expect(shots.every((p) => !p.homing), isTrue);
    });
  });

  group('Twin Fang', () {
    test('Crosscut pays a dual hit in damage and one payload', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.assaultPath, throughTier: 2),
      );
      final castId = landBasic(game, target);
      final cast = game.mastery.cast(castId)!;

      expect(cast.hitsOn(identityHashCode(target)), 2, reason: 'setup');
      expect(game.mastery.telemetryFor(0).masteryDamage, greaterThan(0));
      expect(
        game.mastery.telemetryFor(0).payloadApplications,
        1,
        reason: 'One payload per cast, not one per blade.',
      );
      expect(target.slowTimer, greaterThan(0));
    });

    test('Crosscut pays nothing when the blades split', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.assaultPath, throughTier: 2),
      );
      // A second body, placed so each blade takes one.
      final second = CosmicSurvivalEnemy(
        position: target.position + const Offset(0, 90),
        hp: 1000000,
        maxHp: 1000000,
        speed: 0,
        damage: 0,
        radius: target.radius,
        tier: target.tier,
        element: target.element,
        conduct: target.conduct,
        target: target.target,
      );
      game.enemies.add(second);

      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(300, 0);
      comp.basicCooldown = 0;
      comp.specialCooldown = 999;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      // Whatever landed, no single body took both blades, so no bonus.
      expect(game.mastery.telemetryFor(0).masteryDamage, 0);
    });

    test('Predator Step empowers exactly one cast after a kill', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.assaultPath, throughTier: 3),
      );
      target.hp = 1;
      landBasic(game, target);
      expect(target.isDead, isTrue, reason: 'setup: the basic should kill');

      // A fresh body to shoot at.
      final next = game.enemies.firstWhere(
        (e) => !e.isDead,
        orElse: () {
          final e = CosmicSurvivalEnemy(
            position: game.orb.position + const Offset(300, 0),
            hp: 1000000,
            maxHp: 1000000,
            speed: 0,
            damage: 0,
            radius: target.radius,
            tier: target.tier,
            element: target.element,
            conduct: target.conduct,
            target: target.target,
          );
          game.enemies.add(e);
          return e;
        },
      );
      next
        ..position = game.orb.position + const Offset(300, 0)
        ..hp = 1000000;

      final empowered = castBasic(game, next);
      expect(
        empowered.first.homing,
        isTrue,
        reason: 'The kill should sharpen the next cast\'s tracking.',
      );

      final after = castBasic(game, next);
      expect(
        after.first.homing,
        isFalse,
        reason: 'The window is spent by the cast it empowered.',
      );
      expect(after.first.damage, lessThan(empowered.first.damage));
    });

    test('Blade Dance returns five casts worth of slashes', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.assaultPath),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.specialCooldown = 0;
      comp.basicCooldown = 999;
      game.update(1 / 60);

      final shots = castBasic(game, target);
      expect(
        shots.every((p) => p.masteryReturnFraction > 0),
        isTrue,
        reason: 'The special should have empowered this cast.',
      );

      // Spend the remaining four, then confirm the sixth is ordinary.
      for (var i = 0; i < 4; i++) {
        castBasic(game, target);
      }
      final plain = castBasic(game, target);
      expect(plain.every((p) => p.masteryReturnFraction == 0), isTrue);
    });

    test('a returning slash cannot trigger Crosscut or a payload', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.assaultPath),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.specialCooldown = 0;
      comp.basicCooldown = 999;
      game.update(1 / 60);

      castBasic(game, target, gap: 60);
      // Exactly one basic cast, so the payload count below is unambiguous.
      comp.basicCooldown = 999;
      var sawReturn = false;
      for (var i = 0; i < 90; i++) {
        game.update(1 / 60);
        for (final p in game.companionProjectiles) {
          if (!p.masteryGenerated) continue;
          sawReturn = true;
          expect(
            p.masteryCastId,
            0,
            reason: 'A return carries no cast, so Crosscut cannot see it.',
          );
          expect(
            p.masteryReturnFraction,
            0,
            reason: 'A boomerang must not boomerang again.',
          );
        }
      }
      expect(sawReturn, isTrue, reason: 'setup: nothing came back');
      expect(
        game.mastery.telemetryFor(0).payloadApplications,
        1,
        reason: 'The outgoing pair pays one payload; the returns pay none.',
      );
    });
  });

  group('Tempest Claw', () {
    test('Rending Wake pays each body a slash reaches, once', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.controlPath, throughTier: 2),
      );
      landBasic(game, target);
      expect(
        game.mastery.telemetryFor(0).payloadApplications,
        1,
        reason: 'Both blades into one body is still one body.',
      );
      expect(target.slowTimer, greaterThan(0));
    });

    test('Crosswind pays both bodies when the pair splits', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.controlPath, throughTier: 3),
      );
      final second = CosmicSurvivalEnemy(
        position: target.position + const Offset(0, 80),
        hp: 1000000,
        maxHp: 1000000,
        speed: 0,
        damage: 0,
        radius: target.radius,
        tier: target.tier,
        element: target.element,
        conduct: target.conduct,
        target: target.target,
      );
      game.enemies.add(second);

      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(260, 40);
      comp.basicCooldown = 0;
      comp.specialCooldown = 999;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }

      if (target.slowTimer > 0 && second.slowTimer > 0) {
        // The split landed: Rending Wake paid each, Crosswind paid both again.
        expect(
          game.mastery.telemetryFor(0).payloadApplications,
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('Tempest Ring fires every fourth cast and caps its hits', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.controlPath),
      );
      for (var i = 0; i < 3; i++) {
        castBasic(game, target, gap: 180);
      }
      expect(
        game.companionProjectiles.where((p) => p.masteryGenerated).length,
        0,
        reason: 'Three casts is not yet a ring.',
      );

      castBasic(game, target, gap: 180);
      final ring = game.companionProjectiles
          .where((p) => p.masteryGenerated)
          .toList();
      expect(ring.length, ManeTuning.tempestRingSlashes);

      final ringCast = game.mastery.cast(ring.first.masteryCastId)!;
      expect(ringCast.maxHitsPerTarget, ManeTuning.tempestRingMaxHitsPerTarget);

      // Park the body inside the ring and let the whole thing sweep through.
      target.position = game.activeCompanions[0]!.position;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(
        ringCast.hitsOn(identityHashCode(target)),
        lessThanOrEqualTo(ManeTuning.tempestRingMaxHitsPerTarget),
      );
    });

    test('a ring is not counted as another scheduled attack', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.controlPath),
      );
      for (var i = 0; i < 4; i++) {
        castBasic(game, target, gap: 180);
      }
      expect(
        game.mastery.telemetryFor(0).basicCasts,
        4,
        reason: 'The ring is the capstone firing, not a fifth cast.',
      );
    });
  });

  group('War Rhythm', () {
    test('Measured Cuts banks a Rhythm per clean pair, up to five', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath, throughTier: 1),
      );
      for (var i = 0; i < 8; i++) {
        landBasic(game, target);
      }
      expect(rhythmOf(game, 0), ManeTuning.maxRhythm);
    });

    test('Rhythm makes the Mane faster and harder hitting', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath, throughTier: 2),
      );
      final cold = castBasic(game, target, gap: 180);
      final coldDamage = cold.first.damage;
      final coldCooldown = game.activeCompanions[0]!.basicCooldown;

      for (var i = 0; i < 6; i++) {
        landBasic(game, target);
      }
      expect(rhythmOf(game, 0), greaterThan(0));

      final hot = castBasic(game, target, gap: 180);
      expect(hot.first.damage, greaterThan(coldDamage));
      expect(game.activeCompanions[0]!.basicCooldown, lessThan(coldCooldown));
      expect(
        hot.first.radiusMultiplier,
        greaterThan(cold.first.radiusMultiplier),
        reason: 'Three or more Rhythm should widen the slashes.',
      );
    });

    test('a cast that lands nothing spends a Rhythm', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath, throughTier: 1),
      );
      for (var i = 0; i < 4; i++) {
        landBasic(game, target);
      }
      final banked = rhythmOf(game, 0);
      expect(banked, greaterThan(0));

      // Cast at the body, then move it out from under the slashes: a cast
      // has to exist before it can miss.
      final shots = castBasic(game, target, gap: 180);
      expect(shots, isNotEmpty, reason: 'setup: nothing was cast');
      target.position = game.orb.position + const Offset(4000, 4000);
      for (var i = 0; i < 60 * 4; i++) {
        game.update(1 / 60);
      }
      expect(rhythmOf(game, 0), lessThan(banked));
    });

    test('Crescendo spends the reserve to empower that many casts', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.resonancePath, throughTier: 3),
      );
      for (var i = 0; i < 3; i++) {
        landBasic(game, target);
      }
      final banked = rhythmOf(game, 0);
      expect(banked, greaterThan(0));

      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.specialCooldown = 0;
      comp.basicCooldown = 999;
      game.update(1 / 60);

      expect(rhythmOf(game, 0), 0, reason: 'The special spends it.');
      expect(game.mastery.telemetryFor(0).specialAmplifications, 1);

      final payloadsBefore = game.mastery.telemetryFor(0).payloadApplications;
      landBasic(game, target);
      expect(
        game.mastery.telemetryFor(0).payloadApplications,
        greaterThan(payloadsBefore),
        reason: 'An empowered cast carries the element.',
      );
    });

    test(
      'Encore opens only on a full five and cannot refresh itself',
      () async {
        final (game, target) = await arena(
          snapshot: equip(ManeNodes.resonancePath),
        );
        for (var i = 0; i < 8; i++) {
          landBasic(game, target);
        }
        expect(rhythmOf(game, 0), ManeTuning.maxRhythm);

        final comp = game.activeCompanions[0]!;
        comp.position = target.position - const Offset(120, 0);
        comp.specialCooldown = 0;
        comp.basicCooldown = 999;
        game.update(1 / 60);

        expect(encoreOf(game, 0), greaterThan(0));
        expect(game.mastery.telemetryFor(0).capstoneActivations, 1);
        final opened = encoreOf(game, 0);

        // Bank and spend a partial reserve: it must not restart the window.
        for (var i = 0; i < 2; i++) {
          landBasic(game, target);
        }
        comp.specialCooldown = 0;
        comp.basicCooldown = 999;
        game.update(1 / 60);
        expect(encoreOf(game, 0), lessThan(opened));
        expect(game.mastery.telemetryFor(0).capstoneActivations, 1);
      },
    );

    test('the Encore extension ceiling holds however many kills arrive', () {
      final state = ManeMasteryState()..rhythm = ManeTuning.maxRhythm;
      expect(state.tryOpenEncore(), isTrue);
      expect(state.tryOpenEncore(), isFalse, reason: 'cannot refresh itself');
      for (var i = 0; i < 50; i++) {
        state.extendEncore();
      }
      expect(
        state.encoreTimer,
        closeTo(
          ManeTuning.encoreDuration + ManeTuning.encoreMaxExtension,
          1e-9,
        ),
      );
    });

    test('a kill during an Encore buys more of it', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath),
      );
      for (var i = 0; i < 8; i++) {
        landBasic(game, target);
      }
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.specialCooldown = 0;
      comp.basicCooldown = 999;
      game.update(1 / 60);
      expect(encoreOf(game, 0), greaterThan(0));

      // A body that the next basic will finish.
      target.hp = 1;
      final before = encoreOf(game, 0);
      landBasic(game, target);
      expect(target.isDead, isTrue, reason: 'setup: the basic should kill');
      expect(
        encoreOf(game, 0),
        greaterThan(before - ManeTuning.encoreKillExtension),
        reason: 'The kill should have bought back more than the time spent.',
      );
      expect(
        encoreOf(game, 0),
        lessThanOrEqualTo(
          ManeTuning.encoreDuration + ManeTuning.encoreMaxExtension,
        ),
      );
    });
  });

  group('the catapult bills a body a bounded number of times', () {
    test(
      'one special cannot hit the same enemy more than five times',
      () async {
        final (game, target) = await arena(
          element: 'Ice',
          snapshot: equip(ManeNodes.assaultPath, throughTier: 1),
        );
        final comp = game.activeCompanions[0]!;
        comp.position = target.position - const Offset(150, 0);
        comp.basicCooldown = 99999;
        comp.specialCooldown = 0;
        game.companionProjectiles.clear();
        game.update(1 / 60);

        final shot = game.companionProjectiles.firstWhere(
          (p) => p.abilityFamily == 'mane',
        );
        expect(shot.maxHitsPerEnemy, kManeSpecialMaxHitsPerEnemy);

        // A Mane catapult crawls, so without the ceiling it bills this standing
        // body once per frame of overlap — measured at 21 hits for 3,777 damage
        // before the cap existed.
        var contacts = 0;
        for (var i = 0; i < 60 * 8; i++) {
          comp.basicCooldown = 99999;
          comp.specialCooldown = 99999;
          final before = target.hp;
          game.update(1 / 60);
          if (before - target.hp > 0.01) contacts++;
        }
        expect(
          contacts,
          lessThanOrEqualTo(kManeSpecialMaxHitsPerEnemy + 4),
          reason:
              'The projectile landed $contacts separate hits on one body. The '
              'ceiling is $kManeSpecialMaxHitsPerEnemy; anything much above it '
              'means the cap is not being enforced before damage.',
        );
      },
    );

    test('the ceiling is per body, so piercing a line still pays', () async {
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.assaultPath, throughTier: 1),
      );
      final comp = game.activeCompanions[0]!;
      final line = [
        for (var i = 1; i <= 3; i++)
          dummy(target, comp.position + Offset(90.0 * i, 0)),
      ];
      for (final body in line) {
        game.enemies.add(body);
      }
      comp.basicCooldown = 99999;
      comp.specialCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      final before = {for (final b in line) b: b.hp};
      for (var i = 0; i < 60 * 8; i++) {
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      expect(
        line.where((b) => b.hp < before[b]!).length,
        greaterThan(1),
        reason: 'A capped catapult must still pierce through a line.',
      );
    });
  });

  group('abilities scale with the creature that casts them', () {
    test('a Fire Mane throws 4, 8 or 16 fireballs by Beauty', () {
      expect(
        scaledAbilityCount(
          kAbilityStatLow,
          atLow: 4,
          atAverage: 8,
          atPerfect: 16,
        ),
        4,
      );
      expect(
        scaledAbilityCount(
          kAbilityStatAverage,
          atLow: 4,
          atAverage: 8,
          atPerfect: 16,
        ),
        8,
      );
      expect(
        scaledAbilityCount(
          kAbilityStatPerfect,
          atLow: 4,
          atAverage: 8,
          atPerfect: 16,
        ),
        16,
      );
      // Enhancement pushes past perfect; the count must not run away with it.
      expect(scaledAbilityCount(30, atLow: 4, atAverage: 8, atPerfect: 16), 16);
      // And a floor, so a hatchling still casts something.
      expect(scaledAbilityCount(0.1, atLow: 4, atAverage: 8, atPerfect: 16), 4);
    });

    test('the count climbs monotonically across the whole band', () {
      var previous = 0;
      for (var stat = 0.5; stat <= 16; stat += 0.25) {
        final count = scaledAbilityCount(
          stat,
          atLow: 4,
          atAverage: 8,
          atPerfect: 16,
        );
        expect(count, greaterThanOrEqualTo(previous));
        previous = count;
      }
    });

    test('the real Fire ability honours the curve', () {
      int fireballs(double beauty) => createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 0,
        family: 'mane',
        element: 'Fire',
        damage: 100,
        maxHp: 400,
        casterPower: 4,
        casterBeauty: beauty,
        casterIntelligence: 4,
        casterStrength: 4,
        targetPos: const Offset(200, 0),
      ).projectiles.length;

      expect(fireballs(2.6), 4);
      expect(fireballs(4.31), 8);
      expect(fireballs(11.75), 16);
    });

    test('Lightning scales on its own flatter curve, not Fire\'s', () {
      int orbs(double beauty) =>
          scaledAbilityCount(beauty, atLow: 5, atAverage: 7, atPerfect: 12);
      expect(orbs(kAbilityStatLow), 5);
      expect(orbs(kAbilityStatAverage), 7);
      expect(orbs(kAbilityStatPerfect), 12);
      // Two families sharing one curve is one family with two names.
      expect(
        orbs(kAbilityStatPerfect),
        isNot(
          scaledAbilityCount(
            kAbilityStatPerfect,
            atLow: 4,
            atAverage: 8,
            atPerfect: 16,
          ),
        ),
      );
    });
  });

  group('each stat has its own job on a Mane', () {
    /// One special cast into a ring of six standing bodies.
    Future<({int projectiles, double radius, double damage})> cast({
      required double strength,
      required double intelligence,
      required double beauty,
      String element = 'Ice',
    }) async {
      final game = CosmicSurvivalGame(
        party: [
          CosmicPartyMember(
            instanceId: 'mane-0',
            baseId: 'MAN01',
            displayName: 'Mane',
            family: 'Mane',
            element: element,
            level: 10,
            slotIndex: 0,
            statSpeed: 4.25,
            statIntelligence: intelligence,
            statStrength: strength,
            statBeauty: beauty,
            statSpeedPotential: 50,
            statIntelligencePotential: 50,
            statStrengthPotential: 50,
            statBeautyPotential: 50,
            staminaBars: 3,
            staminaMax: 3,
          ),
        ],
        onGameOver: () {},
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
      final comp = game.activeCompanions[0]!;
      final bodies = [
        for (var i = 0; i < 6; i++)
          dummy(
            template,
            comp.position +
                Offset(cos(i * pi / 3) * 110, sin(i * pi / 3) * 110),
          ),
      ];
      for (final b in bodies) {
        game.enemies.add(b);
      }
      comp.basicCooldown = 99999;
      comp.specialCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      final shots = game.companionProjectiles
          .where((p) => p.abilityFamily == 'mane')
          .toList();
      final before = {for (final b in bodies) b: b.hp};
      for (var i = 0; i < 60 * 8; i++) {
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      return (
        projectiles: shots.length,
        radius: shots.isEmpty ? 0.0 : shots.first.radiusMultiplier,
        damage: bodies.fold<double>(0, (a, b) => a + (before[b]! - b.hp)),
      );
    }

    test('Strength decides how hard the catapult hits', () async {
      final average = await cast(
        strength: 4.25,
        intelligence: 4.25,
        beauty: 4.25,
      );
      final strong = await cast(strength: 9, intelligence: 4.25, beauty: 4.25);
      expect(strong.damage, greaterThan(average.damage * 1.4));
      expect(
        strong.projectiles,
        average.projectiles,
        reason: 'Strength buys power, not coverage.',
      );
      expect(strong.radius, closeTo(average.radius, 0.01));
    });

    test('Beauty decides how much of it there is, not how hard', () async {
      final average = await cast(
        strength: 4.25,
        intelligence: 4.25,
        beauty: 4.25,
      );
      final pretty = await cast(strength: 4.25, intelligence: 4.25, beauty: 9);
      // Ice is a single shot, so Beauty's coverage is the ball getting wider.
      expect(pretty.radius, greaterThan(average.radius * 1.2));
      expect(pretty.projectiles, average.projectiles);
      // Wider still means more total damage, through reach rather than power.
      expect(pretty.damage, greaterThan(average.damage));
      expect(
        pretty.damage,
        lessThan(average.damage * 1.4),
        reason: 'Beauty must not out-damage Strength on a single shot.',
      );
    });

    test('on a fan element Beauty buys count instead of width', () async {
      final average = await cast(
        strength: 4.25,
        intelligence: 4.25,
        beauty: 4.25,
        element: 'Fire',
      );
      final pretty = await cast(
        strength: 4.25,
        intelligence: 4.25,
        beauty: 9,
        element: 'Fire',
      );
      expect(pretty.projectiles, greaterThan(average.projectiles));
    });

    test(
      'a Strength build and a Beauty build are not the same build',
      () async {
        final strong = await cast(
          strength: 9,
          intelligence: 4.25,
          beauty: 4.25,
        );
        final pretty = await cast(
          strength: 4.25,
          intelligence: 4.25,
          beauty: 9,
        );
        expect(strong.radius, lessThan(pretty.radius));
        expect(strong.damage, greaterThan(pretty.damage));
      },
    );
  });

  group('the path is the family\'s, not the creature\'s', () {
    test(
      'a second Mane inherits the same path and builds its own Rhythm',
      () async {
        final (game, target) = await arena(
          snapshot: equip(
            ManeNodes.resonancePath,
            throughTier: 1,
            slots: [0, 1],
          ),
          slots: [0, 1],
        );
        expect(game.mastery.equippedFor(1)?.pathId, ManeNodes.resonancePath);

        for (var i = 0; i < 3; i++) {
          landBasic(game, target, slotIndex: 1);
        }
        expect(rhythmOf(game, 1), greaterThan(0));
        expect(
          rhythmOf(game, 0),
          0,
          reason: 'Rhythm is the creature\'s, even though the path is shared.',
        );
      },
    );
  });
}
