import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Let as the opening act (2026-10-20 rebuild): strong from the first
/// wave, falling behind with breeding. The mechanics that make it so, driven
/// through the real survival game:
///
/// - the meteor is aimed at the crowd, not at the one body the Let shoots;
/// - an empty landing still lays the ground the element leaves on contact;
/// - Dark's follow-ups spread round the kill instead of all landing west;
/// - a cast with no room in the projectile list waits instead of spending
///   its cooldown on a dropped meteor;
/// - the contact effects reach past the crater, onto the bodies it did not
///   kill.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember let(String element) => CosmicPartyMember(
    instanceId: 'let-0',
    baseId: 'LET01',
    displayName: 'Let $element',
    family: 'Let',
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

  /// A cleared arena with one Let out: the opening wave is dead and the ship
  /// is parked far away with its guns held.
  Future<CosmicSurvivalGame> arena(String element) async {
    final game = CosmicSurvivalGame(
      party: [let(element)],
      onGameOver: () {},
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
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.orb.shieldHp = 0;
    game.ship.position = game.orb.position + const Offset(0, 900);
    game.ship.fireTimer = -1e9;
    return game;
  }

  CosmicSurvivalEnemy body(
    CosmicSurvivalGame game,
    Offset at, {
    double hp = 1e6,
    double? maxHp,
  }) {
    final e = CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: maxHp ?? hp,
      speed: 0,
      damage: 0,
      radius: 11,
      tier: EnemyTier.drone,
      element: 'Ice',
      target: CosmicEnemyTarget.orb,
      conduct: EnemyConduct.stalk,
    );
    game.enemies.add(e);
    return e;
  }

  /// Frames with the Let's own attacks held unless [cast], and anything the
  /// spawner sends in put down at once.
  void run(
    CosmicSurvivalGame game,
    int frames, {
    Set<CosmicSurvivalEnemy> keep = const {},
    bool cast = false,
  }) {
    for (var f = 0; f < frames; f++) {
      for (final comp in game.activeCompanions.values) {
        comp.basicCooldown = 99999;
        if (!cast) comp.specialCooldown = 99999;
      }
      for (final e in game.enemies) {
        if (!keep.contains(e)) e.isDead = true;
      }
      game.update(1 / 60);
    }
  }

  /// A special meteor of [element] from the Let in slot 0, thrown at [spot].
  Projectile meteor(String element, Offset spot, {required Offset from}) {
    final m = createCosmicSpecialAbility(
      origin: from,
      baseAngle: 0,
      family: 'let',
      element: element,
      damage: 40,
      maxHp: 400,
      casterBeauty: 4.25,
      casterIntelligence: 4.25,
      casterStrength: 4.25,
      targetPos: spot,
    ).projectiles.first;
    m.sourceSlotIndex = 0;
    return m;
  }

  /// Drops [m] and runs one frame past its landing.
  void land(
    CosmicSurvivalGame game,
    Projectile m, {
    Set<CosmicSurvivalEnemy> keep = const {},
  }) {
    game.companionProjectiles.add(m);
    for (var i = 0; i < 120 && m.isDescending; i++) {
      run(game, 1, keep: keep);
    }
    run(game, 1, keep: keep);
  }

  Iterable<Projectile> letMeteors(CosmicSurvivalGame game) =>
      game.companionProjectiles.where(
        (p) =>
            p.sourceSlotIndex == 0 &&
            p.isDescending &&
            p.visualStyle == ProjectileVisualStyle.meteor,
      );

  group('crowd aim', () {
    test('the meteor comes down on the thickest crowd in reach', () async {
      final game = await arena('Poison');
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      // A lone body close in, and a clump of eight further out the other way.
      final lone = body(game, at + const Offset(130, 0));
      final clumpCentre = at + const Offset(-220, 40);
      final clump = <CosmicSurvivalEnemy>[
        for (var i = 0; i < 8; i++)
          body(
            game,
            clumpCentre +
                Offset(cos(i * pi / 4), sin(i * pi / 4)) * (i.isEven ? 30 : 55),
          ),
      ];
      final keep = {lone, ...clump};
      run(game, 2, keep: keep);
      comp.specialCooldown = 0;
      for (var f = 0; f < 30 && letMeteors(game).isEmpty; f++) {
        run(game, 1, keep: keep, cast: true);
      }
      final thrown = letMeteors(game).toList();
      expect(thrown, hasLength(1), reason: 'the Let did not cast');
      final impact = thrown.single.skyfallImpact;
      final crater = letSkyfallBlastRadius(thrown.single);
      final caught = clump
          .where((e) => (e.position - impact).distance <= crater)
          .length;
      expect(
        caught,
        clump.length,
        reason:
            'the crater (radius ${crater.round()}) came down '
            '${(impact - clumpCentre).distance.round()} from the clump',
      );
      expect((impact - lone.position).distance, greaterThan(crater));
    });

    test('a boss the Let is going for still takes the meteor', () async {
      final game = await arena('Poison');
      final comp = game.activeCompanions[0]!;
      final at = comp.position;
      final b = game.spawner.createBossForWave(5, at + const Offset(160, 0))!;
      b
        ..position = at + const Offset(160, 0)
        ..spawnIntroTimer = 0
        ..chillTimer = 1e9
        ..chillMultiplier = 0
        ..shieldUp = false
        ..shieldTimer = 1e9;
      game.activeBoss = b;
      final clump = <CosmicSurvivalEnemy>[
        for (var i = 0; i < 6; i++)
          body(game, at + Offset(-220.0 + i * 12, 30.0 - i * 8)),
      ];
      final keep = clump.toSet();
      run(game, 2, keep: keep);
      comp.specialCooldown = 0;
      for (var f = 0; f < 30 && letMeteors(game).isEmpty; f++) {
        run(game, 1, keep: keep, cast: true);
      }
      final thrown = letMeteors(game).toList();
      expect(thrown, hasLength(1), reason: 'the Let did not cast');
      expect(
        (thrown.single.skyfallImpact - b.position).distance,
        lessThan(30),
      );
    });
  });

  group('empty landing', () {
    Future<List<Projectile>> groundAfterEmptyLanding(String element) async {
      final game = await arena(element);
      final spot = game.orb.position + const Offset(320, 0);
      land(game, meteor(element, spot, from: game.orb.position));
      return game.companionProjectiles
          .where(
            (p) =>
                p.abilityFamily == 'let' &&
                p.stationary &&
                p.element == element &&
                p.life > 0 &&
                (p.position - spot).distance < 1,
          )
          .toList();
    }

    for (final element in ['Lava', 'Poison', 'Dust', 'Earth']) {
      test('a $element meteor on empty ground still lays its ground', () async {
        final ground = await groundAfterEmptyLanding(element);
        expect(ground, hasLength(1));
        expect(
          ground.single.tickEffect,
          CosmicAbilityRuntime.letContactZone(element)!.tick,
        );
      });
    }

    for (final element in ['Mud', 'Light', 'Steam', 'Plant']) {
      test('$element\'s kill ground is still earned by a kill', () async {
        expect(await groundAfterEmptyLanding(element), isEmpty);
      });
    }
  });

  group('Dark follow-ups', () {
    test('spread by angle round the kill', () {
      final ring = [
        for (var i = 0; i < 24; i++)
          Offset(cos(i * pi / 12), sin(i * pi / 12)) * (260.0 + (i % 3) * 20),
      ];
      final aims = CosmicAbilityRuntime.darkLetFollowupAims(
        centre: Offset.zero,
        bodies: ring,
        count: 5,
        startAngle: 0.3,
        spacing: 200,
        minDistance: 180,
      );
      expect(aims, hasLength(5));
      final slices = {
        for (final a in aims)
          (((atan2(a.dy, a.dx) - 0.3) % (2 * pi)) / (2 * pi / 5)).floor(),
      };
      expect(slices, hasLength(5), reason: 'two follow-ups shared a slice');
      for (final a in aims) {
        expect(ring.any((b) => (b - a).distance < 0.01), isTrue);
      }
    });

    test('a slice with nobody in it takes a body clear of the others, '
        'or open ground', () {
      // Everyone stands east of the kill.
      final east = [
        for (var i = 0; i < 6; i++) Offset(250, -150.0 + i * 60),
      ];
      final aims = CosmicAbilityRuntime.darkLetFollowupAims(
        centre: Offset.zero,
        bodies: east,
        count: 3,
        startAngle: 0,
        spacing: 200,
      );
      expect(aims, hasLength(3));
      for (var i = 0; i < aims.length; i++) {
        for (var j = i + 1; j < aims.length; j++) {
          expect((aims[i] - aims[j]).distance, greaterThan(150));
        }
      }
    });

    test('in the game, the bombardment falls all round the kill', () async {
      final game = await arena('Dark');
      // Clear of the orb, so no body in the ring is standing on it.
      final spot = game.orb.position + const Offset(0, -560);
      final victim = body(game, spot, hp: 1);
      final ring = <CosmicSurvivalEnemy>[
        for (var i = 0; i < 16; i++)
          body(game, spot + Offset(cos(i * pi / 8), sin(i * pi / 8)) * 300),
      ];
      final m = meteor('Dark', spot, from: game.orb.position);
      final crater = letSkyfallBlastRadius(m);
      expect(300, greaterThan(CosmicAbilityRuntime.kLetRimReach * crater));
      land(game, m, keep: {victim, ...ring});
      expect(victim.isDead, isTrue);
      final followUps = game.companionProjectiles
          .where(
            (p) =>
                p.element == 'Dark' &&
                p.effectStacks == 1 &&
                p.visualStyle == ProjectileVisualStyle.meteor,
          )
          .toList();
      expect(followUps.length, greaterThanOrEqualTo(3));
      // Unit vectors to the aims nearly cancel when they are spread round
      // the kill; all on one side they add up to almost their count.
      var sum = Offset.zero;
      for (final p in followUps) {
        final d = p.skyfallImpact - spot;
        sum += d / d.distance;
        // On the ring round the kill, not back in the crater it cleared.
        expect(d.distance, inInclusiveRange(crater, 320));
      }
      expect(
        sum.distance,
        lessThan(followUps.length * 0.5),
        reason: 'aims: ${[for (final p in followUps) p.skyfallImpact - spot]}',
      );
    });
  });

  group('projectile room', () {
    test('a Let with no room for its meteor keeps its cooldown', () async {
      final game = await arena('Poison');
      final comp = game.activeCompanions[0]!;
      final target = body(game, comp.position + const Offset(150, 0));
      final keep = {target};
      run(game, 2, keep: keep);
      // Fill the shared list to its 220 cap with inert, long-lived pieces.
      game.companionProjectiles.clear();
      while (game.companionProjectiles.length < 220) {
        game.companionProjectiles.add(
          Projectile(
            position: game.orb.position + const Offset(0, -2000),
            angle: 0,
            element: 'Fire',
            damage: 0,
            life: 1000,
            speedMultiplier: 0,
            stationary: true,
          ),
        );
      }
      comp.specialCooldown = 0;
      run(game, 10, keep: keep, cast: true);
      expect(letMeteors(game), isEmpty);
      expect(
        comp.specialCooldown,
        lessThanOrEqualTo(0),
        reason: 'the cooldown was spent on a meteor the list dropped',
      );
      // Room again: it throws, and only now does the cooldown run.
      game.companionProjectiles.removeRange(0, 20);
      for (var f = 0; f < 10 && letMeteors(game).isEmpty; f++) {
        run(game, 1, keep: keep, cast: true);
      }
      expect(letMeteors(game), hasLength(1));
      expect(comp.specialCooldown, greaterThan(0));
    });

    test('a Let\'s ground lives its authored life; Plant\'s vines keep four '
        'casts', () {
      for (final element in ['Lava', 'Steam', 'Light', 'Mud', 'Dust']) {
        expect(CasterPieces.windowFor('let', element), isNull, reason: element);
      }
      expect(
        CasterPieces.windowFor('let', 'Plant'),
        CasterPieces.letVineCastWindow,
      );
    });
  });

  group('past the rim', () {
    /// A [element] meteor landing on a tough body at the spot, with one body
    /// in the ring just past the crater and one beyond the rim.
    Future<(CosmicSurvivalEnemy, CosmicSurvivalEnemy, CosmicSurvivalEnemy)>
    landWithRing(
      String element, {
      double ringHp = 1e6,
      double ringMaxHp = 1e6,
    }) async {
      final game = await arena(element);
      final spot = game.orb.position + const Offset(320, 0);
      final m = meteor(element, spot, from: game.orb.position);
      final crater = letSkyfallBlastRadius(m);
      final rim = CosmicAbilityRuntime.letRimReach(m);
      expect(rim, greaterThan(crater * 1.2));
      final struck = body(game, spot);
      final ring = body(
        game,
        spot + Offset(0, (crater + rim) / 2),
        hp: ringHp,
        maxHp: ringMaxHp,
      );
      final beyond = body(
        game,
        spot - Offset(0, rim + 160),
        hp: ringHp,
        maxHp: ringMaxHp,
      );
      land(game, m, keep: {struck, ring, beyond});
      return (struck, ring, beyond);
    }

    test('Ice freezes the ring past the crater', () async {
      final (struck, ring, beyond) = await landWithRing('Ice');
      expect(struck.slowMultiplier, lessThanOrEqualTo(0.05));
      expect(ring.slowMultiplier, lessThanOrEqualTo(0.05));
      expect(ring.slowTimer, greaterThan(2.5));
      expect(beyond.slowTimer, 0);
    });

    test('Water\'s splash reaches the ring past the crater', () async {
      final (_, ring, beyond) = await landWithRing('Water');
      expect(ring.hp, lessThan(ring.maxHp));
      expect(beyond.hp, beyond.maxHp);
    });

    test('Lightning chains out to the ring past the crater', () async {
      final (_, ring, beyond) = await landWithRing('Lightning');
      expect(ring.hp, lessThan(ring.maxHp));
      expect(beyond.hp, beyond.maxHp);
    });

    test('Spirit\'s execute rolls for the survivors out to the rim', () async {
      // At a third of its health a body is executed without a roll, as the
      // struck one is.
      final (_, ring, beyond) = await landWithRing(
        'Spirit',
        ringHp: 3e5,
        ringMaxHp: 1e6,
      );
      expect(ring.isDead, isTrue);
      expect(beyond.isDead, isFalse);
    });

    test('Crystal and Earth sweep the ring past the crater', () async {
      for (final element in ['Crystal', 'Earth']) {
        final (_, ring, beyond) = await landWithRing(element);
        expect(ring.hp, lessThan(ring.maxHp), reason: element);
        expect(beyond.hp, beyond.maxHp, reason: element);
      }
    });
  });

  group('cadence', () {
    double interval(int special, double recharge, {String element = 'Mud'}) =>
        alchemonSpecialInterval(
          family: 'let',
          element: element,
          specialCooldownReduction: recharge,
          abilityAtk: special,
        );

    test('about 3 s at Potential 20 and about 2.4 s at the top', () {
      // The survival benchmark's Mud Let: SPECIAL 40 and recharge 0.93 at
      // Potential 20, SPECIAL 165 and recharge 1.34 at 100 + Enhancement 10.
      expect(interval(40, 0.93), closeTo(3.0, 0.15));
      expect(interval(165, 1.34), inInclusiveRange(2.0, 2.45));
    });

    test('a stronger SPECIAL buys a Let far less cadence than a Mane', () {
      double gain(String family) {
        double at(int special) => alchemonSpecialInterval(
          family: family,
          element: 'Mud',
          specialCooldownReduction: 1.0,
          abilityAtk: special,
        );
        return at(40) / at(160);
      }

      expect(gain('let'), lessThan(1.1));
      expect(gain('mane'), greaterThan(2.0));
    });
  });
}
