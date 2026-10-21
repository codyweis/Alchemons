import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/mask_trap_placement.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mask.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mask the gatekeeper and Mane the clearer (2026-10-20 rebuild), driven
/// through the real survival game where a headless test can reach it:
///
/// - Mask traps go across the orb's busiest approach, not round the Mask;
/// - a Mask trap outlives two recasts;
/// - Ice's amp is the board's 2-5x by Beauty; Dark's suction pulls; Spirit's
///   wisp count sets how soon a clear comes; Air's power sets its shove;
/// - Contagion's spread stays inside its caps;
/// - a Mane catapult's life and hitbox are inside their caps, and Earth and
///   Dark crawl slower than the rest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember mask(String element, {double stat = 4.25}) =>
      CosmicPartyMember(
        instanceId: 'mask-0',
        baseId: 'MSK01',
        displayName: 'Mask $element',
        family: 'Mask',
        element: element,
        level: 10,
        slotIndex: 0,
        statSpeed: stat,
        statIntelligence: stat,
        statStrength: stat,
        statBeauty: stat,
        statSpeedPotential: 50,
        statIntelligencePotential: 50,
        statStrengthPotential: 50,
        statBeautyPotential: 50,
        staminaBars: 3,
        staminaMax: 3,
      );

  SurvivalFamilyMasterySnapshot contagion() {
    final path = FamilyMasteryCatalog.pathFor(
      CreatureFamily.mask,
      MaskNodes.contagionPath,
    )!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'mask-0',
        family: CreatureFamily.mask,
        pathId: path.id,
        activeNodeIds: path.nodes.map((n) => n.id),
      ),
    });
  }

  /// A cleared arena with one Mask out, its attacks held, the ship parked far
  /// from everything.
  Future<CosmicSurvivalGame> arena(
    String element, {
    double stat = 4.25,
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [mask(element, stat: stat)],
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
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.companionProjectiles.clear();
    game.orb.shieldHp = 0;
    game.ship.position = game.orb.position + const Offset(0, 900);
    game.ship.fireTimer = -1e9;
    return game;
  }

  CosmicSurvivalEnemy body(
    CosmicSurvivalGame game,
    Offset at, {
    double hp = 1e6,
    double speed = 0,
    EnemyTier tier = EnemyTier.drone,
  }) {
    final e = CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: hp,
      speed: speed,
      damage: 0,
      radius: 11,
      tier: tier,
      element: 'Ice',
      target: CosmicEnemyTarget.orb,
      conduct: EnemyConduct.stalk,
    );
    game.enemies.add(e);
    return e;
  }

  /// Frames with the Mask's darts held and its special held unless [cast];
  /// anything the spawner sends in is put down at once.
  void run(
    CosmicSurvivalGame game,
    int frames, {
    required Set<CosmicSurvivalEnemy> keep,
    bool cast = false,
    void Function()? each,
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
      each?.call();
    }
  }

  List<Projectile> maskPieces(CosmicSurvivalGame game) => game
      .companionProjectiles
      .where((p) => p.abilityFamily == 'mask' && p.stationary)
      .toList();

  Projectile maskCast(String element, {double stat = 4.25}) =>
      createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 0,
        family: 'mask',
        element: element,
        damage: 60,
        maxHp: 400,
        casterPower: stat,
        casterBeauty: stat,
        casterIntelligence: stat,
        casterStrength: stat,
        targetPos: Offset.zero,
      ).projectiles.first..sourceSlotIndex = 0;

  group('Mask — gatekeeper', () {
    test("traps land on the orb's approach, not round the Mask", () async {
      final game = await arena('Lava');
      final orb = game.orb.position;
      final comp = game.activeCompanions[0]!;
      // The wave comes down one lane, east of the orb; the Mask is on the
      // far side of it, shooting at the one body near it.
      final keep = <CosmicSurvivalEnemy>{};
      for (var i = 0; i < 30; i++) {
        keep.add(
          body(
            game,
            orb + Offset(500.0 + i * 18, (i % 5 - 2) * 30.0),
          ),
        );
      }
      comp.position = orb + const Offset(-450, 0);
      keep.add(body(game, orb + const Offset(-540, 0)));
      comp.specialCooldown = 0;
      for (var f = 0; f < 60 && maskPieces(game).isEmpty; f++) {
        run(game, 1, keep: keep, cast: true);
      }
      final pools = maskPieces(game);
      expect(pools, isNotEmpty, reason: 'the Mask never cast');
      for (final p in pools) {
        final fromOrb = p.position - orb;
        expect(
          fromOrb.distance,
          inInclusiveRange(220.0, 730.0),
          reason: 'a pool off the approach band: ${fromOrb.distance}',
        );
        expect(
          atan2(fromOrb.dy, fromOrb.dx).abs(),
          lessThan(0.6),
          reason: 'a pool off the lane: $fromOrb',
        );
        expect(
          (p.position - comp.position).distance,
          greaterThan(500),
          reason: 'a pool laid round the Mask',
        );
      }
    });

    test('the lane is the busiest bearing, between 380 and 570 out', () {
      final lane = MaskApproachLane();
      // A thin stream north, a thick one west.
      for (var i = 0; i < 6; i++) {
        lane.add(Offset(0, -600.0 - i * 40));
      }
      for (var i = 0; i < 20; i++) {
        lane.add(Offset(-500.0 - i * 25, (i % 3 - 1) * 20.0));
      }
      final aim = lane.aim(Offset.zero)!;
      expect(atan2(aim.dy, aim.dx).abs(), greaterThan(pi - 0.3));
      expect(aim.distance, inInclusiveRange(380.0, 570.0));
      lane.reset();
      expect(lane.aim(Offset.zero), isNull);
      expect(
        maskApproachFallback(Offset.zero, const Offset(0, 50)).distance,
        kMaskApproachNear,
      );
    });

    test('a Mask trap outlives two recasts and fades at the third', () {
      final field = <Projectile>[
        maskCast('Lava'),
        maskCast('Air'),
        maskCast('Mud'),
      ];
      for (final p in field) {
        expect(CasterPieces.holdsPlace(p), isTrue);
      }
      final lives = [for (final p in field) p.life];
      for (var i = 0; i < 2; i++) {
        for (final p in field) {
          CasterPieces.onCast(
            [p],
            slot: 0,
            family: 'Mask',
            element: p.element,
          );
        }
      }
      expect([for (final p in field) p.life], lives);
      for (final p in field) {
        CasterPieces.onCast([p], slot: 0, family: 'Mask', element: p.element);
        expect(p.life, CasterPieces.retireFade);
      }
    });

    test('the Ice amp grows with Beauty inside the board\'s 2x-5x', () {
      final amps = [
        for (final stat in [1.0, 2.5, 3.5, 4.25, 6.3, 8.75, 11.4, 30.0])
          maskIceAmpOf(maskCast('Ice', stat: stat)),
      ];
      for (var i = 1; i < amps.length; i++) {
        expect(amps[i], greaterThanOrEqualTo(amps[i - 1]));
      }
      expect(amps.first, kMaskIceAmpMin);
      expect(amps[3], closeTo(2.4, 1e-9), reason: 'average keeps the old amp');
      expect(amps[4], inInclusiveRange(2.8, 3.3), reason: 'Potential 80');
      expect(amps[6], inInclusiveRange(4.0, 4.8), reason: 'P100 + E10');
      expect(amps.last, lessThanOrEqualTo(kMaskIceAmpMax));
    });

    test(
      'a bred Ice pillar amps an ally and the ship past the old 4x',
      () async {
        final game = await arena('Ice');
        final comp = game.activeCompanions[0]!;
        final pillar = maskCast('Ice', stat: 30)..position = comp.position;
        final amp = maskIceAmpOf(pillar);
        expect(amp, greaterThan(4.0));
        game.companionProjectiles.add(pillar);
        game.updatePersistentAbilityEffects(0.35);
        expect(comp.damageAmp, closeTo(amp, 1e-9));
        expect(game.maskShipDamageAmp, 1);
        pillar.position = game.ship.position;
        expect(game.maskShipDamageAmp, closeTo(amp, 1e-9));
      },
    );

    test('Dark draws a body inside its radius in, against its walk', () async {
      final game = await arena('Dark');
      final orb = game.orb.position;
      final hole = maskCast('Dark')..position = orb + const Offset(450, 160);
      game.companionProjectiles.add(hole);
      // Walking west toward the orb, 160 px north of the hole and well
      // inside its suction: the walk is square to the pull.
      final walker = body(
        game,
        orb + const Offset(450, 0),
        speed: 90,
        tier: EnemyTier.wisp,
      );
      final keep = {walker};
      final startDy = walker.position.dy;
      var thrown = false;
      run(
        game,
        60,
        keep: keep,
        each: () {
          if ((walker.position - hole.position).distance > 600) thrown = true;
        },
      );
      expect(hole.effectRadius, greaterThan(160));
      expect(
        thrown || walker.position.dy - startDy > 60,
        isTrue,
        reason:
            'pulled ${(walker.position.dy - startDy).toStringAsFixed(1)} px '
            'toward the hole in a second',
      );
    });

    test('the pull is stronger toward the mouth and beats a wisp\'s walk', () {
      const r = 240.0;
      expect(
        CosmicAbilityRuntime.voidPullSpeed(40, r),
        greaterThan(CosmicAbilityRuntime.voidPullSpeed(200, r)),
      );
      expect(CosmicAbilityRuntime.voidPullSpeed(r, r), greaterThan(60));
      // What one tick's shove carries a body over the tick.
      const tick = 0.35;
      final v0 = CosmicAbilityRuntime.voidPullImpulse(120, r, tick: tick);
      const k = CosmicAbilityRuntime.knockbackDamping;
      final carried = v0 * (1 - exp(-k * tick)) / k;
      expect(
        carried,
        closeTo(CosmicAbilityRuntime.voidPullSpeed(120, r) * tick, 1e-6),
      );
    });

    test("Spirit's wisp count sets how soon a clear comes", () {
      double castsPerClear(int perCast) =>
          maskSpiritClearThreshold(perCast) / perCast;
      expect(castsPerClear(6), greaterThan(castsPerClear(8)));
      expect(castsPerClear(8), greaterThan(castsPerClear(10)));
      expect(castsPerClear(8), closeTo(1.5, 1e-9));
      expect(castsPerClear(14), 1.0, reason: 'never more than once a cast');
      expect(castsPerClear(20), 1.0);
      for (var n = 0; n <= 25; n++) {
        expect(maskSpiritClearThreshold(n), greaterThanOrEqualTo(n));
        expect(maskSpiritClearThreshold(n), greaterThanOrEqualTo(12));
      }
    });

    test("Air's power sets its shove, inside a ceiling", () {
      final weak = maskCast('Air', stat: 2.5);
      final strong = maskCast('Air', stat: 11.4);
      expect(strong.effectPower, greaterThan(weak.effectPower));
      expect(
        CosmicAbilityRuntime.maskAirImpulse(strong.effectPower),
        greaterThan(CosmicAbilityRuntime.maskAirImpulse(weak.effectPower)),
      );
      expect(
        CosmicAbilityRuntime.maskAirImpulse(1e6),
        CosmicAbilityRuntime.maskAirImpulseCeiling,
      );
    });

    test('an Air pad shoves a body by its power in the real game', () async {
      Future<double> shove(double stat) async {
        final game = await arena('Air', stat: stat);
        final orb = game.orb.position;
        final pad = maskCast('Air', stat: stat)
          ..position = orb + const Offset(400, 0);
        final victim = body(game, pad.position + const Offset(12, 0));
        game.resolveAbilityHit(pad, victim, killed: false);
        return victim.knockbackVelocity.distance;
      }

      final weak = await shove(2.5), strong = await shove(11.4);
      expect(strong, greaterThan(weak * 1.15));
      expect(
        strong,
        lessThanOrEqualTo(CosmicAbilityRuntime.maskAirImpulseCeiling),
      );
    });
  });

  group('Contagion stays inside its caps', () {
    test('a packed crowd never carries more than the cap', () async {
      final game = await arena('Lava', snapshot: contagion());
      final orb = game.orb.position;
      // More bodies than one Mask may infect, packed inside one spread.
      final crowd = MaskTuning.carrierCap + 60;
      final keep = <CosmicSurvivalEnemy>{};
      for (var i = 0; i < crowd; i++) {
        keep.add(
          body(
            game,
            orb + Offset(400.0 + (i % 18) * 6, (i ~/ 18) * 6.0),
          ),
        );
      }
      for (final e in keep.take(6)) {
        game.debugInfect(0, e);
      }
      var peak = 0;
      var deepest = 0;
      run(
        game,
        60 * 12,
        keep: keep,
        each: () {
          final carriers = keep.where((e) => !e.isDead && e.isMaskInfected);
          peak = max(peak, carriers.length);
          for (final e in carriers) {
            deepest = max(deepest, e.maskInfectionGeneration);
          }
        },
      );
      expect(peak, greaterThan(6), reason: 'the infection never spread');
      expect(peak, lessThanOrEqualTo(MaskTuning.carrierCap));
      expect(peak, lessThan(crowd), reason: 'the whole crowd caught it');
      expect(deepest, lessThanOrEqualTo(MaskTuning.maxGenerations));
    });

    test(
      'one carrier passes it to at most a few neighbours a second',
      () async {
        final game = await arena('Lava', snapshot: contagion());
        final orb = game.orb.position;
        final seed = body(game, orb + const Offset(400, 0));
        final keep = {seed};
        for (var i = 0; i < 24; i++) {
          final a = i * pi * 2 / 24;
          keep.add(
            body(game, seed.position + Offset(cos(a), sin(a)) * 30.0),
          );
        }
        game.debugInfect(0, seed);
        // Nothing for the first second: a body passes it on a second after it
        // caught it.
        run(game, 50, keep: keep);
        expect(keep.where((e) => e != seed && e.isMaskInfected), isEmpty);
        // Then the seed's first spread; the ones it caught wait their own
        // second before they pass it on.
        run(game, 15, keep: keep);
        final caught = keep.where((e) => e != seed && e.isMaskInfected).length;
        expect(caught, inInclusiveRange(1, MaskTuning.spreadPerCarrier));
        for (final e in keep.where((e) => e != seed && e.isMaskInfected)) {
          expect(e.maskInfectionGeneration, 1);
        }
      },
    );
  });

  group('Mane — catapult caps', () {
    const authoredRadius = {
      'Earth': 4.9,
      'Lava': 4.6,
      'Water': 5.5,
      'Dust': 4.8,
      'Crystal': 4.6,
      'Poison': 4.4,
      'Ice': 4.4,
      'Blood': 4.4,
      'Air': 4.0,
      'Steam': 4.0,
      'Mud': 3.8,
      'Dark': 2.6,
    };
    List<Projectile> mane(String element, double stat) =>
        createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: 'mane',
          element: element,
          damage: 60,
          maxHp: 400,
          casterPower: stat,
          casterBeauty: stat,
          casterIntelligence: stat,
          casterStrength: stat,
          casterBeautyPotential: stat >= 11 ? 100 : 50,
        ).projectiles;

    test('a catapult lives at most twice its authored flight', () {
      for (final element in kCosmicAbilityElements) {
        for (final stat in [2.5, 4.25, 6.3, 11.4, 30.0]) {
          for (final p in mane(element, stat)) {
            if (p.stationary || p.holdOrbit) continue;
            // Dark's 5.5 s is the longest authored throw; at most x1.18 for
            // Intelligence and the spec's "about x2" for the crawl (it was
            // x3.1: 20 s).
            expect(kManeCatapultLifeScale, lessThanOrEqualTo(2.0));
            expect(
              p.life,
              lessThanOrEqualTo(5.5 * 1.18 * 2.0 + 1e-9),
              reason: '$element at $stat',
            );
          }
        }
      }
    });

    test('a catapult hitbox grows at most 1.6x past authored', () {
      for (final entry in authoredRadius.entries) {
        for (final stat in [2.5, 4.25, 6.3, 11.4, 30.0]) {
          final shot = mane(entry.key, stat).first;
          expect(
            shot.radiusMultiplier,
            lessThanOrEqualTo(entry.value * 1.6 + 1e-9),
            reason: '${entry.key} at $stat',
          );
          // The art keeps its share of the hitbox.
          expect(
            shot.visualScale / shot.radiusMultiplier,
            lessThan(1.0),
            reason: '${entry.key} at $stat',
          );
        }
      }
      // An average caster's shot is as wide as before (Beauty 4.25 buys
      // 1.04 coverage; the cap only bites above it).
      expect(
        mane('Water', 4.25).first.radiusMultiplier,
        closeTo(5.5 * 1.04 * 1.18 * 1.12, 0.05),
      );
    });

    test('Earth and Dark crawl slower than the other catapults', () {
      const others = [
        'Lava',
        'Water',
        'Ice',
        'Poison',
        'Plant',
        'Blood',
        'Crystal',
        'Dust',
        'Steam',
        'Mud',
        'Spirit',
      ];
      for (final stat in [2.5, 4.25, 6.3, 11.4]) {
        final earth = mane('Earth', stat).first.speedMultiplier;
        final dark = mane('Dark', stat).first.speedMultiplier;
        for (final element in others) {
          final speed = mane(element, stat).first.speedMultiplier;
          expect(earth, lessThan(speed * 0.8), reason: 'Earth vs $element');
          expect(dark, lessThan(speed * 0.85), reason: 'Dark vs $element');
        }
        expect(earth, lessThan(dark), reason: 'Earth is the slowest');
        expect(earth, greaterThan(0.12));
      }
    });
  });
}
