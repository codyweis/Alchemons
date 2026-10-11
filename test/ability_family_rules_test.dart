import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3 of the ability pass (docs/ability_pass/README.md, 2026-10-10): the
/// family rules that set most of a special's curve.
///
///  - M1: a Mask's traps come back on SPECIAL like every other family's, from
///    a halved element table — and a Mask still recasts slower than anyone.
///  - A Mask contact trap's trigger is a readable size, not 3-11 px.
///  - M2: a Mystic world is lit once, so its SPECIAL buys intensity, and
///    (final balance) tempo: a damage world beats faster for a stronger caster.
///  - M6: the three world hooks that were already maxed at stat 3 span the
///    real stat band.

/// The roster-median species the scaling report measures with.
CosmicPartyMember _bandMember(
  String family,
  String element,
  int potential,
  int enhancement,
) {
  double stat(int base) => AlchemonStatSystem.effectiveInternal(
    speciesBase: base,
    level: 10,
    potential: potential,
    enhancementRank: enhancement,
  );
  return CosmicPartyMember(
    instanceId: 'rules-$family-$element',
    baseId: 'RULES01',
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: stat(63),
    statIntelligence: stat(68),
    statStrength: stat(64),
    statBeauty: stat(69),
    statSpeedPotential: potential.toDouble(),
    statIntelligencePotential: potential.toDouble(),
    statStrengthPotential: potential.toDouble(),
    statBeautyPotential: potential.toDouble(),
    staminaBars: 3,
    staminaMax: 3,
  );
}

const _bands = {
  'P50': (potential: 50, enhancement: 0),
  'P70': (potential: 70, enhancement: 0),
  'P90': (potential: 90, enhancement: 0),
  'P100E10': (potential: 100, enhancement: 10),
};

double _interval(String family, String element, String band) {
  final b = _bands[band]!;
  final c = deriveAlchemonCombatStats(
    member: _bandMember(family, element, b.potential, b.enhancement),
  );
  return alchemonSpecialInterval(
    family: family,
    element: element,
    specialCooldownReduction: c.specialCooldownReduction,
    abilityAtk: c.abilityAtk,
  );
}

