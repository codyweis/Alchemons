// The four cull checks in the cosmic render loop were written out by hand, and
// the planet one used `&&` where the other three used `||`. A planet was
// therefore only skipped when it was off screen horizontally AND vertically —
// so anything off to the side but vertically aligned rendered in full, and a
// planet body is the most blur-heavy thing in the game (Ice draws eleven).


import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter_test/flutter_test.dart';

// A 400x800 viewport whose top-left is the world origin, so its centre is
// (200, 400).
const cx = 0.0, cy = 0.0, w = 400.0, h = 800.0;
const centre = Offset(200, 400);

bool cull(Offset p, {double margin = 1.0}) =>
    isOutsideViewport(p, cx, cy, w, h, margin: margin);

void main() {
  group('what stays on screen', () {
    test('the centre is never culled', () {
      expect(cull(centre), isFalse);
    });

    test('anything within the margin box is kept', () {
      for (final p in [
        centre,
        centre + const Offset(399, 0),
        centre + const Offset(0, 799),
        centre - const Offset(399, 0),
        centre + const Offset(399, 799),
      ]) {
        expect(cull(p), isFalse, reason: '$p');
      }
    });
  });

  group('what gets culled', () {
    test('far off to the side, even when vertically centred', () {
      // The exact case the bug missed: dx is way out, dy is dead centre.
      expect(cull(centre + const Offset(2000, 0)), isTrue);
      expect(cull(centre - const Offset(2000, 0)), isTrue);
    });

    test('far above or below, even when horizontally centred', () {
      expect(cull(centre + const Offset(0, 2000)), isTrue);
      expect(cull(centre - const Offset(0, 2000)), isTrue);
    });

    test('far out on both axes', () {
      expect(cull(centre + const Offset(2000, 2000)), isTrue);
    });

    test('either axis alone is enough — this is the fix', () {
      // Under the old `&&` both of these rendered in full.
      final sideways = centre + const Offset(1200, 10);
      final vertical = centre + const Offset(10, 2400);
      expect(cull(sideways), isTrue);
      expect(cull(vertical), isTrue);
    });
  });

  group('margin', () {
    test('a wider margin keeps more on screen', () {
      final p = centre + const Offset(500, 0);
      expect(cull(p, margin: 1.0), isTrue);
      expect(cull(p, margin: 1.5), isFalse);
    });

    test('the boundary is exclusive, so a point exactly on it is kept', () {
      expect(cull(centre + const Offset(w, 0)), isFalse);
      expect(cull(centre + const Offset(w + 0.01, 0)), isTrue);
    });
  });

  test('a non-zero camera origin shifts the box with it', () {
    // The viewport's top-left is (1000, 2000), so its centre is (1200, 2400).
    bool moved(Offset p) => isOutsideViewport(p, 1000, 2000, w, h);
    expect(moved(const Offset(1200, 2400)), isFalse);
    expect(moved(Offset.zero), isTrue, reason: 'the origin is now far away');
  });
}
