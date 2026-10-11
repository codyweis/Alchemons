import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic/kin_support_runtime.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ability pass's final balance (docs/ability_pass/README.md, "Final
/// results"; the edits are in docs/ability_pass/final_balance_applied/). The
/// standouts were kill-limited, so damage trims barely moved them: each change
/// here is a reach, a count or a rate. The Mystic tempo is covered in
/// ability_family_rules_test (M2) and the Mask Spirit bank in
/// mask_ability_runtime_test.
void main() {
  Projectile shot({
    String element = 'Fire',
    double effectRadius = 0,
    double radiusMultiplier = 1,
    double visualScale = 1,
    String family = 'let',
  }) => Projectile(
    position: Offset.zero,
    angle: 0,
    element: element,
    damage: 100,
    life: 2,
    speedMultiplier: 0,
    abilityFamily: family,
    effectRadius: effectRadius,
    radiusMultiplier: radiusMultiplier,
    visualScale: visualScale,
  );

  group('Let Fire', () {
    test('the kill blast reaches twice the meteor blast, with no floor', () {
      expect(CosmicAbilityRuntime.kLetFireKillReach, 2.0);
      for (final r in [60.0, 120.0, 257.0]) {
        expect(
          CosmicAbilityRuntime.letFireReach(shot(effectRadius: r)),
          closeTo(r * 2, 1e-9),
        );
      }
      // It was max(555, 3x): most of the arena at every band.
      expect(
        CosmicAbilityRuntime.letFireReach(shot(effectRadius: 120)),
        lessThan(555),
      );
    });
  });

  group('Let Dark', () {
    test('follow-ups ride the anchored count curve: 2 / 3 / 5', () {
      expect(CosmicAbilityRuntime.darkLetFollowupCount(kAbilityStatLow), 2);
      expect(CosmicAbilityRuntime.darkLetFollowupCount(1.0), 2);
      expect(
        CosmicAbilityRuntime.darkLetFollowupCount(kAbilityStatAverage),
        3,
        reason: 'an average caster read five on the old straight line',
      );
      expect(CosmicAbilityRuntime.darkLetFollowupCount(kAbilityStatPerfect), 5);
      expect(CosmicAbilityRuntime.darkLetFollowupCount(30), 5);
      var last = 0;
      for (var s = 1.0; s <= 14; s += 0.25) {
        final n = CosmicAbilityRuntime.darkLetFollowupCount(s);
        expect(n, greaterThanOrEqualTo(last), reason: 'fell at stat $s');
        last = n;
      }
    });

    test('a follow-up is 1.4x its parent, and looks it', () {
      final parent = shot(
        element: 'Dark',
        radiusMultiplier: 3.0,
        visualScale: 3.0,
      );
      expect(
        CosmicAbilityRuntime.darkLetFollowupRadius(parent),
        closeTo(4.2, 1e-9),
      );
      expect(
        CosmicAbilityRuntime.darkLetFollowupVisualScale(parent),
        closeTo(4.2, 1e-9),
      );
      // A small parent's follow-ups still land at the authored minimum.
      final small = shot(element: 'Dark', radiusMultiplier: 1.0);
      expect(CosmicAbilityRuntime.darkLetFollowupRadius(small), 3.5);
    });

    test('every mode spawns follow-ups through the shared sizes', () {
      for (final path in [
        'lib/games/cosmic_survival/cosmic_survival_game.dart',
        'lib/games/cosmic/cosmic_game_ability_pass.dart',
        'lib/games/planet_dungeon/planet_dungeon_game.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(
          src,
          contains('CosmicAbilityRuntime.darkLetFollowupRadius('),
          reason: path,
        );
        expect(
          src,
          isNot(contains('source.radiusMultiplier * 2.0')),
          reason: '$path still sizes its own follow-ups',
        );
      }
    });
  });

  group('Wing co-beams', () {
    test('a co-fired beam holds half the wing\'s own', () {
      const d = WingBeamEffect(
        element: 'Earth',
        targetPolicy: WingBeamTargetPolicy.forward,
        duration: 2.4,
        tickInterval: 0.1,
        damagePerTick: 10,
      );
      expect(WingBeamRules.coBeamLifeShare, 0.5);
      expect(WingBeamRules.coBeamLife(d), closeTo(1.2, 1e-12));
    });

    test('survival and open space both open co-beams on the shared life', () {
      for (final path in [
        'lib/games/cosmic_survival/cosmic_survival_game.dart',
        'lib/games/cosmic/cosmic_game_wing.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('WingBeamRules.coBeamLife('),
          reason: path,
        );
      }
    });
  });

  group('Mane Lightning', () {
    test('the orb count is the cast\'s lane count, held to 5-10', () {
      expect(ManeRuntime.lightningOrbCount(3), 5);
      expect(ManeRuntime.lightningOrbCount(5), 5);
      expect(ManeRuntime.lightningOrbCount(7), 7);
      expect(ManeRuntime.lightningOrbCount(10), 10);
      expect(ManeRuntime.lightningOrbCount(12), 10);
    });

    test('a cast places exactly that many orbs', () {
      for (final lanes in [5, 7, 12]) {
        final orbs = ManeRuntime.lightningOrbs(
          shot(element: 'Lightning', family: 'mane'),
          casterPos: Offset.zero,
          angle: 0,
          scatterCenter: const Offset(200, 0),
          scatterRadius: 120,
          rng: Random(3),
          clamp: (o) => o,
          count: lanes,
          slot: 0,
        );
        expect(orbs.length, ManeRuntime.lightningOrbCount(lanes));
      }
    });
  });

  group('Horn Dust and Dark', () {
    List<Projectile> horn(String element, double beauty) =>
        createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: 'horn',
          element: element,
          damage: 40,
          maxHp: 400,
          casterPower: 4,
          casterBeauty: beauty,
          casterIntelligence: 4,
          casterStrength: 4,
          targetPos: const Offset(200, 0),
        ).projectiles;

    test('a zone that taunts and drags keeps its authored reach', () {
      for (final element in ['Dust', 'Dark']) {
        final avg = horn(
          element,
          kAbilityStatAverage,
        ).where(hornZoneHoldsReach).toList();
        final top = horn(
          element,
          kAbilityStatPerfect,
        ).where(hornZoneHoldsReach).toList();
        expect(avg, isNotEmpty, reason: '$element has no taunting drag zone');
        expect(top.length, avg.length);
        for (var i = 0; i < avg.length; i++) {
          expect(
            top[i].effectRadius,
            closeTo(avg[i].effectRadius, 1e-9),
            reason: '$element: the drag grew with Beauty',
          );
        }
      }
    });

    test('the ram burst holds an average horn\'s cap for those zones', () {
      Projectile zone({required bool taunts}) => Projectile(
        position: Offset.zero,
        angle: 0,
        element: 'Dust',
        damage: 0,
        life: 4,
        speedMultiplier: 0,
        stationary: true,
        abilityFamily: 'horn',
        tickEffect: AbilityEffectKind.pull,
        effectRadius: 500,
        tauntRadius: taunts ? 140 : 0,
      );
      final reach = hornZoneReach(kAbilityStatPerfect);
      expect(reach, greaterThan(1.4));
      final burst = [zone(taunts: true), zone(taunts: false)];
      clampHornChargeBurst(burst, reach: reach);
      expect(burst[0].effectRadius, HornRules.burstEffectMax);
      expect(
        burst[1].effectRadius,
        closeTo(HornRules.burstEffectMax * reach, 1e-9),
        reason: 'a plain pull still grows with the horn',
      );
    });
  });

  group('Kin Spirit', () {
    test('the wisp survives contact and is armed with half the SPECIAL', () {
      final wisp = KinSupport.spiritWisp(Offset.zero, 0, power: 120);
      expect(wisp.piercing, isTrue, reason: 'spent on its first contact');
      expect(wisp.turretDamage, closeTo(60, 1e-9));
      expect(wisp.turretInterval, 0, reason: 'shoots only from tier 3');
    });

    test('tier 3 shoots, faster for a stronger kin; tier 2 does not', () {
      final wisp = KinSupport.spiritWisp(Offset.zero, 0, power: 50);
      KinSupport.applySpiritWispTier(wisp, 5, power: 50);
      expect(wisp.effectCount, 2);
      expect(wisp.turretInterval, 0);
      KinSupport.applySpiritWispTier(wisp, 15, power: 50);
      expect(wisp.effectCount, 3);
      expect(
        wisp.turretInterval,
        closeTo(KinSupport.spiritWispShotInterval, 1e-9),
        reason: 'the authored interval at the reference SPECIAL',
      );
      KinSupport.applySpiritWispTier(wisp, 15, power: 150);
      expect(wisp.turretInterval, lessThan(KinSupport.spiritWispShotInterval));
      expect(
        wisp.turretInterval,
        closeTo(
          KinSupport.spiritWispShotInterval *
              alchemonSpecialPowerFactor(50) /
              alchemonSpecialPowerFactor(150),
          1e-9,
        ),
      );
    });

    test('tier 4 heals the kin on its kills; lower tiers do not', () {
      final wisp = KinSupport.spiritWisp(Offset.zero, 0, power: 100);
      KinSupport.applySpiritWispTier(wisp, 15, power: 100);
      expect(KinSupport.spiritWispKillHeal(wisp, 100), 0);
      KinSupport.applySpiritWispTier(wisp, 30, power: 100);
      expect(wisp.effectCount, 4);
      expect(KinSupport.spiritWispKillHeal(wisp, 100), closeTo(12, 1e-9));
      expect(KinSupport.spiritWispKillHeal(null, 100), 0);
    });

    test('a placed turret\'s shot is credited to its caster', () {
      final turret = shot(element: 'Steam', family: 'mask')
        ..sourceSlotIndex = 2
        ..turretDamage = 30;
      final s = CosmicAbilityRuntime.companionTurretShot(
        turret,
        const Offset(100, 0),
      );
      expect(s.sourceSlotIndex, 2);
      expect(s.abilityFamily, 'mask');
      expect(s.damage, 30);
    });
  });

  // ── The standouts the measured pass still flagged ────────────────────────

  CosmicSpecialResult special(
    String family,
    String element, {
    double stat = kAbilityStatAverage,
    double damage = 100,
  }) => createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: family,
    element: element,
    damage: damage,
    maxHp: 400,
    casterPower: stat,
    casterBeauty: stat,
    casterIntelligence: stat,
    casterStrength: stat,
    targetPos: const Offset(200, 0),
  );

  group('Mane Plant', () {
    test('a rooted kill blows up 70 px, in every mode', () {
      expect(ManeRuntime.plantRootExplodeRadius, 70);
      for (final path in [
        'lib/games/cosmic_survival/cosmic_survival_game.dart',
        'lib/games/planet_dungeon/planet_dungeon_game.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(
          src,
          contains('ManeRuntime.plantRootExplodeRadius'),
          reason: path,
        );
        expect(src, isNot(contains('explodeRadius = 165.0')), reason: path);
      }
    });

    test('the vine tops out at half its old size', () {
      expect(kManePlantMaxRadius, 9.0);
      final vine = special('mane', 'Plant').projectiles.single;
      for (var i = 0; i < 20; i++) {
        ManeRuntime.growPlantVine(vine);
      }
      expect(vine.radiusMultiplier, kManePlantMaxRadius);
    });

    test('Fire and Plant recharge with the heavy throws', () {
      for (final e in ['Fire', 'Plant', 'Dark', 'Crystal']) {
        expect(elementalSpecialCooldownMultiplierSurvival('mane', e), 1.13);
      }
      expect(elementalSpecialCooldownMultiplierSurvival('mane', 'Air'), 0.77);
    });
  });

  group('Mane Dark', () {
    test('the void bolt pulls from 80 px at an average stat', () {
      final bolt = special('mane', 'Dark').projectiles.single;
      expect(bolt.snareRadius, closeTo(80, 1e-9));
      expect(bolt.effectRadius, closeTo(80, 1e-9));
    });
  });

  group('Mane Fire', () {
    test('four, five or six fireballs: inside the board\'s 3-8', () {
      expect(
        special('mane', 'Fire', stat: kAbilityStatLow).projectiles,
        hasLength(4),
      );
      expect(special('mane', 'Fire').projectiles, hasLength(5));
      expect(
        special('mane', 'Fire', stat: kAbilityStatPerfect).projectiles,
        hasLength(6),
      );
    });
  });

  group('Wing Dark and Spirit', () {
    test('Dark throws half the seekers, shorter-lived than its lances', () {
      final ps = special('wing', 'Dark').projectiles;
      final seekers = ps.where((p) => p.homing).toList();
      final lances = ps.skip(1).where((p) => !p.homing).toList();
      expect(seekers.length, inInclusiveRange(2, 3));
      expect(lances.length, greaterThan(seekers.length));
      for (final s in seekers) {
        expect(s.life, lessThan(lances.first.life));
      }
    });

    test('Spirit\'s reaping spirits fade after about two seconds', () {
      final ps = special('wing', 'Spirit').projectiles;
      final spirits = ps.where((p) => p.homing).toList();
      expect(spirits, isNotEmpty);
      for (final s in spirits) {
        expect(s.life, inInclusiveRange(2.0 * 0.86, 2.0 * 1.18));
      }
    });
  });

  group('Mask Steam and Let Steam', () {
    test('a geyser shoots for half the SPECIAL', () {
      final geysers = special('mask', 'Steam').projectiles;
      expect(geysers, isNotEmpty);
      for (final g in geysers) {
        expect(g.turretDamage, closeTo(50, 1e-9));
      }
    });

    test('Let Steam\'s kill vent lasts nine seconds', () {
      expect(CosmicAbilityRuntime.letKillZone('Steam')!.duration, 9.0);
    });
  });
}
