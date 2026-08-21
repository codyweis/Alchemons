import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/top_hud.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cumulative left-to-right boundaries, as fractions of the bar width.
List<double> _boundaries(List<MapEntry<String, double>> parts, double total) {
  final out = <double>[];
  var cum = 0.0;
  for (final p in parts) {
    cum += p.value;
    out.add(cum / total);
  }
  return out;
}

void main() {
  group('recipe notches line up with meter fill', () {
    test('a meter that exactly matches the recipe puts every segment edge '
        'on its notch', () {
      final recipe = PlanetRecipe.generate(
        element: 'Fire',
        seed: 11,
        level: 3,
      );

      // A perfect match is the named targets PLUS the recipe's "any"
      // allowance. Carrying only the named components leaves the meter short
      // of 100, which shifts every composition boundary — that is real
      // feedback ("you are over on Fire"), not a drawing bug.
      final meter = ElementMeter();
      for (final c in recipe.components.entries) {
        meter.add(c.key, c.value);
      }
      if (recipe.randomPct > 0) {
        final filler = kElementColors.keys.firstWhere(
          (e) => !recipe.components.containsKey(e),
        );
        meter.add(filler, recipe.randomPct);
      }
      expect(meter.total, closeTo(100.0, 0.0001));

      final fill = _boundaries(
        meterSegmentsInDrawOrder(meter).where(
          (e) => recipe.components.containsKey(e.key),
        ).toList(),
        meter.total,
      );
      final notches = _boundaries(recipeTargetsInDrawOrder(recipe), 100.0);

      expect(fill.length, notches.length);
      for (var i = 0; i < notches.length; i++) {
        expect(
          fill[i],
          closeTo(notches[i], 0.0001),
          reason: 'segment $i does not land on its notch',
        );
      }
    });

    test('both orderings agree for every generated recipe', () {
      for (final element in kElementColors.keys) {
        for (var level = 1; level <= 3; level++) {
          final recipe = PlanetRecipe.generate(
            element: element,
            seed: 7,
            level: level,
          );
          final meter = ElementMeter();
          for (final c in recipe.components.entries) {
            meter.add(c.key, c.value);
          }

          expect(
            meterSegmentsInDrawOrder(meter).map((e) => e.key).toList(),
            recipeTargetsInDrawOrder(recipe).map((e) => e.key).toList(),
            reason: '$element L$level draws fill and notches in different '
                'orders — the notches would point at the wrong segments',
          );
        }
      }
    });

    test('notches are absolute composition targets, not relative to what is '
        'carried', () {
      // Fire 50 / Water 50, no allowance.
      const recipe = PlanetRecipe(
        planetElement: 'Fire',
        level: 1,
        components: {'Fire': 50, 'Water': 50},
        randomPct: 0,
      );
      final notches = _boundaries(recipeTargetsInDrawOrder(recipe), 100.0);
      expect(notches, [closeTo(0.5, 1e-9), closeTo(1.0, 1e-9)]);

      // Carrying the right PROPORTIONS but only a quarter of a full meter
      // still lands on the notch — the bar shows composition.
      final light = ElementMeter();
      light.add('Fire', 12.5);
      light.add('Water', 12.5);
      final lightFill = _boundaries(
        meterSegmentsInDrawOrder(light),
        light.total,
      );
      expect(lightFill.first, closeTo(0.5, 1e-9));

      // Over-weighted on Fire: its edge runs PAST the notch.
      final skewed = ElementMeter();
      skewed.add('Fire', 70);
      skewed.add('Water', 30);
      final skewFill = _boundaries(
        meterSegmentsInDrawOrder(skewed),
        skewed.total,
      );
      expect(skewFill.first, greaterThan(notches.first));
    });

    test('ordering rule is descending by amount', () {
      final meter = ElementMeter();
      meter.add('Plant', 8);
      meter.add('Fire', 46);
      meter.add('Water', 24);
      meter.add('Dust', 22);

      expect(meterSegmentsInDrawOrder(meter).map((e) => e.key).toList(), [
        'Fire',
        'Water',
        'Dust',
        'Plant',
      ]);
    });
  });
}
