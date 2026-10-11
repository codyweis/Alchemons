import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic/kin_support_runtime.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 2 of the ability pass (docs/ability_pass/README.md): the stat hooks
/// that kept clamping (M5), the reaches that never scaled, and the ceiling on
/// reaches past perfect. An average creature must play exactly as before;
/// only the top end grows.
void main() {
  // The scaling report's bands (docs/ability_pass/README.md).
  const p50 = 4.3;
  const p70 = 5.27;
  const p100e10 = 11.05;

  group('ability hooks (M5)', () {
    const params = <({double perPoint, double min, double max})>[
      (perPoint: 0.12, min: 0.82, max: 1.22),
      (perPoint: 0.10, min: 0.85, max: 1.40),
      (perPoint: 0.10, min: 0.85, max: 1.50),
      (perPoint: 0.18, min: 0.90, max: 2.0),
      (perPoint: 0.40, min: 0.85, max: 6.0),
      (perPoint: 0.20, min: 0.80, max: 1.80),
    ];

    test('match the legacy curve at and below an average stat', () {
      for (final p in params) {
        for (final stat in [
          0.5,
          1.0,
          2.5,
          3.0,
          3.7,
          4.0,
          kAbilityStatAverage,
        ]) {
          expect(
            abilityHookScale(
              stat,
              perPoint: p.perPoint,
              min: p.min,
              max: p.max,
            ),
            hornStatScale(stat, perPoint: p.perPoint, min: p.min, max: p.max),
            reason: '$p at $stat',
          );
        }
      }
    });

    test('keep growing past average: about x1.5-2 from P50 to P100E10', () {
      for (final p in params) {
        double v(double s) =>
            abilityHookScale(s, perPoint: p.perPoint, min: p.min, max: p.max);
        final growth = v(p100e10) / v(p50);
        expect(growth, inInclusiveRange(1.5, 2.0), reason: '$p');
        // Never below the old curve, and never shrinking as the stat grows.
        var last = v(kAbilityStatAverage);
        for (var s = kAbilityStatAverage; s <= 30; s += 0.25) {
          final now = v(s);
          expect(
            now,
            greaterThanOrEqualTo(
              hornStatScale(s, perPoint: p.perPoint, min: p.min, max: p.max),
            ),
          );
          expect(now, greaterThanOrEqualTo(last - 1e-9));
          last = now;
        }
        // The P70 band gives up nothing it had.
        expect(
          v(p70),
          greaterThanOrEqualTo(
            hornStatScale(p70, perPoint: p.perPoint, min: p.min, max: p.max),
          ),
        );
      }
    });

    test('a shrinking hook (a charge time) keeps shrinking', () {
      double v(double s) =>
          abilityHookScale(s, perPoint: -0.06, min: 0.70, max: 1.15);
      expect(
        v(kAbilityStatAverage),
        hornStatScale(4.25, perPoint: -0.06, min: 0.70, max: 1.15),
      );
      expect(v(p100e10), lessThan(v(p50) / 1.5));
      expect(v(30), lessThan(v(p100e10)));
    });

    test('Horn Mud drops sludge as before up to average, denser past it', () {
      double legacy(double s) =>
          1.45 + (0.58 - 1.45) * ((s - 3.0) / 2.0).clamp(0.0, 1.0);
      for (final s in [1.0, 3.0, 3.5, 4.0, kAbilityStatAverage]) {
        expect(hornMudInterval(s), closeTo(legacy(s), 1e-12));
      }
      // Never sparser than before; the old curve stopped at 5.
      for (final s in [p70, 7.14, p100e10]) {
        expect(hornMudInterval(s), lessThanOrEqualTo(legacy(s)));
      }
      expect(hornMudInterval(p100e10), lessThan(hornMudInterval(7.14)));
    });

    test('Kin timed supports read the same at average, longer at the top', () {
      expect(
        KinSupport.lavaPlateDuration(kAbilityStatAverage),
        9.0 * hornStatScale(4.25, perPoint: 0.10, min: 0.85, max: 1.40),
      );
      expect(
        KinSupport.lavaPlateDuration(p100e10) /
            KinSupport.lavaPlateDuration(p50),
        inInclusiveRange(1.5, 2.0),
      );
      expect(
        KinSupport.iceChargeDuration(p100e10),
        lessThan(KinSupport.iceChargeDuration(p50)),
      );
    });

    test(
      'the Kin Earth wall is ten stones over 120 degrees at average, longer above',
      () {
        double span(List<Projectile> wall) {
          final a = wall.first.position.direction;
          final b = wall.last.position.direction;
          return (b - a).abs();
        }

        final avg = KinSupport.earthWallArc(
          center: Offset.zero,
          facing: 0,
          beauty: kAbilityStatAverage,
        );
        expect(avg.length, 10);
        expect(span(avg), closeTo(2.094, 1e-6));
        final top = KinSupport.earthWallArc(
          center: Offset.zero,
          facing: 0,
          beauty: p100e10,
        );
        expect(top.length, greaterThan(avg.length * 1.5));
        expect(span(top), greaterThan(span(avg) * 1.5));
        expect(span(top), lessThanOrEqualTo(4.19 + 1e-6));
      },
    );

    test('a Kin cast heals the same at average and more at the top', () {
      int selfHeal(double stat) => createCosmicSpecialAbility(
        origin: Offset.zero,
        baseAngle: 0,
        family: 'Kin',
        element: 'Light',
        damage: 40,
        maxHp: 1000,
        casterPower: stat,
        casterBeauty: stat,
        casterIntelligence: stat,
        casterStrength: stat,
      ).selfHeal;
      // healScale on the legacy baseline-4 curve at 4.25: 1 + 0.25 * 0.11.
      expect(selfHeal(kAbilityStatAverage), (1000 * 0.50 * 1.0275).round());
      expect(selfHeal(p100e10) / selfHeal(p50), inInclusiveRange(1.5, 2.0));
    });
  });

  group('reaches', () {
    test('new reaches are unchanged at and below average', () {
      for (final s in [0.5, 2.5, 3.0, 4.0, kAbilityStatAverage]) {
        expect(hornZoneReach(s), 1.0);
        expect(letZoneReach(s), 1.0);
      }
      expect(hornZoneReach(p100e10), greaterThan(1.4));
      expect(letZoneReach(p100e10), greaterThan(1.3));
    });

    test(
      'a reach never passes 1.6x its decent-band size, even past perfect',
      () {
        double ceiling(double atLow, double atPerfect) =>
            kAbilityReachCeiling *
            scaledAbilityValue(
              kAbilityStatDecent,
              atLow: atLow,
              atAverage: 1.0,
              atPerfect: atPerfect,
            );
        for (final s in [p100e10, 12.0, 15.0, 30.0, 60.0]) {
          expect(
            scaledAbilityReach(s, atLow: 0.74, atAverage: 1.0, atPerfect: 1.65),
            lessThanOrEqualTo(ceiling(0.74, 1.65) + 1e-12),
          );
          expect(
            hornZoneReach(s),
            lessThanOrEqualTo(ceiling(1.0, 1.65) + 1e-12),
          );
        }
        // Below the ceiling it is the anchored curve itself.
        expect(
          scaledAbilityReach(7.0, atLow: 0.74, atAverage: 1.0, atPerfect: 1.65),
          scaledAbilityValue(7.0, atLow: 0.74, atAverage: 1.0, atPerfect: 1.65),
        );
      },
    );

    test('a Let zone grows with the caster past average only', () {
      final spec = CosmicAbilityRuntime.letContactZone('Lava')!;
      Projectile meteor(double intelligence) => Projectile(
        position: Offset.zero,
        angle: 0,
        element: 'Lava',
        damage: 100,
        life: 1,
        speedMultiplier: 0,
        abilityFamily: 'let',
        letCasterIntelligence: intelligence,
      );
      final avg = CosmicAbilityRuntime.letZone(
        meteor(kAbilityStatAverage),
        Offset.zero,
        'Lava',
        spec,
      );
      expect(avg.effectRadius, spec.radius);
      expect(avg.radiusMultiplier, spec.radius / 7.0);
      final top = CosmicAbilityRuntime.letZone(
        meteor(p100e10),
        Offset.zero,
        'Lava',
        spec,
      );
      expect(top.effectRadius / spec.radius, letZoneReach(p100e10));
    });

    test('a ram burst cap grows with the horn; the taunt cap stays put', () {
      Projectile zone() => Projectile(
        position: Offset.zero,
        angle: 0,
        element: 'Water',
        damage: 0,
        life: 4,
        speedMultiplier: 0,
        stationary: true,
        abilityFamily: 'horn',
        effectRadius: 500,
        snareRadius: 500,
        tauntRadius: 500,
      );
      final avg = [zone()];
      clampHornChargeBurst(avg);
      expect(avg.first.effectRadius, HornRules.burstEffectMax);
      expect(avg.first.snareRadius, HornRules.burstSnareMax);
      final reach = hornZoneReach(p100e10);
      final top = [zone()];
      clampHornChargeBurst(top, reach: reach);
      expect(
        top.first.effectRadius,
        closeTo(HornRules.burstEffectMax * reach, 1e-9),
      );
      expect(
        top.first.tauntRadius,
        HornRules.burstTauntMax, // a wider taunt hauls the wave onto the orb
      );
    });

    test('Mane Light rings are the ladder at average and wider above it', () {
      Projectile template(double reach) => Projectile(
        position: Offset.zero,
        angle: 0,
        element: 'Light',
        damage: 10,
        life: 26,
        speedMultiplier: 0,
        abilityFamily: 'mane',
        effectRadius: kManeLightWardEffectRadius * reach,
      );
      final avg = ManeLightWard.cast(
        rings: const [],
        ringCap: 3,
        growth: 0,
        casterPos: Offset.zero,
        casterAngle: 0,
        template: template(1.0),
      ).hung!;
      expect(avg.radiusMultiplier, kManeLightRadiusByLevel.first);
      expect(avg.visualScale, kManeLightVisualByLevel.first);

      final wide = ManeLightWard.cast(
        rings: const [],
        ringCap: 3,
        growth: 0,
        casterPos: Offset.zero,
        casterAngle: 0,
        template: template(1.2),
      ).hung!;
      expect(
        wide.radiusMultiplier,
        closeTo(kManeLightRadiusByLevel.first * 1.2, 1e-9),
      );
      // Feeding climbs the ladder and keeps the ring's reach.
      final fed = ManeLightWard.cast(
        rings: [wide],
        ringCap: 1,
        growth: 0,
        casterPos: Offset.zero,
        casterAngle: 0,
        template: template(1.2),
      ).fed!;
      expect(
        fed.radiusMultiplier,
        closeTo(kManeLightRadiusByLevel[1] * 1.2, 1e-9),
      );
      expect(max(0, fed.effectStacks), 1);
    });
  });

  group('persistent pieces (M7)', () {
    Projectile piece({
      int slot = 0,
      String family = 'horn',
      String element = 'Fire',
      double life = 30,
      bool stationary = true,
      double speed = 0,
    }) => Projectile(
      position: Offset.zero,
      angle: 0,
      element: element,
      damage: 0,
      life: life,
      speedMultiplier: speed,
      stationary: stationary,
      sourceSlotIndex: slot,
      abilityFamily: family,
    );

    void cast(
      List<Projectile> field, {
      int slot = 0,
      String family = 'Horn',
      String element = 'Fire',
    }) {
      CasterPieces.onCast(field, slot: slot, family: family, element: element);
      field.removeWhere((p) => p.life <= CasterPieces.retireFade);
    }

    test(
      'a caster holds the pieces of its last two casts, however fast it casts',
      () {
        final field = <Projectile>[];
        for (var n = 1; n <= 12; n++) {
          cast(field);
          field.addAll([for (var i = 0; i < 10; i++) piece()]); // one wall
          expect(
            field.length,
            lessThanOrEqualTo(10 * CasterPieces.castWindow),
            reason: 'after cast $n',
          );
        }
        expect(field.length, 10 * CasterPieces.castWindow);
      },
    );

    test('a recast fades the oldest pieces rather than popping them', () {
      final old = piece();
      final field = [old];
      for (var i = 1; i < CasterPieces.castWindow; i++) {
        CasterPieces.onCast(field, slot: 0, family: 'Horn', element: 'Fire');
        expect(old.life, 30); // still within its caster's window
      }
      CasterPieces.onCast(field, slot: 0, family: 'Horn', element: 'Fire');
      expect(old.life, CasterPieces.retireFade);
    });

    test(
      'other casters, other abilities and shots in flight are left alone',
      () {
        final mine = piece();
        final theirs = piece(slot: 1);
        final otherFamily = piece(family: 'wing');
        final inFlight = piece(stationary: false, speed: 1);
        final field = [mine, theirs, otherFamily, inFlight];
        for (var i = 0; i < CasterPieces.castWindow; i++) {
          CasterPieces.onCast(field, slot: 0, family: 'Horn', element: 'Fire');
        }
        expect(mine.life, CasterPieces.retireFade);
        expect(theirs.life, 30);
        expect(otherFamily.life, 30);
        expect(inFlight.life, 30);
      },
    );

    test(
      'a caster too slow to reach its pieces\' life never meets the rule',
      () {
        // A piece that lives 1.5 recasts dies of age before its window ends,
        // so the rule never cuts one short.
        final field = <Projectile>[];
        for (var n = 0; n < 8; n++) {
          CasterPieces.onCast(field, slot: 0, family: 'Horn', element: 'Fire');
          field.add(piece(life: 12)); // what this cast lays
          for (final p in field) {
            expect(p.life, greaterThan(CasterPieces.retireFade));
            p.life -= 8; // one recast interval passes
          }
          field.removeWhere((p) => p.life <= 0);
        }
        expect(field.length, 1);
      },
    );

    test('fixtures a recast feeds or refreshes are never retired', () {
      final ring = piece(family: 'mane', element: 'Light', stationary: false)
        ..holdOrbit = true;
      final vine = piece(family: 'mask', element: 'Plant');
      final shield = piece(family: 'mask', element: 'Dust')
        ..attachedToSlot = -1;
      final wisp = piece(family: 'kin', element: 'Spirit', stationary: false)
        ..followSourceCompanion = true;
      for (var i = 0; i < 5; i++) {
        CasterPieces.onCast([ring], slot: 0, family: 'Mane', element: 'Light');
        CasterPieces.onCast(
          [vine, shield],
          slot: 0,
          family: 'Mask',
          element: 'Plant',
        );
        CasterPieces.onCast([shield], slot: 0, family: 'Mask', element: 'Dust');
        CasterPieces.onCast([wisp], slot: 0, family: 'Kin', element: 'Spirit');
      }
      for (final p in [ring, vine, shield, wisp]) {
        expect(p.life, 30, reason: '${p.abilityFamily} ${p.element}');
      }
    });

    test(
      'Kin Dust keeps its own pile-up; Pip Poison lasts until the next cast',
      () {
        final cloud = piece(family: 'kin', element: 'Dust');
        for (var i = 0; i < 6; i++) {
          CasterPieces.onCast([cloud], slot: 0, family: 'Kin', element: 'Dust');
        }
        expect(cloud.life, 30);
        final line = piece(family: 'pip', element: 'Poison');
        CasterPieces.onCast([line], slot: 0, family: 'Pip', element: 'Poison');
        expect(line.life, CasterPieces.retireFade);
      },
    );

    test(
      'Mask traps are covered, so a faster Mask cannot pile its field up',
      () {
        final field = <Projectile>[];
        for (var n = 0; n < 8; n++) {
          cast(field, family: 'Mask', element: 'Air');
          field.addAll([
            for (var i = 0; i < 12; i++) piece(family: 'mask', element: 'Air'),
          ]);
        }
        expect(field.length, 12 * CasterPieces.castWindow);
      },
    );

    test('the Kin supports keep three casts, as an average Kin spans', () {
      expect(
        CasterPieces.windowFor('kin', 'Water'),
        CasterPieces.kinCastWindow,
      );
      final field = <Projectile>[];
      for (var n = 0; n < 8; n++) {
        cast(field, family: 'Kin', element: 'Water');
        field.add(piece(family: 'kin', element: 'Water'));
      }
      expect(field.length, CasterPieces.kinCastWindow);
    });
  });
}
