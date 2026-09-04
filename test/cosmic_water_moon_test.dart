// AQUARIS HAS A MOON, and the tide dungeon down there runs on its phases.
//
// Everything worth checking about it is geometry, and geometry is the one
// thing a screenshot comparison cannot answer: a moon that never goes dark
// still changes every pixel as it moves.

import 'dart:math' show cos, pi, sin;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the painter's own orbit. Kept beside it deliberately: if one
/// moves without the other, the numbers below stop describing the moon.
const double _scale = 0.30;
const double _speed = 0.22;
const double _lightAngle = -2.356;

double _illumAt(double t) => (1 - cos(t * _speed - _lightAngle)) / 2;
bool _inFrontAt(double t) => sin(t * _speed) > 0;

void main() {
  test('the moon is about a third of the planet', () {
    expect(_scale, closeTo(0.30, 0.001));
  });

  test('it goes behind the planet and comes back round', () {
    // A moon that is always in front is a sticker, not an orbit.
    var front = 0, behind = 0;
    for (var t = 0.0; t < 2 * pi / _speed; t += 0.25) {
      _inFrontAt(t) ? front++ : behind++;
    }
    expect(front, greaterThan(0));
    expect(behind, greaterThan(0));
    expect(
      (front - behind).abs(),
      lessThan(front),
      reason: 'it should spend comparable time on each side',
    );
  });

  test('it runs the whole way from new to full', () {
    // The first cut used cos() straight as the shadow offset, which pushed
    // the shadow clear at BOTH ends of the swing: full when it should have
    // been new, and no dark phase anywhere in the orbit.
    var lo = 1.0, hi = 0.0;
    for (var t = 0.0; t < 2 * pi / _speed; t += 0.1) {
      final i = _illumAt(t);
      if (i < lo) lo = i;
      if (i > hi) hi = i;
    }
    expect(lo, lessThan(0.02), reason: 'it has to go dark: got $lo');
    expect(hi, greaterThan(0.98), reason: 'and full: got $hi');
  });

  test('it is lit on the side the light is on', () {
    // Fullest when it is round the far side from the light, darkest when it
    // is between the viewer and the light. Backwards is a moon lit from the
    // wrong side, which reads as broken without anyone being able to say why.
    expect(_illumAt((_lightAngle + pi) / _speed), closeTo(1.0, 0.01));
    expect(_illumAt((_lightAngle + 2 * pi) / _speed), closeTo(0.0, 0.01));
  });

  test('Water is the planet that has one', () {
    expect(kCosmicPlanetEntry.containsKey('Water'), isTrue);
  });
}
