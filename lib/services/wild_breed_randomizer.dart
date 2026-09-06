// lib/services/wild_creature_randomizer.dart

import 'dart:math';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/stat_system.dart';

class WildCreatureRandomizer {
  final Random _random;

  WildCreatureRandomizer({Random? random}) : _random = random ?? Random();

  /// Prepare a wild (catalog) creature for breeding by giving it random stats
  Creature randomizeWildCreature(
    Creature wild, {
    int? seed,
    bool arcaneBoostUnlocked = false,
  }) {
    // Encounter screens prepare the wild specimen once so any unlocked
    // scanner shows the exact Potential block used by capture or fusion.
    // Never reroll an already-prepared specimen later in the pipeline.
    if (wild.stats != null) return wild;

    final rng = seed != null ? Random(seed) : _random;

    // Preserve the identity already rolled by WildlifeGenerator. Catalog-only
    // scripted encounters still receive fresh Nature slots here.
    final hasPreparedNatures = wild.nature != null || wild.nature2 != null;
    final rarityKey = wild.rarity.toLowerCase();
    final natures = hasPreparedNatures
        ? const <NatureDef>[]
        : NatureCatalogWeighted.rollWildSlots(
            rng,
            elite: rarityKey == 'legendary' || rarityKey == 'mythic',
          );
    final nature = wild.nature ?? (natures.isEmpty ? null : natures.first);
    final nature2 = wild.nature2 ?? (natures.length > 1 ? natures[1] : null);

    // Random genetics (use baseline with slight variation)
    final genetics = _randomizeGenetics(wild.genetics, rng);

    // Random stats (wild creatures have average stats)
    final stats = _generateWildStats(
      wild,
      nature?.id,
      nature2?.id,
      rng,
      arcaneBoostUnlocked: arcaneBoostUnlocked,
    );

    return wild.copyWith(
      nature: nature,
      nature2: nature2,
      genetics: genetics,
      stats: stats,
    );
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
    Creature wild,
    String? natureId,
    String? natureId2,
    Random rng, {
    required bool arcaneBoostUnlocked,
  }) {
    final base =
        wild.baseStats ??
        const SpeciesBaseStats(
          speed: 60,
          intelligence: 60,
          strength: 60,
          beauty: 60,
        );
    final potentials = List<int>.generate(
      4,
      (_) => _rollPotential(rng, boosted: arcaneBoostUnlocked),
    );

    return CreatureStats(
      speed: _derive(base.speed, potentials[0], natureId, natureId2, 'speed'),
      intelligence: _derive(
        base.intelligence,
        potentials[1],
        natureId,
        natureId2,
        'intelligence',
      ),
      strength: _derive(
        base.strength,
        potentials[2],
        natureId,
        natureId2,
        'strength',
      ),
      beauty: _derive(
        base.beauty,
        potentials[3],
        natureId,
        natureId2,
        'beauty',
      ),
      speedPotential: potentials[0].toDouble(),
      intelligencePotential: potentials[1].toDouble(),
      strengthPotential: potentials[2].toDouble(),
      beautyPotential: potentials[3].toDouble(),
    );
  }

  double _derive(
    int base,
    int potential,
    String? natureId,
    String? natureId2,
    String statKey,
  ) => AlchemonStatSystem.effectiveInternal(
    speciesBase: base,
    level: 1,
    potential: potential,
    additionalMultiplier: AlchemonStatSystem.natureMultiplier(
      natureId,
      statKey,
      natureId2,
    ),
  );

  int _rollPotential(Random rng, {required bool boosted}) {
    final first = AlchemonStatSystem.rollPotential(rng);
    if (!boosted) return first;
    return max(first, AlchemonStatSystem.rollPotential(rng));
  }
}
