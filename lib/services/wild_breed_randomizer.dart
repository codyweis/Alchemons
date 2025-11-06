// lib/services/wild_creature_randomizer.dart

import 'dart:math';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';

class WildCreatureRandomizer {
  final Random _random;

  WildCreatureRandomizer({Random? random}) : _random = random ?? Random();

  /// Prepare a wild (catalog) creature for breeding by giving it random stats
  Creature randomizeWildCreature(Creature wild, {int? seed}) {
    final rng = seed != null ? Random(seed) : _random;

    // Random nature
    final nature = NatureCatalogWeighted.weightedRandom(rng);

    // Random genetics (use baseline with slight variation)
    final genetics = _randomizeGenetics(wild.genetics, rng);

    // Random stats (wild creatures have average stats)
    final stats = _generateWildStats(wild.rarity, rng);

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

  CreatureStats _generateWildStats(String rarity, Random rng) {
    // Wild creatures have stats based on rarity
    final baseRange = _getStatRangeForRarity(rarity);

    return CreatureStats(
      speed: _rollStat(rng, baseRange),
      intelligence: _rollStat(rng, baseRange),
      strength: _rollStat(rng, baseRange),
      beauty: _rollStat(rng, baseRange),
      speedPotential: _rollPotential(rng, baseRange),
      intelligencePotential: _rollPotential(rng, baseRange),
      strengthPotential: _rollPotential(rng, baseRange),
      beautyPotential: _rollPotential(rng, baseRange),
    );
  }

  ({double min, double max, double potMin, double potMax})
  _getStatRangeForRarity(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return (min: 1.0, max: 3.0, potMin: 2.0, potMax: 4.0);
      case 'uncommon':
        return (min: 2.0, max: 4.0, potMin: 3.0, potMax: 5.0);
      case 'rare':
        return (min: 3.0, max: 5.0, potMin: 4.0, potMax: 6.0);
      case 'mythic':
        return (min: 4.0, max: 6.0, potMin: 5.0, potMax: 7.0);
      default:
        return (min: 1.0, max: 3.0, potMin: 2.0, potMax: 4.0);
    }
  }

  double _rollStat(
    Random rng,
    ({double min, double max, double potMin, double potMax}) range,
  ) {
    return range.min + (rng.nextDouble() * (range.max - range.min));
  }

  double _rollPotential(
    Random rng,
    ({double min, double max, double potMin, double potMax}) range,
  ) {
    return range.potMin + (rng.nextDouble() * (range.potMax - range.potMin));
  }
}
