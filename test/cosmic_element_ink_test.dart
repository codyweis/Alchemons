import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('element ink on panel chrome', () {
    // The cosmic panels are near-black. Raw element colours are tuned for
    // planets against a starfield, and several are unreadable here: Dark sits
    // at 1.59:1 and Mud at 2.03:1 against bg1, which is why element chips
    // "looked off". `elementInk` lifts them.
    const chrome = CosmicScreenStyles.bg1;

    test('every element clears 3:1 after lifting', () {
      for (final element in kElementColors.keys) {
        expect(
          _contrast(elementInk(element), chrome),
          greaterThan(3.0),
          reason: '$element is too dark to read as UI ink',
        );
      }
    });

    test('lifting never makes an element harder to read', () {
      for (final element in kElementColors.keys) {
        expect(
          _contrast(elementInk(element), chrome),
          greaterThanOrEqualTo(_contrast(elementColor(element), chrome)),
          reason: '$element got darker',
        );
      }
    });

    test('the raw palette really does fail here — this is not busywork', () {
      // If these ever pass at raw values the lift can be reconsidered.
      expect(_contrast(elementColor('Dark'), chrome), lessThan(2.0));
      expect(_contrast(elementColor('Mud'), chrome), lessThan(2.5));
    });

    test('ink keeps the element recognisable', () {
      // A lift that washes everything to near-white would pass the contrast
      // bar while destroying the colour coding.
      for (final element in kElementColors.keys) {
        final raw = elementColor(element);
        final ink = elementInk(element);
        final drift =
            (raw.r - ink.r).abs() +
            (raw.g - ink.g).abs() +
            (raw.b - ink.b).abs();
        expect(drift, lessThan(1.2), reason: '$element drifted too far');
      }
    });
  });

  group('stale save keys', () {
    test('known elements pass, anything else is filtered', () {
      for (final element in kElementColors.keys) {
        expect(isKnownElement(element), isTrue, reason: element);
      }
      // Keys seen in the wild from older builds.
      expect(isKnownElement('Metal'), isFalse);
      expect(isKnownElement(''), isFalse);
      expect(isKnownElement('fire'), isFalse, reason: 'case matters');
    });
  });
}
