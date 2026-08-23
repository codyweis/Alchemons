// The home screen is a fixed composition: header, a 260px hero, a side dock
// and the daily chest, every one of them anchored to an edge at a hard-coded
// pixel size. Nothing flexes, so on a short viewport they run into each other.
//
// _homeScaleFor is the single factor every one of those dimensions is
// multiplied by. These check the arithmetic actually separates them, rather
// than just making things smaller.

import 'package:alchemons/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the composition in build(): header, gap, hero.
double topBlock(double k) => 68 + (20 * k) + (260 * k);

/// The chest occupies from its bottom padding up through its own height.
double bottomBlock(double k) => (90 * k) + (160 * k);

void main() {
  group('the scale factor', () {
    test('leaves tall screens exactly as they were', () {
      for (final h in [780.0, 800.0, 900.0, 1200.0]) {
        expect(homeScaleForTest(h), 1.0, reason: '${h}dp');
      }
    });

    test('shrinks proportionally below the design height', () {
      expect(homeScaleForTest(702), closeTo(0.9, 1e-9));
      expect(homeScaleForTest(624), closeTo(0.8, 1e-9));
    });

    test('never collapses past the usability floor', () {
      // Below this the composition simply does not fit; shrinking further
      // would make touch targets unusable rather than fixing anything.
      for (final h in [400.0, 300.0, 100.0, 0.0]) {
        expect(homeScaleForTest(h), homeMinScaleForTest, reason: '${h}dp');
      }
    });

    test('is monotonic — a shorter screen never scales up', () {
      var last = double.infinity;
      for (var h = 1000.0; h >= 300; h -= 25) {
        final k = homeScaleForTest(h);
        expect(k, lessThanOrEqualTo(last), reason: '${h}dp');
        last = k;
      }
    });
  });

  group('the hero and the chest stop colliding', () {
    test('unscaled, the composition commits 598px before anything flexes', () {
      // 68 header + 20 gap + 260 hero = 348 from the top, and 90 + 160 for
      // the chest from the bottom. A 600dp viewport is left with 2px between
      // them — touching — and anything shorter overlaps outright.
      const unscaled = 1.0;
      final committed = topBlock(unscaled) + bottomBlock(unscaled);
      expect(committed, closeTo(598, 0.5));
      expect(600 - committed, lessThan(5), reason: 'effectively touching');
      expect(560 - committed, lessThan(0), reason: 'overlapping outright');
    });

    test('scaling keeps daylight between them on short screens', () {
      for (final h in [560.0, 600.0, 640.0, 700.0, 780.0]) {
        final k = homeScaleForTest(h);
        final gap = h - topBlock(k) - bottomBlock(k);
        expect(
          gap,
          greaterThan(0),
          reason: 'at ${h}dp the hero and chest overlap by ${-gap}px',
        );
      }
    });

    test('a tall screen keeps its generous spacing', () {
      final gap = 900 - topBlock(homeScaleForTest(900)) -
          bottomBlock(homeScaleForTest(900));
      expect(gap, greaterThan(200));
    });
  });

  test('the side dock starts above the chest on a short screen', () {
    // Dock top is 140 * k from the safe area; the chest top is
    // height - (90 + 160) * k. They must not cross.
    for (final h in [560.0, 640.0, 780.0]) {
      final k = homeScaleForTest(h);
      expect(140 * k, lessThan(h - bottomBlock(k)), reason: '${h}dp');
    }
  });
}
