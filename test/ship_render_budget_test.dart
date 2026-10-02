// THE SHIP'S BUDGET. The hull, its wake and its orbital sentinels are drawn
// every frame in space and in survival (lib/games/cosmic/ship_art.dart).
// This keeps them blur-free and keeps each hull's draw count where it was
// measured when the hulls were rebuilt (2026-10-02).
//
// A budget test, not a golden: test/ship_look_preview_test.dart renders what
// they look like.

import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

void main() {
  // Peak draws per frame: hull plus wake, boosting through a turn with a
  // hit flash. Each wake pass is one drawRawPoints however many grains.
  const budget = <String?, int>{
    null: 27,
    'skin_phantom': 29,
    'skin_solar': 35,
    'skin_inferno': 31,
    'skin_crystal': 34,
  };

  for (final MapEntry(key: skin, value: limit) in budget.entries) {
    test('${skin ?? 'standard'} hull: no blur, at most $limit draws', () {
      final ship = ShipComponent(pos: Offset.zero);
      var peak = 0;
      for (var f = 0; f < 240; f++) {
        final t = f / 60;
        ship
          ..angle = -pi / 2 + t * 1.4
          ..pos += Offset(cos(ship.angle), sin(ship.angle)) * (550 / 60);
        final c = _CensusCanvas();
        ship.render(c as Canvas, t, skin: skin, boost: 1, flash: 0.5);
        expect(c.blurredDraws, 0, reason: 'frame $f');
        peak = max(peak, c.draws);
      }
      expect(peak, lessThanOrEqualTo(limit));
    });
  }

  test('an orbital sentinel: no blur, at most 6 draws', () {
    for (final skin in budget.keys) {
      final c = _CensusCanvas();
      paintOrbitalSentinel(
        c as Canvas,
        Offset.zero,
        shipLight(skin),
        time: 2.3,
        seed: 1.7,
      );
      expect(c.blurredDraws, 0);
      expect(c.draws, lessThanOrEqualTo(6));
    }
  });
}