/// The rule a Mask ran on before 2026-10-10: its own base, recharge stats
/// only, and an element table twice today's.
double _oldMaskInterval(String element, String band) {
  final b = _bands[band]!;
  final c = deriveAlchemonCombatStats(
    member: _bandMember('mask', element, b.potential, b.enhancement),
  );
  return kMaskBaseSpecialCooldown /
      c.specialCooldownReduction *
      elementalSpecialCooldownMultiplierSurvival('mask', element) *
      2;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M1: Mask cadence', () {
    test('the element table is halved, and the reference SPECIAL is P50', () {
      expect(elementalSpecialCooldownMultiplierSurvival('mask', 'Air'), 0.70);
      expect(elementalSpecialCooldownMultiplierSurvival('mask', 'Light'), 1.80);
      final p50 = deriveAlchemonCombatStats(
        member: _bandMember('mask', 'Fire', 50, 0),
      );
      expect(
        p50.abilityAtk,
        closeTo(kMaskReferenceSpecial, 2),
        reason: 'kMaskReferenceSpecial is a Mask\'s SPECIAL at the P50 band',
      );
      // At the reference the power factor cancels: base x table / recharge.
      expect(
        alchemonSpecialInterval(
          family: 'mask',
          element: 'Fire',
          specialCooldownReduction: 1.2,
          abilityAtk: kMaskReferenceSpecial,
        ),
        closeTo(kMaskBaseSpecialCooldown / 1.2 * 0.825, 1e-9),
      );
    });

    test('about x2 the casts at P50 and about x4 at P100E10', () {
      for (final element in kCosmicAbilityElements) {
        final p50 =
            _oldMaskInterval(element, 'P50') /
            _interval('mask', element, 'P50');
        final top =
            _oldMaskInterval(element, 'P100E10') /
            _interval('mask', element, 'P100E10');
        expect(p50, inInclusiveRange(1.8, 2.2), reason: '$element at P50');
        expect(top, inInclusiveRange(3.5, 4.5), reason: '$element at P100E10');
        // And it now gains like the other families do, about x3 across the
        // bands (it was x1.4 on recharge stats alone).
        expect(
          _interval('mask', element, 'P50') /
              _interval('mask', element, 'P100E10'),
          greaterThan(2.5),
          reason: '$element cadence gain',
        );
      }
    });

    test('a Mask still recasts slower than every other family', () {
      const recasting = ['horn', 'wing', 'let', 'pip', 'mane', 'kin'];
      for (final band in _bands.keys) {
        final fastestMask = kCosmicAbilityElements
            .map((e) => _interval('mask', e, band))
            .reduce(min);
        for (final family in recasting) {
          final slowest = kCosmicAbilityElements
              .map((e) => _interval(family, e, band))
              .reduce(max);
          expect(
            fastestMask,
            greaterThan(slowest),
            reason:
                '$band: the fastest Mask (${fastestMask.toStringAsFixed(1)}s) '
                'is quicker than the slowest $family '
                '(${slowest.toStringAsFixed(1)}s) — placement is the rare action',
          );
        }
      }
    });
  });

  group('Mask contact traps', () {
    List<Projectile> cast(String element, double beauty) =>
        createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: 'Mask',
          element: element,
          damage: 40,
          maxHp: 500,
          casterBeauty: beauty,
          casterIntelligence: beauty,
          casterStrength: beauty,
          targetPos: const Offset(120, 0),
        ).projectiles;
    double trigger(Projectile p) => Projectile.radius * p.radiusMultiplier;

    for (final element in kMaskContactTrapElements) {
      test('$element springs on a readable trigger that grows with Beauty', () {
        final average = cast(element, kAbilityStatAverage);
        final perfect = cast(element, kAbilityStatPerfect);
        final past = cast(element, 30);
        expect(average, isNotEmpty);
        for (final p in average) {
          expect(p.tickEffect, AbilityEffectKind.none);
          expect(
            trigger(p),
            inInclusiveRange(24.0, 41.0),
            reason: '$element trigger at an average stat',
          );
        }
        final a = trigger(average.first);
        final top = trigger(perfect.first);
        expect(top / a, closeTo(1.52, 0.01), reason: '$element at perfect');
        expect(
          trigger(past.first) / a,
          lessThanOrEqualTo(kAbilityReachCeiling * 1.03 + 1e-9),
          reason: '$element past perfect is held to the reach ceiling',
        );
      });
    }

    test('an area trap keeps its authored contact radius', () {
      final pools = cast('Lava', kAbilityStatAverage);
      for (final p in pools) {
        expect(p.radiusMultiplier, closeTo(1.9, 1e-9));
      }
    });
  });

  group('M2: Mystic world intensity', () {
    test('a damage world lands harder with SPECIAL', () {
      // About P50, P90 and P100 + Enhancement 10 for a Mystic.
      final p50 = mysticWorldIntensity(element: 'Air', abilityAtk: 81);
      final p90 = mysticWorldIntensity(element: 'Air', abilityAtk: 153);
      final top = mysticWorldIntensity(element: 'Air', abilityAtk: 240);
      expect(p50, closeTo(0.65, 0.02));
      expect(p90, greaterThan(p50));
      expect(top / p50, closeTo(2.43, 0.05));
      expect(
        mysticWorldIntensity(element: 'Air', abilityAtk: 5000),
        2.5,
        reason: 'a run cannot drive a world past 2.5x',
      );
      // The Grove and the Quaking land lower at every SPECIAL.
      for (final e in ['Plant', 'Earth']) {
        expect(
          mysticWorldIntensity(element: e, abilityAtk: 81),
          closeTo(p50 * 0.65, 1e-9),
        );
      }
      // Control and support worlds are not scaled here.
      for (final e in ['Water', 'Dark', 'Steam', 'Ice', 'Mud', 'Dust']) {
        expect(mysticWorldIntensity(element: e, abilityAtk: 240), 1.0);
      }
    });

    test('a damage world works faster with SPECIAL, 1 at P50', () {
      // The final balance pass (2026-10-10): what the median special gains
      // from recasts, a world gains in tempo instead.
      final p50 = mysticWorldTempo(element: 'Lightning', abilityAtk: 81);
      final p90 = mysticWorldTempo(element: 'Lightning', abilityAtk: 153);
      final top = mysticWorldTempo(element: 'Lightning', abilityAtk: 240);
      expect(p50, closeTo(1.0, 1e-9));
      expect(p90, closeTo(1.65, 0.01));
      expect(top, closeTo(2.43, 0.01));
      expect(
        mysticWorldTempo(element: 'Lightning', abilityAtk: 5000),
        3.0,
        reason: 'a run cannot drive a beat into a continuous beam',
      );
      expect(mysticWorldTempo(element: 'Lightning', abilityAtk: 0), 0.6);
      for (final e in kMysticDamageWorlds) {
        expect(mysticWorldTempo(element: e, abilityAtk: 240), top);
      }
      for (final e in ['Water', 'Dark', 'Steam', 'Ice', 'Mud', 'Dust']) {
        expect(mysticWorldTempo(element: e, abilityAtk: 240), 1.0);
      }
    });

    Future<CosmicSurvivalGame> litAt(String element, String band) async {
      final b = _bands[band]!;
      final game = CosmicSurvivalGame(
        party: [_bandMember('Mystic', element, b.potential, b.enhancement)],
        random: Random(5),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      void keepAlive() {
        game.orb.currentHp = game.orb.maxHp;
        game.ship.currentHp = game.ship.maxHp;
        if (game.showingPowerUpSelection) {
          game.alchemicalMeter = 0;
          game.dismissPowerUpSelection();
        }
      }

      for (
        var i = 0;
        i < 1200 && game.enemies.where((e) => !e.isDead).isEmpty;
        i++
      ) {
        keepAlive();
        game.update(1 / 60);
      }
      final comp = game.activeCompanions[0]!;
      final target = game.enemies.firstWhere((e) => !e.isDead);
      comp.specialCooldown = 0;
      for (var f = 0; f < 1200 && !game.isMysticFieldSpent(0); f++) {
        target
          ..isDead = false
          ..hp = 1e9
          ..position = comp.position + const Offset(70, 0);
        keepAlive();
        game.update(1 / 60);
      }
      expect(game.isMysticFieldSpent(0), isTrue, reason: 'never cast');
      return game;
    }

    test('a fully surged storm never quickens past the cap', () async {
      final game = await litAt('Lightning', 'P100E10');
      final surge = kAllPowerUps.firstWhere((d) => d.id == 'world_lightning');
      for (var i = 0; i < 3; i++) {
        game.applyPowerUp(surge, targetSlot: 0);
      }
      expect(
        game.mysticWorldBeat(0)!,
        greaterThanOrEqualTo(
          CosmicSurvivalGame.kMysticStrikeInterval /
                  CosmicSurvivalGame.kMysticBeatQuickeningCap -
              1e-9,
        ),
      );
    });

    test('a stronger Mystic\'s storm and quake beat faster', () async {
      for (final (element, authored) in [
        ('Lightning', CosmicSurvivalGame.kMysticStrikeInterval),
        ('Earth', CosmicSurvivalGame.kMysticQuakeInterval),
      ]) {
        final beats = <double>[];
        for (final band in ['P50', 'P100E10']) {
          final game = await litAt(element, band);
          final atk = game.activeCompanions[0]!.abilityAtk;
          final beat = game.mysticWorldBeat(0)!;
          expect(
            beat,
            closeTo(
              authored / mysticWorldTempo(element: element, abilityAtk: atk),
              1e-9,
            ),
            reason:
                '$element at $band: the beat is not the authored one '
                'quickened by tempo',
          );
          beats.add(beat);
        }
        expect(
          beats[0] / beats[1],
          inInclusiveRange(2.0, 2.8),
          reason: '$element: P100E10 should beat about 2.4x as often as P50',
        );
      }
    });

    test('a world with no clock reports no beat', () async {
      final game = await litAt('Air', 'P50');
      expect(game.mysticWorldBeat(0), isNull);
    });

    test('a stronger Mystic\'s miasma trails a longer wake', () async {
      // The Poison world's patches spread wider, linger longer and run a
      // longer wake with tempo (final balance): at P50 the wake holds the
      // authored 26 patches, at P100E10 about 2.4x that.
      final counts = <int>[];
      for (final band in ['P50', 'P100E10']) {
        final game = await litAt('Poison', band);
        final centre = game.orb.position;
        for (var f = 0; f < 60 * 14; f++) {
          final a = f / 60 * 1.6;
          game.ship.position = centre + Offset(cos(a), sin(a)) * 260;
          game.orb.currentHp = game.orb.maxHp;
          game.ship.currentHp = game.ship.maxHp;
          if (game.showingPowerUpSelection) {
            game.alchemicalMeter = 0;
            game.dismissPowerUpSelection();
          }
          game.update(1 / 60);
        }
        counts.add(game.mysticPoolCount(0));
      }
      expect(counts[0], lessThanOrEqualTo(26));
      expect(counts[1], greaterThan(40), reason: 'the wake did not grow');
    });
  });

  group('M6: the world hooks span the real stat band', () {
    test(
      'the progress curve grows from stat 3 to 12 instead of starting full',
      () {
        expect(mysticWorldHookProgress(3), lessThan(0.1));
        expect(
          mysticWorldHookProgress(kAbilityStatAverage),
          closeTo(0.25, 1e-9),
        );
        expect(mysticWorldHookProgress(kAbilityStatPerfect), 1.0);
        expect(mysticWorldHookProgress(30), 1.0);
        var last = -1.0;
        for (var s = 3.0; s <= 12.0; s += 0.5) {
          final v = mysticWorldHookProgress(s);
          expect(v, greaterThan(last), reason: 'flat at stat $s');
          last = v;
        }
      },
    );

    CosmicPartyMember mystic(String element, double stat) => CosmicPartyMember(
      instanceId: 'm6-$element',
      baseId: 'M6W01',
      displayName: '$element Mystic',
      family: 'Mystic',
      element: element,
      level: 10,
      slotIndex: 0,
      statSpeed: stat,
      statIntelligence: stat,
      statStrength: stat,
      statBeauty: stat,
      statSpeedPotential: 80,
      statIntelligencePotential: 80,
      statStrengthPotential: 80,
      statBeautyPotential: 80,
      staminaBars: 3,
      staminaMax: 3,
    );

    void keepAlive(CosmicSurvivalGame game) {
      game.orb.currentHp = game.orb.maxHp;
      game.ship.currentHp = game.ship.maxHp;
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
    }

    Future<CosmicSurvivalGame> lit(String element, double stat) async {
      final game = CosmicSurvivalGame(
        party: [mystic(element, stat)],
        random: Random(5),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      game.startGame();
      game.summonCompanion(0);
      for (
        var i = 0;
        i < 1200 && game.enemies.where((e) => !e.isDead).isEmpty;
        i++
      ) {
        keepAlive(game);
        game.update(1 / 60);
      }
      final comp = game.activeCompanions[0]!;
      final target = game.enemies.firstWhere((e) => !e.isDead);
      comp.specialCooldown = 0;
      for (var f = 0; f < 1200 && !game.isMysticFieldSpent(0); f++) {
        target
          ..isDead = false
          ..hp = 1e9
          ..position = comp.position + const Offset(70, 0);
        keepAlive(game);
        game.update(1 / 60);
      }
      expect(game.isMysticFieldSpent(0), isTrue, reason: 'never cast');
      for (var f = 0; f < 30; f++) {
        keepAlive(game);
        game.update(1 / 60);
      }
      return game;
    }

    test('the blizzard deepens from an average stat to perfect', () async {
      final slows = <double>[];
      for (final stat in [3.0, kAbilityStatAverage, 7.0, kAbilityStatPerfect]) {
        final game = await lit('Ice', stat);
        final chilled = game.enemies.firstWhere((e) => !e.isDead);
        slows.add(chilled.blizzardMultiplier);
      }
      // 0.70 - 0.25 x progress: about 36% slower at an average stat (it was
      // the full 55% for every fielded creature), 55% at perfect.
      expect(slows[1], closeTo(0.70 - 0.25 * 0.25, 1e-6));
      expect(slows[3], closeTo(0.45, 1e-6));
      for (var i = 1; i < slows.length; i++) {
        expect(slows[i], lessThan(slows[i - 1]), reason: 'flat at step $i');
      }
    });

    test('the Lava world cracks more of the floor as it grows', () async {
      final counts = <int>[];
      for (final stat in [3.0, kAbilityStatAverage, kAbilityStatPerfect]) {
        final game = await lit('Lava', stat);
        counts.add(game.mysticFissureCount(0));
      }
      expect(counts, [5, 6, 9]);
    });
  });
}
