// Every companion the player was not driving held the same distance — 72% of
// its own attack range — whatever family it was. A kin artillery piece and a
// horn bruiser jostled on the same ring, and a wing stood still like the rest.
// Families that play completely differently in your hands looked identical
// once the AI had them.
//
// Then (2026-10-07) "closer / further from the centre" read as robotic: a horn
// sat inside a guardian's body, and they crept and jittered. A companion now
// takes a STATION: off the target's edge, on the party's side, swaying at its
// own pace, a wing looping and swooping.

import 'dart:math';

import 'package:alchemons/games/shared/companion_stance.dart';
import 'package:flutter_test/flutter_test.dart';

const range = 300.0;

/// Where a [family] companion stands round a target the size of a guardian
/// (radius 38) at the origin, with the party below it.
Offset _station(
  String family, {
  int slot = 0,
  double time = 0,
  bool closeIn = false,
  double attackRange = range,
}) => companionStation(
  target: Offset.zero,
  targetRadius: 38,
  bodyRadius: 15,
  attackRange: attackRange,
  stance: stanceForFamily(family),
  homeBearing: pi / 2,
  slot: slot,
  time: time,
  closeIn: closeIn,
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

  group('where it stands', () {
    test('off the target\'s edge, never inside its body', () {
      // A horn's reach (34% of a short range) used to put it inside a
      // guardian; its body and the target's are both counted now.
      for (final f in kCompanionStances.keys) {
        for (final t in [0.0, 1.7, 4.2, 9.9]) {
          expect(
            _station(f, time: t, attackRange: 120).distance,
            greaterThanOrEqualTo(38 + 15),
            reason: '$f at $t',
          );
        }
      }
    });

    test('within its own attack range when that reaches past the edge', () {
      for (final f in kCompanionStances.keys) {
        if (f == 'wing') continue; // it swoops out and back
        expect(_station(f).distance, lessThanOrEqualTo(range), reason: f);
      }
    });

    test('a horn presses closest, a kin stands furthest back', () {
      final d = {
        for (final f in kCompanionStances.keys) f: _station(f).distance,
      };
      for (final f in kCompanionStances.keys) {
        expect(d['horn']!, lessThanOrEqualTo(d[f]!), reason: f);
        if (f != 'wing') {
          expect(d['kin']!, greaterThanOrEqualTo(d[f]!), reason: f);
        }
      }
    });

    test('on the party\'s side of the target', () {
      for (final f in kCompanionStances.keys) {
        if (f == 'wing') continue; // it loops round
        expect(_station(f).dy, greaterThan(0), reason: f);
      }
    });

    test('a fifth closer while the target is open, never inside it', () {
      for (final f in ['pip', 'mane', 'kin']) {
        final open = _station(f, closeIn: true).distance;
        expect(open, lessThan(_station(f).distance), reason: f);
        expect(open, greaterThanOrEqualTo(38 + 15), reason: f);
      }
    });
  });

  group('how it moves', () {
    double bearing(Offset p) => atan2(p.dy, p.dx);

    test('no two companions sway in step', () {
      final a = [
        for (var t = 0.0; t < 10; t += 0.5)
          bearing(_station('mane', slot: 0, time: t)),
      ];
      final b = [
        for (var t = 0.0; t < 10; t += 0.5)
          bearing(_station('mane', slot: 1, time: t)),
      ];
      var differs = 0;
      for (var k = 1; k < a.length; k++) {
        final da = a[k] - a[k - 1], db = b[k] - b[k - 1];
        if ((da - db).abs() > 1e-3) differs++;
      }
      expect(differs, greaterThan(a.length ~/ 2));
    });

    test('a wing loops round the target and swoops in and out', () {
      final pts = [
        for (var t = 0.0; t < 12; t += 0.25) _station('wing', time: t),
      ];
      var turned = 0.0;
      for (var k = 1; k < pts.length; k++) {
        var d = bearing(pts[k]) - bearing(pts[k - 1]);
        d = atan2(sin(d), cos(d));
        turned += d;
      }
      expect(turned.abs(), greaterThan(pi), reason: 'it goes round');
      final r = pts.map((p) => p.distance).toList()..sort();
      expect(r.last - r.first, greaterThan(40), reason: 'and in and out');
    });

    test('a kin barely moves', () {
      final pts = [
        for (var t = 0.0; t < 12; t += 0.25) _station('kin', time: t),
      ];
      final b = pts.map(bearing).toList()..sort();
      expect(b.last - b.first, lessThan(0.15));
    });

    test('it is the same at any frame rate: a function of time alone', () {
      expect(
        _station('wing', slot: 2, time: 3.25),
        _station('wing', slot: 2, time: 3.25),
      );
    });
  });
}
