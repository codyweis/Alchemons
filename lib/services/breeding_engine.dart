import 'dart:math';
import '../models/creature.dart';
import 'creature_repository.dart';

class BreedingResult {
  final Creature? creature;
  final Creature? variantUnlocked;
  final bool success;

  BreedingResult({this.creature, this.variantUnlocked, this.success = true});

  BreedingResult.failure()
    : creature = null,
      variantUnlocked = null,
      success = false;
}

class BreedingEngine {
  final CreatureRepository repository;
  final Random _random = Random();

  BreedingEngine(this.repository);

  BreedingResult breed(String parent1Id, String parent2Id) {
    final parent1 = repository.getCreatureById(parent1Id);
    final parent2 = repository.getCreatureById(parent2Id);

    if (parent1 == null || parent2 == null) return BreedingResult.failure();

    // 1️⃣ Mutation check → takes precedence
    if (_rollMutationChance(parent1, parent2)) {
      final mutationResult = _pickMutationFromFamily(parent1, parent2);
      if (mutationResult != null) {
        return BreedingResult(
          creature: mutationResult,
        ); // mutation overrides everything else
      }
    }

    final weightedPool = <Creature>[];

    // 2️⃣ Special breeding → add based on hybrid odds
    for (final creature in repository.creatures) {
      final special = creature.specialBreeding;
      if (special != null && special.requiredParents.isNotEmpty) {
        for (final pair in special.requiredParents) {
          if (_matchesPair(pair, [parent1.id, parent2.id])) {
            final odds = creature.breeding.odds;
            weightedPool.addAll(List.filled(odds['hybrid'], creature));
          }
        }
      }
    }

    // 3️⃣ Guaranteed breeding → instant return
    for (final creature in repository.creatures) {
      if (creature.guaranteedBreeding != null) {
        for (final pair in creature.guaranteedBreeding!) {
          if (_matchesPair(pair, [parent1.types.first, parent2.types.first])) {
            return BreedingResult(creature: creature);
          }
        }
      }
    }

    // 4️⃣ Normal breeding
    for (final c in repository.creatures) {
      // Skip non-matching special breeding
      if (c.specialBreeding != null &&
          c.specialBreeding!.requiredParents.isNotEmpty) {
        bool specialMatch = false;
        for (final pair in c.specialBreeding!.requiredParents) {
          if (_matchesPair(pair, [parent1.id, parent2.id])) {
            specialMatch = true;
            break;
          }
        }
        if (!specialMatch) continue;
      }

      if (c.breeding.parents.any(
        (p) => _matchesPair(p, [parent1.types.first, parent2.types.first]),
      )) {
        final odds = c.breeding.odds;
        weightedPool.addAll(List.filled(odds['hybrid'], c));

        if (parent1.types.first == c.types.first ||
            parent2.types.first == c.types.first) {
          weightedPool.addAll(List.filled(odds['parent1'], c));
          weightedPool.addAll(List.filled(odds['parent2'], c));
        }
      }
    }

    // 5️⃣ Always add parents themselves
    weightedPool.addAll(
      List.filled(parent1.breeding.odds['parent1'] ?? 0, parent1),
    );
    weightedPool.addAll(
      List.filled(parent2.breeding.odds['parent2'] ?? 0, parent2),
    );

    // 6️⃣ Apply rarity boost
    _applyRarityBoost(weightedPool, parent1.rarity, parent2.rarity);

    // 7️⃣ Pick from pool
    Creature? offspring;
    if (weightedPool.isEmpty) {
      offspring = _random.nextBool() ? parent1 : parent2;
    } else {
      offspring = weightedPool[_random.nextInt(weightedPool.length)];
    }

    // 8️⃣ NEW: Check for variant ONLY if result is a parent
    if (_isParentResult(offspring, parent1, parent2)) {
      final variant = _checkVariantUnlock(offspring, parent1, parent2);
      if (variant != null) {
        return BreedingResult(creature: offspring, variantUnlocked: variant);
      }
    }

    return BreedingResult(creature: offspring);
  }

  // ------------------ New Variant Methods ------------------

  bool _isParentResult(Creature offspring, Creature parent1, Creature parent2) {
    return offspring.id == parent1.id || offspring.id == parent2.id;
  }

  Creature? _checkVariantUnlock(
    Creature resultParent,
    Creature parent1,
    Creature parent2,
  ) {
    // Get the OTHER parent (the one that didn't get selected as result)
    final otherParent = resultParent.id == parent1.id ? parent2 : parent1;

    // Check if we can create a variant with these types
    final baseType = resultParent.types.first;
    final secondaryType = otherParent.types.first;

    // Excluded types that can't be variants
    const excludedTypes = {
      'Shadow',
      'Light',
      'Blood',
      'Dream',
      'Arcane',
      'Chaos',
      'Time',
      'Void',
      'Ascended',
    };

    if (excludedTypes.contains(baseType) ||
        excludedTypes.contains(secondaryType)) {
      return null;
    }

    // Don't create variant if types are the same
    if (baseType == secondaryType) {
      return null;
    }

    // Check variant unlock chance (25% base chance)
    if (_random.nextInt(100) < 25) {
      return _createVariant(resultParent, secondaryType);
    }

    return null;
  }

  Creature _createVariant(Creature baseCreature, String secondaryType) {
    return Creature.variant(
      baseId: baseCreature.id,
      baseName: baseCreature.name,
      primaryType: baseCreature.types.first,
      secondaryType: secondaryType,
      baseImage: baseCreature.image,
    );
  }

  // ------------------ Original Helper Methods (unchanged) ------------------

  bool _rollMutationChance(Creature p1, Creature p2) {
    // must share the same mutation family
    if (p1.mutationFamily == null || p1.mutationFamily != p2.mutationFamily) {
      return false;
    }

    int m1 = p1.breeding.odds['mutation'] ?? 0;
    int m2 = p2.breeding.odds['mutation'] ?? 0;
    int totalChance = max(m1, m2); // you could average them instead
    return _random.nextInt(100) < totalChance;
  }

  Creature? _pickMutationFromFamily(Creature p1, Creature p2) {
    // must share the same family
    final family = p1.mutationFamily;
    if (family == null || family != p2.mutationFamily) return null;

    // pick a random creature from that family (excluding parents)
    final familyMembers = repository.creatures
        .where((c) => c.mutationFamily == family)
        .where((c) => c.id != p1.id && c.id != p2.id)
        .toList();

    if (familyMembers.isEmpty) return null;

    return familyMembers[_random.nextInt(familyMembers.length)];
  }

  void _applyRarityBoost(List<Creature> pool, String r1, String r2) {
    final boostTable = {"Common": 0, "Uncommon": 3, "Rare": 6, "Mythic": 12};

    if (r1 == r2) {
      final boost = boostTable[r1] ?? 0;
      if (boost > 0) {
        final boosted = pool
            .where((c) => _isHigherOrEqualRarity(c.rarity, r1))
            .toList();
        for (final c in boosted) {
          pool.addAll(List.filled(boost, c));
        }
      }
    }
  }

  bool _isHigherOrEqualRarity(String rarity, String compareTo) {
    const order = ["Common", "Uncommon", "Rare", "Mythic"];
    return order.indexOf(rarity) >= order.indexOf(compareTo);
  }

  bool _matchesPair(List<String> pair, List<String> attempt) {
    if (pair.isEmpty) return false;
    if (pair.length == 1) return attempt.contains(pair.first);
    return (pair[0] == attempt[0] && pair[1] == attempt[1]) ||
        (pair[0] == attempt[1] && pair[1] == attempt[0]);
  }
}
