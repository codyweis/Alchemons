import 'dart:math';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mane.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3: the Mane vertical slice. Eight nodes across two paths, checked
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
    int? seed,
  }) async {
    final game = CosmicSurvivalGame(
      party: [for (final slot in slots) mane(element, slotIndex: slot)],
      onGameOver: () {},
      masterySnapshot: snapshot,
      random: seed == null ? null : Random(seed),
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

  /// Fires one special and returns its projectiles, still in flight.
  Future<List<Projectile>> castSpecial(
    CosmicSurvivalGame game,
    CosmicSurvivalEnemy target, {
    int slotIndex = 0,
    double gap = 140,
    bool clearFirst = true,
  }) async {
    final comp = game.activeCompanions[slotIndex]!;
    comp.position = target.position - Offset(gap, 0);
    comp.basicCooldown = 99999;
    comp.specialCooldown = 0;
    // Anything already in flight is usually noise, but not always: a test
    // about a persistent circuit cannot wipe the circuit before looking for
    // it. Callers that care keep the field.
    final before = clearFirst
        ? const <Projectile>{}
        : game.companionProjectiles.toSet();
    if (clearFirst) game.companionProjectiles.clear();
    game.update(1 / 60);
    comp.specialCooldown = 99999;
    return game.companionProjectiles
        .where((p) => p.sourceSlotIndex == slotIndex && !before.contains(p))
        .toList();
  }

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
    test('a Mane with nothing equipped throws the untouched chassis', () async {
      final (game, target) = await arena();
      final shots = castBasic(game, target);
      expect(shots.length, 2);
      expect(shots.every((p) => p.masteryCastId == 0), isTrue);
      expect(shots.every((p) => !p.homing), isTrue);
    });

    test('a path leaves the pair as the chassis threw it', () async {
      // War Rhythm changes what a pair earns, not the pair: the chassis's
      // spread, damage, speed and art all stand until an Encore widens it.
      final (bare, bareTarget) = await arena();
      final plain = castBasic(bare, bareTarget);
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath),
      );
      final shaped = castBasic(game, target);
      expect(shaped, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(shaped[i].angle, closeTo(plain[i].angle, 1e-9));
        expect(shaped[i].damage, closeTo(plain[i].damage, 1e-9));
        expect(shaped[i].radiusMultiplier, plain[i].radiusMultiplier);
        expect(shaped[i].basicFamily, 'mane');
      }
    });
  });

  group('Crosscut', () {
    /// A still body [offset] past [target], on the far side from the Mane.
    CosmicSurvivalEnemy behind(
      CosmicSurvivalGame game,
      CosmicSurvivalEnemy target,
      Offset offset,
    ) {
      final body = dummy(target, target.position + offset);
      game.enemies.add(body);
      return body;
    }

    /// Lands one pair on [target] and lets whatever it sends on fly out.
    Future<void> landAndFly(
      CosmicSurvivalGame game,
      CosmicSurvivalEnemy target,
    ) async {
      landBasic(game, target);
      for (var i = 0; i < 90; i++) {
        game.update(1 / 60);
      }
    }

    test('both blades on one body cross through it and cut the next one, '
        'carrying the element', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.resonancePath, throughTier: 2),
      );
      // Off the line the pair was thrown along, but ahead of it.
      final next = behind(game, target, const Offset(110, 45));
      await landAndFly(game, target);

      expect(next.hp, lessThan(next.maxHp), reason: 'the pair never got there');
      expect(next.slowTimer, greaterThan(0), reason: "Mud's effect");
      // The cut on the next body is the path's.
      expect(game.mastery.telemetryFor(0).masteryDamage, greaterThan(0));
      expect(
        game.mastery.telemetryFor(0).payloadApplications,
        1,
        reason: 'One payload per crossing, not one per blade.',
      );
      // The crossing is not another attack: it earns no Rhythm of its own.
      expect(rhythmOf(game, 0), 1);
    });

    test('a crossed pair crosses again, up to three bodies past the first',
        () async {
      final (game, target) = await arena(
        element: 'Fire',
        snapshot: equip(ManeNodes.resonancePath, throughTier: 2),
      );
      final line = [
        for (var i = 1; i <= ManeTuning.crosscutCrossings + 1; i++)
          behind(game, target, Offset(90.0 * i, 0)),
      ];
      await landAndFly(game, target);
      for (var i = 0; i < ManeTuning.crosscutCrossings; i++) {
        expect(line[i].hp, lessThan(line[i].maxHp), reason: 'body ${i + 1}');
      }
      expect(
        line.last.hp,
        line.last.maxHp,
        reason: 'it crossed more than ${ManeTuning.crosscutCrossings}',
      );
      // Still one Rhythm: the crossings are not attacks.
      expect(rhythmOf(game, 0), 1);
    });

    test('without Crosscut the pair stops in the body', () async {
      final (game, target) = await arena(
        element: 'Fire',
        snapshot: equip(ManeNodes.resonancePath, throughTier: 1),
      );
      final next = behind(game, target, const Offset(90, 0));
      await landAndFly(game, target);
      expect(target.hp, lessThan(target.maxHp), reason: 'setup');
      expect(next.hp, next.maxHp);
      expect(game.mastery.telemetryFor(0).masteryDamage, 0);
    });

    test('Crosscut pays nothing when the blades split', () async {
      final (game, target) = await arena(
        element: 'Mud',
        snapshot: equip(ManeNodes.resonancePath, throughTier: 2),
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
      // Whatever landed, no single body took both blades, so nothing
      // crossed.
      expect(game.mastery.telemetryFor(0).masteryDamage, 0);
    });
  });

  group('family speed', () {
    test('Mane blades and catapults fly at half speed', () async {
      final (game, target) = await arena(element: 'Ice');
      final blades = castBasic(game, target);
      expect(
        blades.every((p) => p.speedMultiplier == kManeBasicSpeedMultiplier),
        isTrue,
        reason: 'A Mane blade is a thrown slash, not a bullet.',
      );
      // And the same has to hold with mastery equipped.
      final (mastered, masteredTarget) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.resonancePath),
      );
      final shaped = castBasic(mastered, masteredTarget);
      expect(
        shaped.every((p) => p.speedMultiplier == kManeBasicSpeedMultiplier),
        isTrue,
        reason: 'Equipping a path must not restore the old blade speed.',
      );

      final special = await castSpecial(game, target);
      expect(
        special.every((p) => p.speedMultiplier <= 0.3 || p.holdOrbit),
        isTrue,
        reason: 'The catapult crawl is now half what it was.',
      );
    });
  });

  group('Limitless', () {
    test('Far Throw carries the special further', () async {
      final (bare, bareTarget) = await arena(element: 'Ice');
      final plain = await castSpecial(bare, bareTarget);

      final (far, farTarget) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: 1),
      );
      final thrown = await castSpecial(far, farTarget);

      expect(thrown.first.life, greaterThan(plain.first.life));
      expect(
        thrown.first.life / plain.first.life,
        closeTo(ManeTuning.farThrowLifeScale, 0.01),
      );
    });

    /// Casts an Ice catapult through [target] at a second body ahead of it
    /// and off its line, and returns what that body took and the shot.
    Future<({double offLine, Projectile shot, List<double> turns})> arcThrough(
      int throughTier,
    ) async {
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: throughTier),
      );
      // Ahead of the first body and 60 units off the line the shot is
      // thrown down: a straight shot passes it by.
      final aside = dummy(target, target.position + const Offset(200, 60));
      game.enemies.add(aside);
      final shots = await castSpecial(game, target);
      final shot = shots.firstWhere((p) => p.abilityFamily == 'mane');
      final comp = game.activeCompanions[0]!;
      final turns = <double>[];
      for (var i = 0; i < 60 * 4; i++) {
        // Only the two bodies: the spawner's own arrivals are not the test.
        for (final e in game.enemies) {
          if (!identical(e, target) && !identical(e, aside)) e.isDead = true;
        }
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        final before = shot.angle;
        game.update(1 / 60);
        turns.add((shot.angle - before).abs());
      }
      return (offLine: aside.maxHp - aside.hp, shot: shot, turns: turns);
    }

    test("Hunter's Arc bends the shot onto a body it would have missed",
        () async {
      final straight = await arcThrough(1);
      expect(
        straight.offLine,
        0,
        reason: 'setup: Far Throw alone should fly past the second body',
      );
      expect(straight.shot.masteryArc, isFalse);

      final arced = await arcThrough(2);
      expect(arced.shot.masteryArc, isTrue);
      expect(arced.shot.masteryArcTurned, greaterThan(0.1));
      expect(
        arced.offLine,
        greaterThan(0),
        reason: 'After its first hit the shot should bend onto the body '
            'ahead of it.',
      );
      // It bends; it does not snap.
      expect(
        arced.turns.reduce(max),
        lessThanOrEqualTo(ManeTuning.arcMaxTurnRate / 60 + 1e-9),
      );
      expect(
        arced.shot.masteryArcTurned,
        lessThanOrEqualTo(ManeTuning.arcTurnBudget + 1e-9),
      );
    });

    test("Hunter's Arc waits for the first hit", () async {
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: 2),
      );
      final shots = await castSpecial(game, target);
      final shot = shots.firstWhere((p) => p.abilityFamily == 'mane');
      final heading = shot.angle;
      // The body it was thrown at steps out of the way, and another stands
      // ahead of the shot and off its line: well inside the cone, but the
      // shot has struck nothing yet.
      target.position = game.orb.position + const Offset(0, 4000);
      final aside = dummy(target, shot.position + const Offset(160, 50));
      game.enemies.add(aside);
      final comp = game.activeCompanions[0]!;
      for (var i = 0; i < 60 * 2; i++) {
        for (final e in game.enemies) {
          if (!identical(e, target) && !identical(e, aside)) e.isDead = true;
        }
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      expect(shot.masteryArcTurned, 0);
      expect(shot.angle, heading);
    });

    test('a shot with nothing ahead of it flies straight', () async {
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: 2),
      );
      // Something behind it, which is not "ahead" — far enough back that
      // the Mane still throws at the body in front of it.
      final behind = dummy(target, target.position - const Offset(420, 40));
      game.enemies.add(behind);
      final shots = await castSpecial(game, target);
      final shot = shots.firstWhere((p) => p.abilityFamily == 'mane');
      final heading = shot.angle;
      final comp = game.activeCompanions[0]!;
      for (var i = 0; i < 60 * 3; i++) {
        for (final e in game.enemies) {
          if (!identical(e, target) && !identical(e, behind)) e.isDead = true;
        }
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      expect(target.hp, lessThan(target.maxHp), reason: 'setup: no first hit');
      expect(shot.pierceCount, greaterThan(0));
      expect(shot.angle, heading);
    });

    test("a Lightning orb that crosses a body blooms on the next one ahead",
        () async {
      // An orb flies to a landing point rather than on a heading, so the arc
      // swings the landing point: its field blooms on a body, not on the
      // empty ground it was thrown at.
      Future<({Offset landed, Offset thrownAt, double fromAhead})> landing(
        int throughTier,
        int seed,
      ) async {
        final (game, target) = await arena(
          element: 'Lightning',
          snapshot: equip(ManeNodes.limitlessPath, throughTier: throughTier),
          seed: seed,
        );
        final shots = await castSpecial(game, target);
        final orbs = shots.where((p) => p.effectStacks == 1).toList();
        expect(orbs, isNotEmpty, reason: 'setup: no orbs');
        // The orb with the furthest to go, so there is room to bend.
        orbs.sort(
          (a, b) => (b.cachedHomingTarget! - b.position).distance.compareTo(
            (a.cachedHomingTarget! - a.position).distance,
          ),
        );
        final orb = orbs.first;
        // Only this orb: the others bloom wherever they were thrown.
        game.companionProjectiles.removeWhere(
          (p) => p.sourceSlotIndex == 0 && !identical(p, orb),
        );
        final thrownAt = orb.cachedHomingTarget!;
        final toLanding = thrownAt - orb.position;
        expect(toLanding.distance, greaterThan(400), reason: 'setup');
        final dir = toLanding / toLanding.distance;
        final side = Offset(-dir.dy, dir.dx);
        // One body on its path, which it crosses, and one ahead and off it
        // by more than the field it blooms into reaches — far enough ahead
        // that an orb turning no tighter than the arc allows can make it.
        target.position = orb.position + dir * 60;
        final ahead = dummy(target, orb.position + dir * 300 + side * 60);
        game.enemies.add(ahead);
        final comp = game.activeCompanions[0]!;
        Offset? landed;
        for (var i = 0; i < 60 * 3 && landed == null; i++) {
          for (final e in game.enemies) {
            if (!identical(e, target) && !identical(e, ahead)) e.isDead = true;
          }
          comp.basicCooldown = 99999;
          comp.specialCooldown = 99999;
          game.update(1 / 60);
          if (orb.life <= 0) landed = orb.cachedHomingTarget;
        }
        expect(landed, isNotNull, reason: 'setup: the orb never landed');
        return (
          landed: landed!,
          thrownAt: thrownAt,
          fromAhead: (landed - ahead.position).distance,
        );
      }

      for (final seed in const [1, 2, 3]) {
        final plain = await landing(1, seed);
        expect(
          plain.landed,
          plain.thrownAt,
          reason: 'Far Throw alone keeps its point',
        );
        expect(plain.fromAhead, greaterThan(100), reason: 'setup: $seed');

        final arced = await landing(2, seed);
        expect((arced.landed - arced.thrownAt).distance, greaterThan(50));
        // Inside the reach of the field it blooms into (36-48 units).
        expect(
          arced.fromAhead,
          lessThan(36),
          reason: 'seed $seed: the orb\'s field should have bloomed on the '
              'body it swung toward',
        );
      }
    });

    test('a No Horizon shot that keeps finding bodies still leaves', () async {
      // The arc has a budget. Without one, a shot that never ages and always
      // finds a body ahead could circle a horde for the rest of the wave.
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: 3),
      );
      final field = <CosmicSurvivalEnemy>{target};
      for (var x = -5; x <= 5; x++) {
        for (var y = -5; y <= 5; y++) {
          final at = game.orb.position + Offset(x * 110.0 + 55, y * 110.0);
          if ((at - target.position).distance < 60) continue;
          field.add(dummy(target, at));
        }
      }
      game.enemies.addAll(field.where((e) => !identical(e, target)));
      final shots = await castSpecial(game, target);
      final shot = shots.firstWhere((p) => p.abilityFamily == 'mane');
      expect(shot.masteryNoLifetime, isTrue);
      final comp = game.activeCompanions[0]!;
      for (var i = 0; i < 60 * 40; i++) {
        if (!game.companionProjectiles.contains(shot)) break;
        for (final e in game.enemies) {
          if (!field.contains(e)) e.isDead = true;
        }
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      expect(shot.masteryArcTurned, greaterThan(0), reason: 'setup');
      expect(
        shot.masteryArcTurned,
        lessThanOrEqualTo(ManeTuning.arcTurnBudget + 1e-9),
      );
      expect(
        game.companionProjectiles.contains(shot),
        isFalse,
        reason: 'The shot should have spent its arc and left the arena.',
      );
    });

    test(
      'No Horizon stops the shot ageing, but the arena still ends it',
      () async {
        final (game, target) = await arena(
          element: 'Ice',
          snapshot: equip(ManeNodes.limitlessPath, throughTier: 3),
        );
        final shots = await castSpecial(game, target);
        expect(shots.first.masteryNoLifetime, isTrue);

        final life = shots.first.life;
        for (var i = 0; i < 60 * 3; i++) {
          game.update(1 / 60);
        }
        final alive = game.companionProjectiles.where(
          (p) => p.masteryNoLifetime,
        );
        if (alive.isNotEmpty) {
          expect(
            alive.first.life,
            closeTo(life, 0.01),
            reason: 'A shot that does not age must not lose lifetime.',
          );
        }
      },
    );

    test(
      'Endless Circuit puts the first shot into orbit, and only the first',
      () async {
        final (game, target) = await arena(
          element: 'Fire',
          snapshot: equip(ManeNodes.limitlessPath),
        );
        final shots = await castSpecial(game, target);
        expect(
          shots.length,
          greaterThan(1),
          reason: 'test setup: Fire should throw a fan',
        );

        final orbiters = shots.where((p) => p.holdOrbit).toList();
        expect(orbiters, hasLength(1));
        expect(identical(orbiters.first, shots.first), isTrue);
        // A fan keeps the rest of its cast for the target even on the cast
        // that builds the circuit.
        expect(shots.skip(1).every((p) => !p.holdOrbit), isTrue);
        // Five fireballs at an average Beauty since the final balance pass.
        expect(shots.length - 1, greaterThanOrEqualTo(3));
      },
    );

    test(
      'a Light ward gives up a ring to the circuit and regrows it',
      () async {
        // Light is the one element whose special never becomes a projectile in
        // flight — the ward swallows it — so it had no "first shot" to peel off
        // and received nothing at all from this path.
        final (game, target) = await arena(
          element: 'Light',
          snapshot: equip(ManeNodes.limitlessPath),
        );
        final comp = game.activeCompanions[0]!;
        comp.basicCooldown = 99999;
        for (var cast = 0; cast < 4; cast++) {
          // Back within casting range of the body each time; a special that
          // never fires builds no ward and proves nothing.
          comp.position = target.position - const Offset(140, 0);
          comp.specialCooldown = 0;
          game.update(1 / 60);
          for (var i = 0; i < 20; i++) {
            comp.basicCooldown = 99999;
            comp.specialCooldown = 99999;
            game.update(1 / 60);
          }
        }

        final circuits = game.companionProjectiles
            .where((p) => p.holdOrbit && p.masteryNoLifetime)
            .toList();
        expect(circuits, hasLength(1), reason: 'Light built no circuit.');
        expect(
          circuits.first.orbitRadius,
          greaterThan(400),
          reason: 'The ring should have left the Mane for the arena rim.',
        );
        expect(
          circuits.first.followSourceCompanion,
          isFalse,
          reason: 'A circuit that re-anchors to its caster is not a circuit.',
        );
        // And the ward carries on: the ring that left is replaced, not missed.
        expect(
          game.companionProjectiles
              .where((p) => p.holdOrbit && !p.masteryNoLifetime)
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(target.isDead, isFalse, reason: 'test setup only');
      },
    );

    test('the circuit rides the rim the waves walk in across', () async {
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath),
      );
      final shots = await castSpecial(game, target);
      final orbiter = shots.firstWhere((p) => p.holdOrbit);

      final radius = (orbiter.position - game.orb.position).distance;
      expect(radius, greaterThan(400));
      // It keeps that radius as it goes round rather than spiralling away.
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      if (game.companionProjectiles.contains(orbiter)) {
        expect(
          (orbiter.position - game.orb.position).distance,
          closeTo(radius, 2.0),
        );
      }
    });

    test('one cast builds the circuit and later casts fire normally', () async {
      // The single-shot elements are why this matters. Fifteen of seventeen
      // Manes throw one projectile, so taking the first shot of *every* cast
      // would mean those Manes never hit their target again.
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath),
      );
      final first = await castSpecial(game, target);
      expect(first.where((p) => p.holdOrbit), hasLength(1));

      final second = await castSpecial(game, target, clearFirst: false);
      expect(
        second.where((p) => p.holdOrbit),
        isEmpty,
        reason: 'The circuit is built once, not on every cast.',
      );
      expect(
        second.where((p) => !p.holdOrbit),
        isNotEmpty,
        reason: 'The second cast has to actually reach the target.',
      );
      expect(
        game.companionProjectiles.where((p) => p.holdOrbit).length,
        1,
        reason: 'A long run must not end up ringed by orbiters.',
      );
    });

    test('the circuit catches the wave crossing its rim', () async {
      // The capstone's whole claim is that the rim is a line every wave walks
      // across, and on device it was hitting almost nothing. The blade is
      // drawn far larger than the circle it collided as, which no one can see
      // on a shot that crosses the arena in a second but which every enemy
      // walking untouched through a parked blade shows plainly.
      final (game, target) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath),
      );
      final shots = await castSpecial(game, target);
      final circuit = shots.firstWhere((p) => p.masteryCircuit);
      final comp = game.activeCompanions[0]!;
      comp.basicCooldown = 99999;
      comp.specialCooldown = 99999;
      target.isDead = true;
      // The rest of the cast is still in flight and, on this path, never
      // expires — left in, it lands on the walkers and this stops being a
      // test about the rim.
      game.companionProjectiles.removeWhere((p) => !p.masteryCircuit);

      // Bodies walking inward, spread right around the rim.
      final crossing = <CosmicSurvivalEnemy>[];
      for (var i = 0; i < 12; i++) {
        final angle = i * pi / 6;
        final enemy = dummy(
          target,
          game.orb.position +
              Offset(cos(angle), sin(angle)) * (circuit.orbitRadius + 120),
        );
        crossing.add(enemy);
        game.enemies.add(enemy);
      }

      final hpBefore = [for (final e in crossing) e.hp];
      // Walk them in by hand — the arena's stand-ins do not move on their own
      // — over roughly two laps of the rim.
      const step = 1 / 60;
      for (var frame = 0; frame < 60 * 24; frame++) {
        // Keep the arena to the walkers: a wave arriving on its own schedule
        // reaches the orb mid-measurement and ends the run early, which is
        // what made this read 9 one time and 10 the next.
        for (final enemy in game.enemies) {
          if (!crossing.contains(enemy)) enemy.isDead = true;
        }
        for (final enemy in crossing) {
          final toOrb = game.orb.position - enemy.position;
          final d = toOrb.distance;
          if (d > 40) enemy.position += (toOrb / d) * 22 * step;
        }
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(step);
      }

      final hurt = [
        for (var i = 0; i < crossing.length; i++)
          if (crossing[i].hp < hpBefore[i]) i,
      ];
      expect(
        hurt.length,
        greaterThanOrEqualTo(9),
        reason:
            'The rim caught only ${hurt.length} of ${crossing.length} bodies '
            'walking across it. Colliding as a circle a fifth of the drawn '
            'blade, it caught 7.',
      );
    });

    test('the circuit lays nothing down that the element did not', () async {
      // The capstone stops the shot; it does not add an ability. An element
      // whose special already trails keeps trailing on the rim, and one that
      // does not leaves the rim clean.
      final (plain, plainTarget) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath),
      );
      await castSpecial(plain, plainTarget);
      plain.companionProjectiles.removeWhere((p) => !p.masteryCircuit);
      final plainComp = plain.activeCompanions[0]!;
      for (var frame = 0; frame < 60 * 12; frame++) {
        plainComp.basicCooldown = 99999;
        plainComp.specialCooldown = 99999;
        plain.update(1 / 60);
      }
      expect(
        plain.companionProjectiles.where((p) => !p.masteryCircuit),
        isEmpty,
        reason: 'An Ice blade leaves no trail, so its circuit must not either.',
      );

      final (dust, dustTarget) = await arena(
        element: 'Dust',
        snapshot: equip(ManeNodes.limitlessPath),
      );
      await castSpecial(dust, dustTarget);
      dust.companionProjectiles.removeWhere((p) => !p.masteryCircuit);
      final dustComp = dust.activeCompanions[0]!;
      for (var frame = 0; frame < 60 * 4; frame++) {
        dustComp.basicCooldown = 99999;
        dustComp.specialCooldown = 99999;
        dust.update(1 / 60);
      }
      expect(
        dust.companionProjectiles.where((p) => !p.masteryCircuit),
        isNotEmpty,
        reason: 'Dust trails as it travels; riding the rim does not stop it.',
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

    test('Rhythm makes the Mane faster', () async {
      // Rhythm buys cadence and only cadence. It used to also add damage and
      // width through Rising Tempo, which was dropped for being pure numbers
      // on a resource that already had a payoff.
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath, throughTier: 1),
      );
      castBasic(game, target, gap: 180);
      final coldCooldown = game.activeCompanions[0]!.basicCooldown;

      for (var i = 0; i < 6; i++) {
        landBasic(game, target);
      }
      expect(rhythmOf(game, 0), greaterThan(0));

      castBasic(game, target, gap: 180);
      expect(game.activeCompanions[0]!.basicCooldown, lessThan(coldCooldown));
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
      final comp = game.activeCompanions[0]!;
      for (var i = 0; i < 60 * 4; i++) {
        // Nothing may be hit while the cast ages out: the spawner keeps
        // producing bodies, and one wandering into the slashes turns this
        // miss into a hit and the test into a coin flip.
        for (final enemy in game.enemies) {
          enemy.isDead = true;
        }
        comp.basicCooldown = 99999;
        comp.specialCooldown = 99999;
        game.update(1 / 60);
      }
      expect(rhythmOf(game, 0), lessThan(banked));
    });

    /// Casts the Mane's special at [target], and nothing else.
    void castSpecialNow(CosmicSurvivalGame game, CosmicSurvivalEnemy target) {
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.specialCooldown = 0;
      comp.basicCooldown = 999;
      game.update(1 / 60);
      comp.specialCooldown = 999;
    }

    test('Tempest Ring throws eight slashes on every fourth attack', () async {
      Future<List<int>> ringSlashes(int throughTier) async {
        final (game, target) = await arena(
          snapshot: equip(ManeNodes.resonancePath, throughTier: throughTier),
        );
        return [
          for (var i = 0; i < 8; i++)
            castBasic(game, target).where((p) => p.masteryGenerated).length,
        ];
      }

      expect(await ringSlashes(3), [0, 0, 0, 8, 0, 0, 0, 8]);
      expect(await ringSlashes(2), everyElement(0));
    });

    test('below five Rhythm the special spends nothing', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath),
      );
      for (var i = 0; i < 3; i++) {
        landBasic(game, target);
      }
      final banked = rhythmOf(game, 0);
      expect(banked, inInclusiveRange(1, ManeTuning.maxRhythm - 1));

      castSpecialNow(game, target);
      expect(rhythmOf(game, 0), banked, reason: 'Only a full five is spent.');
      expect(encoreOf(game, 0), 0);
      expect(game.mastery.telemetryFor(0).capstoneActivations, 0);
    });

    test(
      'Encore spends a full five, and cannot refresh itself',
      () async {
        final (game, target) = await arena(
          snapshot: equip(ManeNodes.resonancePath),
        );
        for (var i = 0; i < 8; i++) {
          landBasic(game, target);
        }
        expect(rhythmOf(game, 0), ManeTuning.maxRhythm);

        castSpecialNow(game, target);
        expect(rhythmOf(game, 0), 0, reason: 'The Encore spends all five.');
        expect(encoreOf(game, 0), greaterThan(0));
        expect(game.mastery.telemetryFor(0).capstoneActivations, 1);
        final opened = encoreOf(game, 0);

        // A full reserve again, inside the Encore: casting must neither
        // restart the window nor spend the reserve on nothing.
        for (var i = 0; i < 6; i++) {
          landBasic(game, target);
        }
        expect(rhythmOf(game, 0), ManeTuning.maxRhythm);
        expect(encoreOf(game, 0), greaterThan(0), reason: 'setup');
        castSpecialNow(game, target);
        expect(encoreOf(game, 0), lessThan(opened));
        expect(rhythmOf(game, 0), ManeTuning.maxRhythm);
        expect(game.mastery.telemetryFor(0).capstoneActivations, 1);
      },
    );

    test('Encore widens the pair, and only widens it', () async {
      final (game, target) = await arena(
        snapshot: equip(ManeNodes.resonancePath),
      );
      final cold = castBasic(game, target);
      for (var i = 0; i < 8; i++) {
        landBasic(game, target);
      }
      castSpecialNow(game, target);
      expect(encoreOf(game, 0), greaterThan(0), reason: 'setup');
      final hot = castBasic(game, target);
      expect(hot, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(
          hot[i].radiusMultiplier / cold[i].radiusMultiplier,
          closeTo(ManeTuning.encoreWidthScale, 1e-9),
        );
        expect(
          hot[i].visualScale / cold[i].visualScale,
          closeTo(ManeTuning.encoreWidthScale, 1e-9),
        );
        expect(hot[i].damage, closeTo(cold[i].damage, 1e-9));
        expect(hot[i].speedMultiplier, cold[i].speedMultiplier);
      }
    });

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

      // A body that the next basic will finish. The special is parked for
      // this measurement: an Encore is bought back by a BASIC kill, and a
      // catapult landing first would take the kill and prove nothing.
      comp.specialCooldown = 999;
      // Enough that a stray residual tick cannot take the kill, little enough
      // that one blade of the pair finishes it.
      target.hp = 12;
      final before = encoreOf(game, 0);
      final spentFrom = game.stats.timeElapsed;
      landBasic(game, target);
      // An Encore burns down with the clock, so without the kill the timer
      // would read exactly `before - spent`. Measure the clock rather than
      // assuming how many frames flying the shot in happens to take.
      final spent = game.stats.timeElapsed - spentFrom;
      expect(target.isDead, isTrue, reason: 'setup: the basic should kill');
      expect(
        encoreOf(game, 0),
        greaterThan(before - spent),
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
          snapshot: equip(ManeNodes.resonancePath, throughTier: 1),
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
        snapshot: equip(ManeNodes.resonancePath, throughTier: 1),
      );
      final comp = game.activeCompanions[0]!;
      // A ring rather than a line: the companion picks its own target and
      // therefore its own firing angle, so a line laid along one axis is only
      // sometimes the axis it shoots down. A ring is whichever way it fires.
      final line = [
        for (var i = 0; i < 8; i++)
          dummy(
            target,
            comp.position + Offset(cos(i * pi / 4) * 70, sin(i * pi / 4) * 70),
          ),
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

      // 4 / 5 / 6 inside the board's 3-8 since the final balance pass
      // (2026-10-10); it was 4 / 8 / 16.
      expect(fireballs(2.6), 4);
      expect(fireballs(4.31), 5);
      expect(fireballs(11.75), 6);
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

  group('nothing about attack speed is capped', () {
    test('cadence keeps paying past the perfect anchor', () {
      double cadence(double speed) =>
          CosmicBalance.companionCooldownReduction(speed);

      final perfect = cadence(kAbilityStatPerfect);
      // Enhancement ranks push a stat past 12. Those points have to be worth
      // something: the old curve stopped dead at a Speed of 9.
      expect(cadence(13.5), greaterThan(perfect));
      expect(cadence(15.3), greaterThan(cadence(13.5)));
      expect(cadence(30), greaterThan(cadence(15.3)));
    });

    test('but it cannot run away either', () {
      final perfect = CosmicBalance.companionCooldownReduction(
        kAbilityStatPerfect,
      );
      // Logarithmic, so absurd stats are worth a fraction more rather than a
      // multiple more — an uncapped linear tail would reach zero cooldown.
      expect(
        CosmicBalance.companionCooldownReduction(60),
        lessThan(perfect * 1.6),
      );
    });

    test('a count still stops, because half a fireball is not a thing', () {
      expect(scaledAbilityCount(60, atLow: 4, atAverage: 8, atPerfect: 16), 16);
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
      // Ice is a single shot, so Beauty's coverage is the ball getting wider,
      // up to the hitbox cap (kManeHitboxInflationMax, 2026-10-20): at Beauty
      // 9 the uncapped ball was half again an average one's.
      expect(pretty.radius, greaterThan(average.radius * 1.1));
      expect(pretty.projectiles, average.projectiles);
      // Wider means more coverage, not a hidden damage multiplier. Against a
      // fixed six-body ring both casts catch the same targets, so the totals
      // should land on top of each other: which body takes which of the
      // capped pierce hits shifts by a few percent as the ball widens, and
      // that is noise, not power. What matters is that width neither buys
      // damage nor costs it.
      expect(
        pretty.damage,
        closeTo(average.damage, average.damage * 0.12),
        reason: 'Beauty must neither buy damage nor lose it.',
      );
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
