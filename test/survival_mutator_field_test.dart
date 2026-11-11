import 'dart:ui';

import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/mutator_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts what a paint asks the GPU to do.
class _Census implements Canvas {
  int draws = 0, blurred = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    if (n.contains('"draw')) draws++;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurred++;
    }
    return null;
  }
}

void main() {
  const view = Rect.fromLTWH(-200, -450, 412, 915);

  test('a mutator\'s look eases in, and the last one goes before the next '
      'comes', () {
    final field = MutatorField();
    expect(field.shown, isNull);
    for (var i = 0; i < 300; i++) {
      field.update(1 / 60, SurvivalWaveMutator.orbSiege);
    }
    expect(field.shown, SurvivalWaveMutator.orbSiege);
    expect(field.strength, greaterThan(0.9));
    // The wave turns over to another mutator: the old look fades first.
    field.update(1 / 60, SurvivalWaveMutator.manaFlux);
    expect(field.shown, SurvivalWaveMutator.orbSiege);
    for (var i = 0; i < 900; i++) {
      field.update(1 / 60, SurvivalWaveMutator.manaFlux);
    }
    expect(field.shown, SurvivalWaveMutator.manaFlux);
    expect(field.strength, greaterThan(0.9));
    for (var i = 0; i < 900; i++) {
      field.update(1 / 60, null);
    }
    expect(field.shown, isNull);
  });

  test('every look is at most three point draws, with no blur, and nothing '
      'when no mutator runs', () {
    for (final mutator in SurvivalWaveMutator.values) {
      final field = MutatorField();
      final idle = _Census();
      field.paint(idle as Canvas, view, Offset.zero, 1140, 3, const Color(0xFF4FB3FF));
      expect(idle.draws, 0, reason: '$mutator before it runs');
      for (var i = 0; i < 300; i++) {
        field.update(1 / 60, mutator);
      }
      final c = _Census();
      field.paint(c as Canvas, view, Offset.zero, 1140, 3, const Color(0xFF4FB3FF));
      expect(c.draws, inInclusiveRange(1, 3), reason: '$mutator');
      expect(c.blurred, 0, reason: '$mutator');
    }
  });
}
