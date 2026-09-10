import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
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

  test('level 10 catalog teams retain breeding gains in both combat modes', () {
    var previousSpace = 0.0;
    var previousSurvival = 0.0;
    var previousHp = 0;
    for (final potential in [20, 35, 50, 70, 80, 90, 95, 100]) {
      var spaceDps = 0.0;
      var survivalDps = 0.0;
      var hp = 0;
      for (final member in potentialParty(potential)) {
        final survival = deriveCosmicSurvivalCompanionStats(member: member);
        final attack = CosmicBalance.companionPhysAtk(
          level: 10,
          strength: member.statStrength,
        );
        final companion = CosmicCompanion(
          member: member,
          position: Offset.zero,
          maxHp: 100,
          currentHp: 100,
          physAtk: attack,
          elemAtk: 1,
          physDef: 1,
          elemDef: 1,
          cooldownReduction: CosmicBalance.companionCooldownReduction(
            member.statSpeed,
          ),
          critChance: 0,
          attackRange: 100,
          specialAbilityRange: 100,
        );
        // One-hit cadence reference, excluding specials, multi-hit patterns,
        // crits, ship weapons, and movement. This is not a win-rate estimate.
        spaceDps += attack / companion.effectiveBasicCooldown;
        final survivalCompanion = CosmicCompanion(
          member: member,
          position: Offset.zero,
          maxHp: survival.maxHp,
          currentHp: survival.maxHp,
          physAtk: survival.physAtk,
          elemAtk: survival.elemAtk,
          physDef: survival.physDef,
          elemDef: survival.elemDef,
          cooldownReduction: survival.cooldownReduction,
          critChance: survival.critChance,
          attackRange: survival.attackRange,
          specialAbilityRange: survival.specialAbilityRange,
        );
        survivalDps +=
            survival.physAtk / survivalCompanion.effectiveBasicCooldown;
        hp += survival.maxHp;
      }
      debugPrint(
        'P$potential spaceCadence=${spaceDps.toStringAsFixed(1)} '
        'survivalCadence=${survivalDps.toStringAsFixed(1)} survivalHP=$hp',
      );
      expect(spaceDps, greaterThan(previousSpace));
      expect(survivalDps, greaterThan(previousSurvival));
      expect(hp, greaterThan(previousHp));
      previousSpace = spaceDps;
      previousSurvival = survivalDps;
      previousHp = hp;
    }
  });
}
