// Every companion the player was not driving held the same distance — 72% of
// its own attack range — whatever family it was. A kin artillery piece and a
// horn bruiser jostled on the same ring, and a wing stood still like the rest.
// Families that play completely differently in your hands looked identical
// once the AI had them.

import 'package:alchemons/games/shared/companion_stance.dart';
import 'package:flutter_test/flutter_test.dart';

const range = 300.0;

Offset _move(String family, double distance, {int orbitSign = 1}) => stanceMove(
  self: Offset.zero,
  target: Offset(distance, 0),
  attackRange: range,
  stance: stanceForFamily(family),
  orbitSign: orbitSign,
);

void main() {
  group('the ordering the families were asked for', () {
    test('horn is closest, kin is furthest', () {
      final order = familiesByStandoff;
      expect(order.first, 'horn');
      expect(order.last, 'kin');
    });

    test('mane, let and pip all stand back further than a horn', () {
      final horn = stanceForFamily('horn').engageFraction;
      for (final f in ['mane', 'let', 'pip']) {
        expect(
          stanceForFamily(f).engageFraction,
          greaterThan(horn + 0.3),
          reason: '$f should keep real distance',
        );
      }
    });

    test('kin sits behind every other family', () {
      final kin = stanceForFamily('kin').engageFraction;
      for (final f in kCompanionStances.keys) {
        if (f == 'kin') continue;
        expect(kin, greaterThan(stanceForFamily(f).engageFraction));
      }
    });

    test('wing circles far harder than anyone else', () {
      final wing = stanceForFamily('wing').orbitWeight;
      for (final f in kCompanionStances.keys) {
        if (f == 'wing') continue;
        expect(wing, greaterThan(stanceForFamily(f).orbitWeight * 2));
      }
    });

    test('an unknown family gets the middle, not zero', () {
      final s = stanceForFamily('nonsense');
      expect(s.engageFraction, kDefaultCompanionStance.engageFraction);
      expect(stanceForFamily(null).engageFraction, greaterThan(0));
    });

    test('family lookup is case-insensitive', () {
      expect(
        stanceForFamily('KIN').engageFraction,
        stanceForFamily('kin').engageFraction,
      );
    });
  });

  group('moving into stance', () {
    test('too far away, everyone closes', () {
      for (final f in kCompanionStances.keys) {
        expect(_move(f, range * 1.5).dx, greaterThan(0), reason: f);
      }
    });

    test('at the horn\'s comfortable distance the kin is already retreating', () {
      // 102px is exactly where a horn wants to be, and far too close for a
      // kin, whose ring is nearly the full 300.
      final d = range * stanceForFamily('horn').engageFraction;
      expect(_move('horn', d).dx, closeTo(0, 1e-9), reason: 'horn is settled');
      expect(_move('kin', d).dx, lessThan(0), reason: 'kin backs off');
    });

    test('a ranged family shoved into melee backs out', () {
      final kin = _move('kin', 20);
      expect(kin.dx, lessThan(0), reason: 'kin must retreat, not stand');
    });

    test('a horn tolerates being close instead of retreating', () {
      // Same distance that sends a kin backwards.
      expect(_move('horn', range * 0.2).dx, greaterThanOrEqualTo(-0.9));
    });

    test('the move never exceeds full speed', () {
      for (final f in kCompanionStances.keys) {
        for (final d in [20.0, 150.0, 300.0, 900.0]) {
          expect(_move(f, d).distance, lessThanOrEqualTo(1.0 + 1e-9),
              reason: '$f at $d');
        }
      }
    });

    test('magnitude carries intent — a settled horn barely moves', () {
      // Normalising here would send it sliding sideways at full speed.
      final settled = _move('horn', range * stanceForFamily('horn').engageFraction);
      expect(settled.distance, lessThan(0.2));
      final far = _move('horn', range * 2);
      expect(far.distance, greaterThan(0.8));
    });
  });

  group('orbiting', () {
    test('a settled wing moves sideways, not just in and out', () {
      final m = _move('wing', range * stanceForFamily('wing').engageFraction);
      expect(m.dy.abs(), greaterThan(0.5), reason: 'it should be circling');
      expect(m.dx.abs(), lessThan(0.1), reason: 'and not closing while it does');
    });

    test('orbit direction follows the sign, so two wings do not collide', () {
      final a = _move('wing', range * 0.66, orbitSign: 1);
      final b = _move('wing', range * 0.66, orbitSign: -1);
      expect(a.dy.sign, isNot(b.dy.sign));
    });

    test('a horn barely circles at all', () {
      final m = _move('horn', range * 0.34);
      expect(m.dy.abs(), lessThan(0.2));
    });
  });

  group('degenerate input', () {
    test('standing on the target does not produce a direction', () {
      expect(_move('wing', 0), Offset.zero);
    });

    test('zero attack range never divides by zero', () {
      final m = stanceMove(
        self: Offset.zero,
        target: const Offset(100, 0),
        attackRange: 0,
        stance: stanceForFamily('kin'),
        orbitSign: 1,
      );
      expect(m, Offset.zero);
    });

    test('the engage distance is never outside the attack range', () {
      for (final f in kCompanionStances.keys) {
        expect(
          clampedEngageDistance(range, stanceForFamily(f)),
          lessThanOrEqualTo(range),
          reason: f,
        );
      }
    });
  });
}
