import 'dart:math';

import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  final double doubleValue;

  const _FixedRandom(this.doubleValue);

  @override
  bool nextBool() => doubleValue >= 0.5;

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => 49.clamp(0, max - 1);
}

void main() {
  const parentA = CreatureStats(
    speed: 5,
    intelligence: 4,
    strength: 3,
    beauty: 2,
    speedPotential: 100,
    intelligencePotential: 80,
    strengthPotential: 60,
    beautyPotential: 40,
  );
  const parentB = CreatureStats(
    speed: 1,
    intelligence: 2,
    strength: 3,
    beauty: 4,
    speedPotential: 10,
    intelligencePotential: 30,
    strengthPotential: 50,
    beautyPotential: 70,
  );

  test('breeding inherits only Potential and resets trained stats', () {
    for (var seed = 0; seed < 100; seed++) {
      final child = CreatureStats.breed(parentA, parentB, Random(seed));
      expect(child.speed, 1);
      expect(child.intelligence, 1);
      expect(child.strength, 1);
      expect(child.beauty, 1);
      expect(child.speedPotential, inInclusiveRange(1, 100));
      expect(child.intelligencePotential, inInclusiveRange(1, 100));
      expect(child.strengthPotential, inInclusiveRange(1, 100));
      expect(child.beautyPotential, inInclusiveRange(1, 100));
    }
  });

  test('Potential inheritance uses exact 35/35/30 boundaries', () {
    expect(
      AlchemonStatSystem.inheritPotential(
        const _FixedRandom(0.349999),
        100,
        10,
      ),
      100,
    );
    expect(
      AlchemonStatSystem.inheritPotential(const _FixedRandom(0.35), 100, 10),
      10,
    );
    expect(
      AlchemonStatSystem.inheritPotential(
        const _FixedRandom(0.699999),
        100,
        10,
      ),
      10,
    );
    expect(
      AlchemonStatSystem.inheritPotential(const _FixedRandom(0.70), 100, 10),
      50,
    );
  });

  test('legacy Potential values normalize from 0-5 to 1-100', () {
    expect(AlchemonStatSystem.normalizePotential(0), 1);
    expect(AlchemonStatSystem.normalizePotential(2.5), 3);
    expect(AlchemonStatSystem.normalizePotential(2.5, legacyScale: true), 50);
    expect(AlchemonStatSystem.normalizePotential(5), 5);
    expect(AlchemonStatSystem.normalizePotential(76), 76);

    final restoredLegacy = CreatureStats.fromJson({
      'speedPotential': 1.0,
      'intelligencePotential': 2.0,
      'strengthPotential': 3.0,
      'beautyPotential': 4.0,
    });
    expect(restoredLegacy.speedPotential, 20);
    expect(restoredLegacy.beautyPotential, 80);
  });

  test('versioned saves preserve legitimate new Potential rolls of 1-5', () {
    final restored = CreatureStats.fromJson({
      'statScaleVersion': 2,
      'speedPotential': 1,
      'intelligencePotential': 2,
      'strengthPotential': 3,
      'beautyPotential': 4,
    });

    expect(restored.speedPotential, 1);
    expect(restored.intelligencePotential, 2);
    expect(restored.strengthPotential, 3);
    expect(restored.beautyPotential, 4);
  });

  test('level and Enhancement are deterministic multipliers', () {
    final levelOne = AlchemonStatSystem.effectiveInternal(
      speciesBase: 60,
      level: 1,
      potential: 50,
    );
    final mature = AlchemonStatSystem.effectiveInternal(
      speciesBase: 60,
      level: 10,
      potential: 50,
    );
    final enhanced = AlchemonStatSystem.effectiveInternal(
      speciesBase: 60,
      level: 10,
      potential: 50,
      enhancementRank: 10,
    );

    expect(levelOne, closeTo(1.8975, 0.0001));
    expect(mature, closeTo(3.45, 0.0001));
    expect(enhanced, closeTo(4.485, 0.0001));
  });

  test('orb costs escalate toward rank ten', () {
    expect(AlchemonStatSystem.orbCostForNextRank(0), 1);
    expect(AlchemonStatSystem.orbCostForNextRank(3), 2);
    expect(AlchemonStatSystem.orbCostForNextRank(6), 4);
    expect(AlchemonStatSystem.orbCostForNextRank(9), 6);
  });

  test('display Power and legacy combat conversion share one scale', () {
    expect(AlchemonStatSystem.displayRating(5.0), 500);
    expect(AlchemonStatSystem.displayRating(9.0), 900);
    expect(AlchemonStatSystem.combatProgress(1.0), 0.0);
    expect(AlchemonStatSystem.combatProgress(5.0), 1.0);
    expect(AlchemonStatSystem.combatProgress(9.0), 1.30);
    expect(AlchemonStatSystem.legacyGameplayRating(9.0), 6.20);
  });
}
