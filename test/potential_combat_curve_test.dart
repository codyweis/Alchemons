import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_wave50_potential_test.dart' show potentialParty;

void main() {
  test('potential matches breeding targets and improves at every point', () {
    for (final entry in {
      20: 1.0,
      50: 1.25,
      70: 1.55,
      80: 1.8,
      90: 2.1,
      95: 2.3,
      100: 2.5,
    }.entries) {
      expect(
        AlchemonStatSystem.potentialMultiplier(entry.key),
        closeTo(entry.value, 1e-9),
      );
    }
    for (var p = 2; p <= 100; p++) {
      final gain =
          AlchemonStatSystem.potentialMultiplier(p) -
          AlchemonStatSystem.potentialMultiplier(p - 1);
      expect(gain, greaterThan(0));
      expect(gain, lessThanOrEqualTo(0.040000001));
    }
    expect(AlchemonStatSystem.potentialMultiplier(-1), 0.85);
    expect(AlchemonStatSystem.potentialMultiplier(101), 2.5);
    expect(
      AlchemonStatSystem.potentialMultiplier(95) /
          AlchemonStatSystem.potentialMultiplier(50),
      closeTo(1.84, 1e-9),
    );
  });

  test('level 10 catalog teams retain breeding gains in every mode', () {
    // Survival, the dungeons and open space all build a creature from the
    // one power model, so one curve covers every mode.
    var previousDps = 0.0;
    var previousHp = 0;
    for (final potential in [20, 35, 50, 70, 80, 90, 95, 100]) {
      var dps = 0.0;
      var hp = 0;
      for (final member in potentialParty(potential)) {
        final stats = deriveAlchemonCombatStats(member: member);
        // One-hit cadence reference, excluding specials, multi-hit patterns,
        // ship weapons, and movement. This is not a win-rate estimate.
        dps +=
            stats.physAtk /
            alchemonBasicAttackInterval(
              family: member.family,
              element: member.element,
              cooldownReduction: stats.cooldownReduction,
              physAtk: stats.physAtk,
            );
        hp += stats.maxHp;
      }
      debugPrint('P$potential cadence=${dps.toStringAsFixed(1)} HP=$hp');
      expect(dps, greaterThan(previousDps));
      expect(hp, greaterThan(previousHp));
      previousDps = dps;
      previousHp = hp;
    }
  });
}
