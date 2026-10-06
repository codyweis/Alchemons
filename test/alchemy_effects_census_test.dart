// The shop's alchemy effects used to cost up to ~36 gaussian blur passes per
// creature per frame, written three times over (widget, Flame, space). They
// are one blur-free painter now, shared by all three.
//
// A budget test, not a golden: it does not care what an effect looks like,
// only that nobody reintroduces a blur, a layer, or a draw per grain. Widget
// tests never rasterise, so frame timings cannot see blur cost; this is the
// only check on it.

import 'dart:ui';

import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/fx/costume_paint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (n, e) => n + e.value);

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && (a.maskFilter != null || a.imageFilter != null)) {
        blurredDraws++;
      }
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get(String k) => counts[k] ?? 0;
}

const _elements = [
  'Fire', 'Water', 'Earth', 'Air', 'Steam', 'Lava', 'Lightning', 'Mud', //
  'Ice', 'Dust', 'Crystal', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
  'Blood', 'Volcanic', 'Oceanic', 'Verdant', 'Earthen', 'Arcane', 'Bloodborn',
  null,
];

/// Every way each rebuilt key can be painted: elements, plates, sizes, and
/// the layers behind and in front of the creature.
Iterable<(String, String?, bool, double, bool)> _variants() sync* {
  for (final key in AlchemyEffectPaint.keys) {
    final elements = key == AlchemyEffectPaint.elementalAura
        ? _elements
        : const <String?>[null];
    for (final element in elements) {
      for (final dark in const [true, false]) {
        for (final r in const [12.0, 24.0, 55.0, 95.0]) {
          for (final front in const [false, true]) {
            yield (key, element, dark, r, front);
          }
        }
      }
    }
  }
}

void main() {
  test('no rebuilt alchemy effect ever blurs, layers or draws per grain', () {
    final worst = <String, int>{};
    for (final (key, element, dark, r, front) in _variants()) {
      // Sixty frames over twelve seconds: every split, drip and burst.
      for (var f = 0; f < 60; f++) {
        final c = _CensusCanvas();
        AlchemyEffectPaint.paint(
          c as Canvas,
          key,
          const Offset(100, 100),
          r,
          f * 0.2,
          element: element,
          dark: dark,
          front: front,
        );
        final label =
            '$key ${element ?? ''} ${dark ? 'dark' : 'light'} r$r'
            '${front ? ' front' : ''}';
        expect(c.blurredDraws, 0, reason: label);
        expect(c.get('saveLayer'), 0, reason: label);
        expect(
          c.draws,
          lessThanOrEqualTo(16),
          reason: '$label: grains must stay batched (${c.counts})',
        );
        final id = '$key ${element ?? ''}${front ? ' front' : ''}';
        if (c.draws > (worst[id] ?? 0)) worst[id] = c.draws;
      }
    }
    // ignore: avoid_print
    print('most draws in a frame: $worst');
  });

  test('a worn costume, drawn by the sprite, keeps the same budget', () {
    for (final species in ['WNG01', 'WNG04', 'PIP01', 'HOR01', 'LET01']) {
      for (var f = 0; f < 60; f++) {
        final c = _CensusCanvas();
        CostumePaint.paintWorn(
          c as Canvas,
          // All three at once.
          WornCostumes(species, {
            for (final c in FamilyCostume.values) c: c.defaultColor,
          }).encode(),
          const Rect.fromLTWH(0, 0, 200, 200),
          f % 4,
          f * 0.2,
        );
        expect(c.blurredDraws, 0, reason: species);
        expect(c.get('saveLayer'), 0, reason: species);
        expect(
          c.draws,
          inInclusiveRange(1, 40),
          reason: '$species ${c.counts}',
        );
      }
    }
  });

  test('every rebuilt key is known and an unknown one paints nothing', () {
    for (final key in AlchemyEffectPaint.keys) {
      expect(AlchemyEffectPaint.has(key), isTrue);
    }
    // Worn, a costume is the sprite's, not an effect round it.
    expect(AlchemyEffectPaint.has('WNG04:hat'), isFalse);
    expect(AlchemyEffectPaint.has('not_an_effect'), isFalse);
    expect(AlchemyEffectPaint.has(null), isFalse);
    final c = _CensusCanvas();
    AlchemyEffectPaint.paint(c as Canvas, 'not_an_effect', Offset.zero, 40, 1);
    expect(c.draws, 0);
  });
}
