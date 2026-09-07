import 'dart:math';

import 'package:alchemons/models/potential_soul.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Potential Soul gains cover exactly 1 through 5', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      seen.add(PotentialSoulRules.rollGain(Random(seed)));
    }
    expect(seen, {1, 2, 3, 4, 5});
  });

  test('Potential Souls stay out of early and mid Survival', () {
    for (var seed = 0; seed < 500; seed++) {
      expect(PotentialSoulRules.rollsFromSurvival(29, Random(seed)), isFalse);
    }
  });

  test('late Survival Soul rates remain rare and improve with depth', () {
    double rate(int wave) {
      var drops = 0;
      const samples = 10000;
      for (var seed = 0; seed < samples; seed++) {
        if (PotentialSoulRules.rollsFromSurvival(wave, Random(seed))) drops++;
      }
      return drops / samples;
    }

    final wave30 = rate(30);
    final wave40 = rate(40);
    final wave50 = rate(50);
    expect(wave30, inInclusiveRange(0.02, 0.04));
    expect(wave40, inInclusiveRange(0.05, 0.07));
    expect(wave50, inInclusiveRange(0.09, 0.11));
  });

  test('time-gated raids have a fifty percent Soul chance', () {
    var drops = 0;
    const samples = 10000;
    for (var seed = 0; seed < samples; seed++) {
      if (PotentialSoulRules.rollsFromRaid(Random(seed))) drops++;
    }
    expect(drops / samples, inInclusiveRange(0.48, 0.52));
  });
}
