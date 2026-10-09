// THE PLANETS' BUDGET. Every planet in view is drawn every frame, and the
// old art asked for a gaussian blur pass per glow — two dozen a frame for
// Magmora alone. The rebuild asks for none. This keeps it that way, and
// keeps each planet's draw count and its territory's motes bounded.
//
// A budget test, not a golden: it does not care what the planets look like
// (test/planet_look_preview_test.dart renders that), only what they cost.

import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/planets/planet_art.dart';
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

CosmicPlanet _planet(String element) => CosmicPlanet(
  element: element,
  position: const Offset(5000, 5000),
  radius: kPlanetRadius[element]!,
  discovered: true,
);

void main() {
  test('no planet draws a blur, at any moment', () {
    for (final el in kPlanetRadius.keys) {
      final planet = PlanetComponent(planet: _planet(el));
      for (final t in [0.0, 1.7, 4.2, 9.9, 33.3, 120.0]) {
        final c = _CensusCanvas();
        planet.render(c as Canvas, t, drawLabel: false);
        expect(c.blurredDraws, 0, reason: '$el blurs at t=$t');
      }
    }
  });

  test('no planet asks for more than a few dozen draws', () {
    for (final el in kPlanetRadius.keys) {
      final planet = PlanetComponent(planet: _planet(el));
      var worst = 0;
      for (var t = 0.0; t < 60; t += 0.37) {
        final c = _CensusCanvas();
        planet.render(c as Canvas, t, drawLabel: false);
        if (c.draws > worst) worst = c.draws;
      }
      // Headroom, not a target. The originals the player asked back
      // (Vaporis' fog and geysers, Zephyria's bands and motes) are many
      // small soft shapes and peak in the 60s; the rest sit well under 50.
      // All of them plain fills and strokes — blur is checked above.
      expect(worst, lessThanOrEqualTo(80), reason: '$el peaks at $worst');
    }
  });

  test('territory motes draw no blur and stay capped', () {
    for (final el in kPlanetRadius.keys) {
      final art = planetArtFor(_planet(el));
      final c = _CensusCanvas();
      art.paintTerritory(
        c as Canvas,
        const Offset(5000, 5000),
        // Farthest zoom on a big landscape phone: the widest view there is.
        const Rect.fromLTWH(3600, 4400, 2400, 1100),
        1.0,
        7.0,
      );
      expect(c.blurredDraws, 0, reason: el);
      // Ninety motes, up to four fills each; Toxivyre adds its fog.
      expect(c.draws, lessThanOrEqualTo(400), reason: '$el: ${c.draws}');
    }
  });

  test('building every planet is cheap, and done once', () {
    final sw = Stopwatch()..start();
    for (final el in kPlanetRadius.keys) {
      planetArtFor(
        CosmicPlanet(
          element: el,
          position: const Offset(1234, 5678),
          radius: kPlanetRadius[el]!,
        ),
      );
    }
    final built = sw.elapsedMilliseconds;
    final again = planetArtFor(
      CosmicPlanet(
        element: 'Lava',
        position: const Offset(1234, 5678),
        radius: kPlanetRadius['Lava']!,
      ),
    );
    expect(
      identical(
        again,
        planetArtFor(
          CosmicPlanet(
            element: 'Lava',
            position: const Offset(1234, 5678),
            radius: kPlanetRadius['Lava']!,
          ),
        ),
      ),
      isTrue,
    );
    // Generous for a JIT test run; on device it is a fraction of this, at
    // world load.
    expect(built, lessThan(1500), reason: 'all 17 took $built ms');
  });

  test('home customizations draw no blur, and stay cheap even all at once', () {
    const p = Offset(5000, 5000);
    const r = 190.0;
    // The ship parked inside the rings, so the wake path runs too.
    const ship = Offset(5230, 5040);
    final fx = HomeEffectsArt.instance;
    int census(Set<String> active, double t) {
      final c = _CensusCanvas();
      fx.paintBehind(
        c as Canvas,
        p,
        r,
        t,
        active,
        const {},
        wake: ship,
        sizeTier: 3,
      );
      fx.paintFront(
        c as Canvas,
        p,
        r,
        t,
        active,
        const {},
        wake: ship,
        sizeTier: 3,
      );
      expect(c.blurredDraws, 0, reason: '$active blurs at t=$t');
      return c.draws;
    }

    for (final id in HomeEffectsArt.handled) {
      var worst = 0;
      for (var t = 0.0; t < 30; t += 0.23) {
        worst = max(worst, census({id}, t));
      }
      // Each is a few batched point draws and a handful of soft fills.
      expect(worst, lessThanOrEqualTo(60), reason: '$id peaks at $worst');
    }
    var all = 0;
    for (var t = 0.0; t < 30; t += 0.23) {
      all = max(all, census(HomeEffectsArt.handled, t));
    }
    // The heaviest settings there are: density adds grains, not draws.
    const heavy = {
      'black_hole.density': 'Maximum',
      'black_hole.disk': 'Vast',
      'black_hole.color': 'Spectral',
      'planetary_rings.width': 'Vast',
      'planetary_rings.count': '3',
    };
    for (final id in ['black_hole', 'planetary_rings']) {
      for (var t = 0.0; t < 30; t += 0.23) {
        final c = _CensusCanvas();
        fx.paintBehind(
          c as Canvas,
          p,
          r,
          t,
          {id},
          heavy,
          wake: ship,
          sizeTier: 3,
        );
        fx.paintFront(
          c as Canvas,
          p,
          r,
          t,
          {id},
          heavy,
          wake: ship,
          sizeTier: 3,
        );
        expect(c.blurredDraws, 0);
        expect(c.draws, lessThanOrEqualTo(60), reason: '$id heavy: ${c.draws}');
      }
    }
    // The premium colors' bodies, blur-free too.
    for (final id in ['Void', 'Radiant']) {
      final c = _CensusCanvas();
      expect(fx.paintPremiumAura(c as Canvas, p, r, 3, id), isTrue);
      expect(fx.paintPremiumBody(c as Canvas, p, r, 3, id), isTrue);
      expect(c.blurredDraws, 0, reason: id);
    }
    expect(all, lessThanOrEqualTo(400), reason: 'everything at once: $all');
  });
}
