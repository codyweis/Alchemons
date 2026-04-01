// lib/services/wild_creature_randomizer.dart

import 'dart:math';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/wilderness_stat_ranges.dart';

class WildCreatureRandomizer {
  final Random _random;

  WildCreatureRandomizer({Random? random}) : _random = random ?? Random();

  /// Prepare a wild (catalog) creature for breeding by giving it random stats
  Creature randomizeWildCreature(
    Creature wild, {
    int? seed,
    bool arcaneBoostUnlocked = false,
  }) {
    final rng = seed != null ? Random(seed) : _random;

    // Random nature
    final nature = NatureCatalogWeighted.weightedRandom(rng);

    // Random genetics (use baseline with slight variation)
    final genetics = _randomizeGenetics(wild.genetics, rng);

    // Random stats (wild creatures have average stats)
    final stats = _generateWildStats(
      wild.rarity,
      rng,
      arcaneBoostUnlocked: arcaneBoostUnlocked,
    );

    return wild.copyWith(nature: nature, genetics: genetics, stats: stats);
  }

  Genetics? _randomizeGenetics(Genetics? baseGenetics, Random rng) {
    if (baseGenetics == null) return null;

    // Keep base genetics but add slight randomization
    final variants = Map<String, String>.from(baseGenetics.variants);

    // Could add slight mutations here if desired
    // For now, just use base genetics with potential for variation

    return Genetics(variants);
  }

  CreatureStats _generateWildStats(
    String rarity,
    Random rng, {
    required bool arcaneBoostUnlocked,
  }) {
    // Wild creatures have stats based on rarity
    final baseRange = wildernessStatRangeForRarity(
      rarity,
      arcaneBoostUnlocked: arcaneBoostUnlocked,
    );
    final speedPair = _rollStatPair(rng, baseRange);
    final intelligencePair = _rollStatPair(rng, baseRange);
    final strengthPair = _rollStatPair(rng, baseRange);
    final beautyPair = _rollStatPair(rng, baseRange);

    return CreatureStats(
      speed: speedPair.stat,
      intelligence: intelligencePair.stat,
      strength: strengthPair.stat,
      beauty: beautyPair.stat,
      speedPotential: speedPair.potential,
      intelligencePotential: intelligencePair.potential,
      strengthPotential: strengthPair.potential,
      beautyPotential: beautyPair.potential,
    );
  }

  ({double stat, double potential}) _rollStatPair(
    Random rng,
    WildernessStatRange range,
  ) {
    final potential = _rollPotential(rng, range);
    final statMax = min(range.max, potential);
    return (
      stat: _rollStat(rng, range, maxOverride: statMax),
      potential: potential,
    );
  }

  double _rollStat(
    Random rng,
    WildernessStatRange range, {
    double? maxOverride,
  }) {
    final maxValue = maxOverride ?? range.max;
    return range.min + (rng.nextDouble() * (maxValue - range.min));
  }

  double _rollPotential(Random rng, WildernessStatRange range) {
    return range.potMin + (rng.nextDouble() * (range.potMax - range.potMin));
  }
}
