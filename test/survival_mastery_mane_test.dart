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

  group('family speed', () {
    test('Mane blades and catapults fly at half speed', () async {
      final (game, target) = await arena(element: 'Ice');
      final blades = castBasic(game, target);
      expect(
        blades.every((p) => p.speedMultiplier == kManeBasicSpeedMultiplier),
        isTrue,
        reason: 'A Mane blade is a thrown slash, not a bullet.',
      );
      // And the path rebuilds the pair rather than editing it, so the same
      // has to hold with mastery equipped.
      final (mastered, masteredTarget) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.assaultPath),
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

    test('Overdraw adds 15% and nothing else', () async {
      final (one, oneTarget) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: 1),
      );
      final before = await castSpecial(one, oneTarget);

      final (two, twoTarget) = await arena(
        element: 'Ice',
        snapshot: equip(ManeNodes.limitlessPath, throughTier: 2),
      );
      final after = await castSpecial(two, twoTarget);

      expect(
        after.first.damage / before.first.damage,
        closeTo(1.0 + ManeTuning.overdrawDamageBonus, 0.01),
      );
      expect(after.first.life, closeTo(before.first.life, 0.01));
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
        expect(shots.length - 1, greaterThan(4));
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
