import 'dart:math';

import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/potential_genetics.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('a recipe hit keeps the 35/35/30 shares, a miss drops to 20/20/60', () {
    ({double a, double b}) shares({
      required bool hit,
      bool aDom = false,
      bool bDom = false,
    }) => PotentialGenetics.parentShares(
      recipeHit: hit,
      aDominant: aDom,
      bDominant: bDom,
    );

    final hit = shares(hit: true);
    expect(hit.a, closeTo(0.35, 1e-9));
    expect(hit.b, closeTo(0.35, 1e-9));

    final miss = shares(hit: false);
    expect(miss.a, closeTo(0.20, 1e-9));
    expect(miss.b, closeTo(0.20, 1e-9));
  });

  test('a Dominant stat leans on its parent and strangers less often', () {
    final soloHit = PotentialGenetics.parentShares(
      recipeHit: true,
      aDominant: true,
      bDominant: false,
    );
    expect(soloHit.a, closeTo(0.50, 1e-9));
    expect(soloHit.b, closeTo(0.35, 1e-9));
    expect(1 - soloHit.a - soloHit.b, closeTo(0.15, 1e-9));

    final soloMiss = PotentialGenetics.parentShares(
      recipeHit: false,
      aDominant: true,
      bDominant: false,
    );
    expect(soloMiss.a, closeTo(0.32, 1e-9));
    expect(soloMiss.b, closeTo(0.20, 1e-9));

    // Both Dominant splits a smaller bonus rather than doubling it.
    final both = PotentialGenetics.parentShares(
      recipeHit: true,
      aDominant: true,
      bDominant: true,
    );
    expect(both.a, closeTo(0.42, 1e-9));
    expect(both.b, closeTo(0.42, 1e-9));
  });

  test('a miss can never hand back more Potential than the better parent', () {
    final range = PotentialGenetics.strangerRange(
      recipeHit: false,
      parentA: 40,
      parentB: 62,
    );
    expect(range.lo, 1);
    expect(range.hi, 62);

    // The whole point of the cap: hatching in volume off mediocre stock
    // cannot fish up a high Potential.
    final rng = Random(4);
    var best = 0;
    for (var i = 0; i < 5000; i++) {
      final value = PotentialGenetics.inheritPotential(
        rng,
        parentA: 40,
        parentB: 62,
        stat: StatKind.strength,
        recipeHit: false,
      );
      if (value > best) best = value;
    }
    expect(best, lessThanOrEqualTo(62));
  });

  test('a recipe hit is the only roll that can exceed both parents', () {
    final range = PotentialGenetics.strangerRange(
      recipeHit: true,
      parentA: 40,
      parentB: 90,
    );
    expect(range.lo, 54); // 90 * 0.60
    expect(range.hi, AlchemonStatSystem.maxPotential);

    final rng = Random(9);
    var exceeded = false;
    for (var i = 0; i < 5000 && !exceeded; i++) {
      exceeded =
          PotentialGenetics.inheritPotential(
            rng,
            parentA: 40,
            parentB: 90,
            stat: StatKind.strength,
            recipeHit: true,
          ) >
          90;
    }
    expect(exceeded, isTrue);
  });

  test('complementary parents pass one Dominant each', () {
    final a = DominantStats(StatKind.strength, StatKind.intelligence);
    final b = DominantStats(StatKind.speed, StatKind.beauty);

    for (var seed = 0; seed < 400; seed++) {
      final child = PotentialGenetics.inheritDominants(Random(seed), a, b);
      expect(child.first, isNot(child.second));
      // Between them these parents cover every stat, so any pair is legal --
      // what must hold is that the child always carries exactly two.
      expect(child.all.length, 2);
    }
  });

  test('a matched line breeds true, but can still drift', () {
    // Both parents Dominant in the same two stats, so anything outside that
    // pair can only have come from drift.
    final pair = DominantStats(StatKind.strength, StatKind.intelligence);

    var bredTrue = 0;
    var drifted = 0;
    for (var seed = 0; seed < 600; seed++) {
      final child = PotentialGenetics.inheritDominants(
        Random(seed),
        pair,
        pair,
      );
      expect(child.first, isNot(child.second));
      if (child == pair) {
        bredTrue++;
      } else {
        drifted++;
      }
    }

    // The line holds most of the time...
    expect(bredTrue / 600, greaterThan(0.80));
    // ...but never ossifies completely.
    expect(drifted, greaterThan(0));
  });

  test('an Alchemon with no stored Dominants is Dominant in its best two', () {
    final derived = DominantStats.fromPotentials(
      speed: 30,
      intelligence: 91,
      strength: 74,
      beauty: 12,
    );
    expect(derived.contains(StatKind.intelligence), isTrue);
    expect(derived.contains(StatKind.strength), isTrue);
    expect(derived.contains(StatKind.speed), isFalse);

    // Deterministic: the same creature never resolves two different ways.
    expect(
      DominantStats.fromPotentials(
        speed: 30,
        intelligence: 91,
        strength: 74,
        beauty: 12,
      ),
      derived,
    );
    expect(DominantStats.decode(derived.encode()), derived);
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
