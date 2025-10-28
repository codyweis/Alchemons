// lib/services/breeding_engine.dart
//
// BreedingEngine
// Flow:
//   0. global mutation (1% rarity bump + fused element)
//   1. guaranteed pair
//   2. same-species clone
//   3. hybrid:
//        3a. roll family (biased toward less-rare parent)
//        3b. roll element (penalize fusion if cross-family + no recipe)
//        3c. pick catalog creature for (family, element)
//      if none ->
//   4. forced parent fallback (must succeed)
//
// Analyzer support:
//   getFamilyDistribution / getElementDistribution / etc give deterministic
//   weight maps so UI can show “% chance this happened”.
//
// Depends on:
//   CreatureRepository, ElementRecipeConfig, FamilyRecipeConfig,
//   SpecialRulesConfig, BreedingTuning, GeneticsCatalog, NatureCatalog.
//

import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/nature_utils.dart';

// ───────────────────────────────────────────────────────────
// 1. Generic weighted distribution helper (used by analyzer)
// ───────────────────────────────────────────────────────────

class OutcomeDistribution<T> {
  final Map<T, double> weights; // unnormalized weights

  OutcomeDistribution(this.weights);

  Map<T, double> asPercentages() {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return weights.map((k, v) => MapEntry(k, 0.0));
    }
    return weights.map((k, v) => MapEntry(k, (v / total) * 100.0));
  }

  T sample(Random rng) {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    var roll = rng.nextDouble() * total;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return weights.keys.first; // should never really hit unless weights empty
  }
}

// tint bias table from original engine for tint genetics
const Map<String, Map<String, double>> tintBiasPerType = {
  'Fire': {'warm': 1.30, 'vibrant': 1.15, 'pale': 0.90, 'cool': 0.60},
  'Water': {'cool': 1.30, 'pale': 1.15, 'vibrant': 1.05, 'warm': 0.60},
  'Earth': {'pale': 1.20, 'warm': 1.05, 'vibrant': 0.95},
  'Air': {'pale': 1.15, 'cool': 1.10},
  'Lightning': {'vibrant': 1.25, 'warm': 1.10},
  'Ice': {'cool': 1.3, 'pale': 1.10, 'warm': 0.50},
  'Lava': {'warm': 1.50, 'vibrant': 1.15, 'cool': 0.50, 'pale': 0.90},
  'Steam': {'pale': 1.15, 'cool': 1.10, 'warm': 1.05},
  'Mud': {'pale': 1.20, 'vibrant': 0.70},
  'Dust': {'pale': 1.30, 'vibrant': 0.95},
  'Crystal': {'vibrant': 1.30, 'cool': 1.10, 'pale': 1.05},
  'Plant': {'vibrant': 1.15, 'pale': 1.05},
  'Poison': {'cool': 1.10, 'pale': 1.10},
  'Spirit': {'pale': 1.15, 'vibrant': 1.10},
  'Dark': {'cool': 1.15, 'pale': 1.30, 'warm': 0.80},
  'Light': {'vibrant': 1.50, 'pale': 1.10},
  'Blood': {'warm': 1.25, 'vibrant': 1.10, 'cool': 0.90},
};

// ───────────────────────────────────────────────────────────
// 2. Breeding result wrappers
// ───────────────────────────────────────────────────────────

class BreedingResult {
  final Creature? creature;
  final Creature? variantUnlocked; // optional UX unlock for cross-variant
  final bool success;
  BreedingResult({this.creature, this.variantUnlocked, this.success = true});
  BreedingResult.failure()
    : creature = null,
      variantUnlocked = null,
      success = false;
}

class BreedingResultWithStats {
  final Creature creature;
  final CreatureStats stats;
  BreedingResultWithStats({required this.creature, required this.stats});
}

// ───────────────────────────────────────────────────────────
// 3. Engine
// ───────────────────────────────────────────────────────────

class BreedingEngine {
  final CreatureRepository repository;
  final ElementRecipeConfig elementRecipes;
  final FamilyRecipeConfig familyRecipes;
  final SpecialRulesConfig specialRules;
  final BreedingTuning tuning;
  final Random _random;
  final bool logToConsole;

  BreedingEngine(
    this.repository, {
    required this.elementRecipes,
    required this.familyRecipes,
    required this.specialRules,
    this.tuning = const BreedingTuning(),
    this.logToConsole = false,
    Random? random,
  }) : _random = random ?? Random();

  static const _rarityOrder = ["Common", "Uncommon", "Rare", "Mythic"];

  // ─────────────────────────────────────
  // 3A. Public API entrypoints
  // ─────────────────────────────────────

  BreedingResult breed(String parent1Id, String parent2Id) {
    _log('[Breeding] === BREED START (IDs) ===');

    final p1 = repository.getCreatureById(parent1Id);
    final p2 = repository.getCreatureById(parent2Id);
    if (p1 == null || p2 == null) return BreedingResult.failure();

    return _breedCore(
      p1,
      p2,
      parentA: ParentSnapshot.fromCreature(p1),
      parentB: ParentSnapshot.fromCreature(p2),
    );
  }

  BreedingResult breedInstances(db.CreatureInstance a, db.CreatureInstance b) {
    _log('[Breeding] === BREED START (INSTANCES) ===');

    final base1 = repository.getCreatureById(a.baseId);
    final base2 = repository.getCreatureById(b.baseId);
    if (base1 == null || base2 == null) return BreedingResult.failure();

    final g1 = decodeGenetics(a.geneticsJson);
    final g2 = decodeGenetics(b.geneticsJson);

    final p1 = base1.copyWith(
      genetics: g1 ?? base1.genetics,
      nature: (a.natureId != null)
          ? NatureCatalog.byId(a.natureId!)
          : base1.nature,
      isPrismaticSkin: a.isPrismaticSkin || (base1.isPrismaticSkin),
    );

    final p2 = base2.copyWith(
      genetics: g2 ?? base2.genetics,
      nature: (b.natureId != null)
          ? NatureCatalog.byId(b.natureId!)
          : base2.nature,
      isPrismaticSkin: b.isPrismaticSkin || (base2.isPrismaticSkin),
    );

    final snapA = ParentSnapshotFactory.fromDbInstance(a, repository);
    final snapB = ParentSnapshotFactory.fromDbInstance(b, repository);

    return _breedCore(p1, p2, parentA: snapA, parentB: snapB);
  }

  // ─────────────────────────────────────
  // 3B. Core pipeline
  // ─────────────────────────────────────

  BreedingResult _breedCore(
    Creature p1,
    Creature p2, {
    required ParentSnapshot parentA,
    required ParentSnapshot parentB,
  }) {
    final fam1 = _familyOf(p1);
    final fam2 = _familyOf(p2);

    _log('[Breeding] parents: ${p1.id} × ${p2.id}');
    _log(
      '[Breeding] P1: ${p1.id} • ${p1.name} • ${p1.types.first} • ${p1.rarity} • fam=$fam1',
    );
    _log(
      '[Breeding] P2: ${p2.id} • ${p2.name} • ${p2.types.first} • ${p2.rarity} • fam=$fam2',
    );

    // STEP 0: 1% global mutation (rarity bump + fused element)
    if (_roll(tuning.globalMutationChance)) {
      final mutatedBase = _tryGlobalMutation(p1, p2);
      if (mutatedBase != null) {
        _log('[Breeding] Step0: global mutation hit → ${mutatedBase.id}');
        final mutatedFinal = _finalizeChild(
          mutatedBase,
          p1,
          p2,
          parentA: parentA,
          parentB: parentB,
        );
        _log(
          '[Breeding] RESULT (mutated): ${mutatedFinal.id} • ${mutatedFinal.name}',
        );
        _log('[Breeding] === BREED END ===');
        return BreedingResult(creature: mutatedFinal);
      }
      _log('[Breeding] Step0: global mutation rolled but no candidate found.');
    } else {
      _log('[Breeding] Step0: global mutation did not roll.');
    }

    // STEP 1: guaranteed pair overrides (designer auth)
    final gk = SpecialRulesConfig.idKey(p1.id, p2.id);
    final outs = specialRules.guaranteedPairs[gk];
    if (outs != null && outs.isNotEmpty) {
      for (final rule in outs) {
        if (_roll(rule.chance)) {
          final fixed = repository.getCreatureById(rule.resultId);
          if (fixed != null && _passesRequiredTypes(fixed, p1, p2)) {
            _log('[Breeding] Step1: guaranteed-pair hit → ${fixed.id}');
            final fixedChild = _finalizeChild(
              fixed,
              p1,
              p2,
              parentA: parentA,
              parentB: parentB,
            );
            _log(
              '[Breeding] RESULT (guaranteed): ${fixedChild.id} • ${fixedChild.name}',
            );
            _log('[Breeding] === BREED END ===');
            return BreedingResult(creature: fixedChild);
          }
        }
      }
      _log('[Breeding] Step1: guaranteed-pair rules present but no hit.');
    } else {
      _log('[Breeding] Step1: no guaranteed-pair rules.');
    }

    // STEP 2: same-species cloning (pure line)
    if (p1.id == p2.id) {
      _log('[Breeding] Step2: same-species → ${p1.id}');
      final pure = _finalizeChild(
        p1,
        p1,
        p2,
        parentA: parentA,
        parentB: parentB,
      );
      _log('[Breeding] RESULT (pure): ${pure.id} • ${pure.name}');
      _log('[Breeding] === BREED END ===');
      return BreedingResult(creature: pure);
    }

    // STEP 3: hybridization path

    // STEP 3a. roll family using biased distribution
    var famDist = getBiasedFamilyDistribution(p1, p2);
    final childFamily = famDist.sample(_random);
    _log('[Breeding] Step3a: child family roll (biased+nature) = $childFamily');

    // STEP 3b. roll element using biased distribution
    var elemDist = getBiasedElementDistribution(p1, p2);
    final childElement = elemDist.sample(_random);
    _log(
      '[Breeding] Step3b: child element roll (biased+nature) = $childElement',
    );

    // 3c. pick catalog creature with (family, element)
    final pool = repository.creatures.where((c) {
      if (_familyOf(c) != childFamily) return false;
      if (c.types.isEmpty || c.types.first != childElement) return false;
      return true; // allow parents themselves here
    }).toList();

    _log(
      '[Breeding] Step3c: pool size for (fam=$childFamily, elem=$childElement) = ${pool.length}.',
    );

    if (pool.isNotEmpty) {
      final higherParentRarity = _higherRarity(p1.rarity, p2.rarity);

      // prefer rarity close to parents
      final pref = pool
          .where((c) => _withinOneRarity(higherParentRarity, c.rarity))
          .toList();
      final sel = pref.isNotEmpty ? pref : pool;

      // bias toward either parent's family
      final biased = <Creature>[];
      for (final c in sel) {
        final bias = (c.mutationFamily == fam1 || c.mutationFamily == fam2)
            ? 3
            : 1;
        for (int i = 0; i < bias; i++) {
          biased.add(c);
        }
      }

      final pickList = biased.isNotEmpty ? biased : sel;
      final idx = _random.nextInt(pickList.length);
      final offspringBase = pickList[idx];

      _log(
        '[Breeding] Step3c: picked offspring ${offspringBase.id} (${offspringBase.name}).',
      );

      final finalized = _finalizeChild(
        offspringBase,
        p1,
        p2,
        parentA: parentA,
        parentB: parentB,
      );

      _log(
        '[Breeding] RESULT (hybrid): ${finalized.id} • ${finalized.name} • fam=${_familyOf(finalized)} • ${finalized.types.first} • ${finalized.rarity}',
      );
      _log('[Breeding] === BREED END ===');
      return BreedingResult(creature: finalized);
    }

    _log(
      '[Breeding] Step3c: no valid hybrid species found for ($childFamily,$childElement).',
    );

    // STEP 4: forced parent fallback (must succeed)
    final fallbackBase = _random.nextBool() ? p1 : p2;
    _log(
      '[Breeding] Step4: forced parent fallback → ${fallbackBase.id} (${fallbackBase.name})',
    );

    final fallbackFinal = _finalizeChild(
      fallbackBase,
      p1,
      p2,
      parentA: parentA,
      parentB: parentB,
    );

    _log(
      '[Breeding] RESULT (forced-parent): ${fallbackFinal.id} • ${fallbackFinal.name} • fam=${_familyOf(fallbackFinal)} • ${fallbackFinal.types.first} • ${fallbackFinal.rarity}',
    );
    _log('[Breeding] === BREED END ===');

    return BreedingResult(creature: fallbackFinal);
  }

  // ─────────────────────────────────────
  // 3C. Pipeline substeps / bias helpers
  // ─────────────────────────────────────

  Creature? _tryGlobalMutation(Creature p1, Creature p2) {
    // choose next rarity tier above higher parent, but never into Mythic+
    String nextRarity(String rarity) {
      const tiers = [
        'Common',
        'Uncommon',
        'Rare',
        'Epic',
        'Legendary',
        'Mythic',
      ];
      final i = tiers.indexOf(rarity);

      // If already Legendary/Mythic tier or unknown, don't escalate further
      if (i < 0 || i >= tiers.length - 2) return rarity;

      return tiers[i + 1];
    }

    final parentTopRarity = [
      p1.rarity,
      p2.rarity,
    ].reduce((a, b) => _rarityRank(a) >= _rarityRank(b) ? a : b);
    final targetRarity = nextRarity(parentTopRarity);

    // collect candidate elements = parents' primaries + fusion outputs
    final elem1 = p1.types.isNotEmpty ? p1.types.first : null;
    final elem2 = p2.types.isNotEmpty ? p2.types.first : null;
    if (elem1 == null && elem2 == null) return null;

    final elementSet = <String>{};
    if (elem1 != null) elementSet.add(elem1);
    if (elem2 != null) elementSet.add(elem2);

    final fusionKey = ElementRecipeConfig.keyOf(elem1 ?? '', elem2 ?? '');
    final fusionRecipe = elementRecipes.recipes[fusionKey];
    if (fusionRecipe != null) {
      elementSet.addAll(fusionRecipe.keys);
    }

    // choose any species in repo that matches target rarity + allowed element
    final candidates = repository.creatures.where((c) {
      final primary = c.types.isNotEmpty ? c.types.first : null;
      if (primary == null) return false;
      return elementSet.contains(primary) && c.rarity == targetRarity;
    }).toList();

    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  OutcomeDistribution<String> _biasFamilyTowardLessRareParent(
    OutcomeDistribution<String> base,
    Creature p1,
    Creature p2,
  ) {
    final fam1 = _familyOf(p1);
    final fam2 = _familyOf(p2);
    if (fam1 == fam2) return base;

    final r1 = _rarityRank(p1.rarity);
    final r2 = _rarityRank(p2.rarity);

    // lower rank = more common / less rare
    final lessRareFamily = (r1 <= r2) ? fam1 : fam2;

    final newWeights = Map<String, double>.from(base.weights);
    final biasMult = tuning.familyBiasPenalty;
    if (newWeights.containsKey(lessRareFamily)) {
      newWeights[lessRareFamily] = newWeights[lessRareFamily]! * biasMult;
    }

    return OutcomeDistribution<String>(newWeights);
  }

  OutcomeDistribution<String> _biasElementForCrossFamilyPenalty(
    OutcomeDistribution<String> base,
    Creature p1,
    Creature p2,
  ) {
    final fam1 = _familyOf(p1);
    final fam2 = _familyOf(p2);

    final sameFamily = fam1 == fam2;
    final hasRecipe = _hasFamilyRecipe(fam1, fam2);

    // If they share a family OR we explicitly authored this family combo,
    // treat elemental fusion odds as "best case". No penalty.
    if (sameFamily || hasRecipe) {
      return base;
    }

    // Cross-family + no explicit family recipe = awkward fusion.
    final t1 = p1.types.isNotEmpty ? p1.types.first : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first : null;
    if (t1 == null || t2 == null) return base;

    final fusionKey = ElementRecipeConfig.keyOf(t1, t2);
    final fusionRecipe = elementRecipes.recipes[fusionKey];
    if (fusionRecipe == null || fusionRecipe.isEmpty) return base;

    // Fusion outcomes = things that are not literally parent types.
    final fusionOutcomes = fusionRecipe.keys
        .where((elem) => elem != t1 && elem != t2)
        .toSet();
    if (fusionOutcomes.isEmpty) return base;

    // Apply penalty to those third elements (Steam, Lava, etc.)
    final penaltyMult = tuning.elementalBiasPenalty;
    final newWeights = Map<String, double>.from(base.weights);

    for (final elem in fusionOutcomes) {
      if (newWeights.containsKey(elem)) {
        newWeights[elem] = newWeights[elem]! * penaltyMult;
      }
    }

    return OutcomeDistribution<String>(newWeights);
  }

  bool _hasFamilyRecipe(String famA, String famB) {
    final key = FamilyRecipeConfig.keyOf(famA, famB);
    final recipe = familyRecipes.recipes[key];
    return recipe != null && recipe.isNotEmpty;
  }

  // ─────────────────────────────────────
  // 3D. Finalization (genetics, nature, stats, etc.)
  // ─────────────────────────────────────

  Creature _finalizeChild(
    Creature base,
    Creature p1,
    Creature p2, {
    required ParentSnapshot parentA,
    required ParentSnapshot parentB,
  }) {
    var child = base;

    // Genetics
    child = _applyGenetics(child, p1, p2);

    // Nature
    final NatureDef? n = _chooseChildNature(p1, p2);
    if (n != null) child = child.copyWith(nature: n);

    // Cosmetic: prismatic
    if (_random.nextDouble() < tuning.prismaticSkinChance) {
      _log('[Breeding] StepN: prismatic skin applied to offspring.');
      child = child.copyWith(isPrismaticSkin: true);
    }

    // Parent snapshot + timestamp
    final parentage = Parentage(
      parentA: parentA,
      parentB: parentB,
      bredAt: DateTime.now(),
    );
    child = child.copyWith(parentage: parentage);

    // Stats inheritance/blend
    final childStats = _generateChildStats(
      parentA,
      parentB,
      child.nature,
      child.genetics,
    );
    child = child.copyWith(stats: childStats);

    return child;
  }

  CreatureStats _generateChildStats(
    ParentSnapshot parentA,
    ParentSnapshot parentB,
    NatureDef? childNature,
    Genetics? childGenetics,
  ) {
    final statsA = parentA.stats;
    final statsB = parentB.stats;

    CreatureStats childStats;
    if (statsA != null && statsB != null) {
      childStats = CreatureStats.breed(
        statsA,
        statsB,
        _random,
        mutationChance: 0.15,
        mutationStrength: 1.0,
      );
      _log('[Breeding] Stats inherited from parents with blending');
    } else if (statsA != null) {
      childStats = CreatureStats.breed(
        statsA,
        CreatureStats.generate(_random),
        _random,
        mutationChance: 0.20,
        mutationStrength: 1.2,
      );
      _log('[Breeding] Stats partially inherited from parent A');
    } else if (statsB != null) {
      childStats = CreatureStats.breed(
        CreatureStats.generate(_random),
        statsB,
        _random,
        mutationChance: 0.20,
        mutationStrength: 1.2,
      );
      _log('[Breeding] Stats partially inherited from parent B');
    } else {
      childStats = CreatureStats.generate(_random);
      _log('[Breeding] Stats freshly generated');
    }

    // Apply nature / genetics modifiers
    childStats = childStats.applyNature(childNature?.id);
    childStats = childStats.applyGenetics(childGenetics);

    _log(
      '[Breeding] Final stats: '
      'Speed=${childStats.speed.toStringAsFixed(1)}, '
      'Int=${childStats.intelligence.toStringAsFixed(1)}, '
      'Str=${childStats.strength.toStringAsFixed(1)}, '
      'Beauty=${childStats.beauty.toStringAsFixed(1)}',
    );

    return childStats;
  }

  // ─────────────────────────────────────
  // 3E. Nature + Genetics inheritance details
  // ─────────────────────────────────────

  NatureDef? _chooseChildNature(Creature p1, Creature p2) {
    final rng = _random;
    final inheritChance = tuning.inheritNatureChance; // e.g. 60
    final sameLockInChance = tuning.sameNatureLockInChance; // e.g. 50

    final parents = [p1.nature, p2.nature].whereType<NatureDef>().toList();
    if (NatureCatalog.all.isEmpty) return null;

    if (parents.isEmpty) {
      return NatureCatalogWeighted.weightedRandom(rng);
    }

    if (parents.length == 2 && parents[0].id == parents[1].id) {
      if (rng.nextInt(100) < sameLockInChance) {
        return parents[0];
      }
    }

    if (rng.nextInt(100) < inheritChance) {
      return NatureCatalogWeighted.weightedFromPool(parents, rng);
    }

    return NatureCatalogWeighted.weightedRandom(rng);
  }

  Creature _applyGenetics(Creature child, Creature p1, Creature p2) {
    final rng = _random;
    final Map<String, String> chosen = {};

    for (final track in GeneticsCatalog.all) {
      final p1VarId = p1.genetics?.get(track.key) ?? _defaultVariant(track);
      final p2VarId = p2.genetics?.get(track.key) ?? _defaultVariant(track);
      final p1Var = track.byId(p1VarId);
      final p2Var = track.byId(p2VarId);

      final didMutate = rng.nextDouble() < track.mutationChance;

      String resultId;
      switch (track.inheritance) {
        case 'blended':
          // (size-like gene)
          final s1 = (p1Var.effect['scale'] ?? 1.0).toDouble();
          final s2 = (p2Var.effect['scale'] ?? 1.0).toDouble();
          final avg = (s1 + s2) / 2.0 + _noise(rng, 0.0, 0.05);

          resultId = _nearestBy(
            track,
            value: avg,
            read: (v) => (v.effect['scale'] ?? 1.0).toDouble(),
          ).id;

          if (didMutate) {
            resultId = _adjacentSnap(track, resultId, rng);
          }

          final bothGiant = (p1Var.id == 'giant' && p2Var.id == 'giant');
          final bothTiny = (p1Var.id == 'tiny' && p2Var.id == 'tiny');

          if (bothGiant) {
            if (rng.nextDouble() < 0.70) {
              resultId = 'giant';
            } else if (rng.nextDouble() < 0.20) {
              resultId = _snapTowardCenter(track, resultId);
            }
          } else if (bothTiny) {
            if (rng.nextDouble() < 0.60) {
              resultId = 'tiny';
            } else if (rng.nextDouble() < 0.20) {
              resultId = _snapTowardCenter(track, resultId);
            }
          }
          break;

        case 'weighted':
          // tinting / patterning / etc
          final bothSame = p1Var.id == p2Var.id;
          final stick = bothSame && rng.nextDouble() < 0.70;

          if (track.key == 'tinting') {
            final baseDom = <String, int>{
              for (final v in track.variants) v.id: v.dominance,
            };

            Map<String, double> biasedDoubles = _applyTintBiasInternal(
              baseDom: baseDom.map((k, v) => MapEntry(k, v.toDouble())),
              p1Types: p1.types,
              p2Types: p2.types,
            );

            String prelim = stick
                ? p1Var.id
                : _weightedPickFromMap(biasedDoubles, rng);

            if (didMutate) {
              final pool = track.variants
                  .where((v) => v.id != 'normal' && v.id != 'albino')
                  .toList();
              if (pool.isNotEmpty) {
                prelim = pool[rng.nextInt(pool.length)].id;
              }
            }

            resultId = prelim;
          } else if (track.key == 'patterning') {
            resultId = _inheritPatterning(
              track,
              p1Var,
              p2Var,
              rng,
              didMutate: didMutate,
            );
          } else {
            String prelim = stick
                ? p1Var.id
                : _weightedPickByDominance(track, rng).id;

            if (didMutate) {
              final pool = track.variants
                  .where((v) => v.id != 'normal')
                  .toList();
              if (pool.isNotEmpty) {
                prelim = pool[rng.nextInt(pool.length)].id;
              }
            }

            resultId = prelim;
          }
          break;

        case 'dominant_recessive':
        default:
          resultId = _dominantPick(p1Var, p2Var, rng).id;
          break;
      }

      chosen[track.key] = resultId;
    }

    return child.copyWith(genetics: Genetics(chosen));
  }

  String _inheritPatterning(
    GeneTrack track,
    GeneVariant p1Var,
    GeneVariant p2Var,
    Random rng, {
    required bool didMutate,
  }) {
    if (p1Var.id == p2Var.id && rng.nextDouble() < 0.70) {
      return p1Var.id;
    }

    final pair = {p1Var.id, p2Var.id};
    if (pair.contains('spots') && pair.contains('stripes')) {
      if (rng.nextDouble() < 0.15) return 'checkered';
    }

    String picked = _weightedPickByDominance(track, rng).id;

    if (didMutate) {
      final pool = track.variants
          .map((v) => v.id)
          .where((id) => id != p1Var.id && id != p2Var.id)
          .toList();
      if (pool.isNotEmpty) {
        if (pool.contains('checkered') && rng.nextDouble() < 0.40) {
          picked = 'checkered';
        } else {
          picked = pool[rng.nextInt(pool.length)];
        }
      }
    }

    return picked;
  }

  // ─────────────────────────────────────
  // 3F. Analyzer-facing deterministic distributions
  // ─────────────────────────────────────

  OutcomeDistribution<String> getFamilyDistribution(Creature p1, Creature p2) {
    final fam1 = _familyOf(p1);
    final fam2 = _familyOf(p2);

    if (fam1 == fam2) {
      final mutationPct = tuning.sameFamilyMutationChancePct.toDouble(); // ~1%
      final stickPct = 100.0 - mutationPct;

      final otherFamilies = repository.creatures
          .map((c) => _familyOf(c))
          .where((f) => f != 'Unknown' && f != fam1)
          .toSet()
          .toList();

      if (otherFamilies.isEmpty) {
        return OutcomeDistribution<String>({fam1: 100.0});
      }

      final perAlt = mutationPct / otherFamilies.length;
      final map = <String, double>{fam1: stickPct};
      for (final fam in otherFamilies) {
        map[fam] = perAlt;
      }
      return OutcomeDistribution<String>(map);
    }

    final key = FamilyRecipeConfig.keyOf(fam1, fam2);
    final recipe = familyRecipes.recipes[key];

    if (recipe != null && recipe.isNotEmpty) {
      return OutcomeDistribution<String>(
        recipe.map((k, v) => MapEntry(k, v.toDouble())),
      );
    }

    // no authored mix, default to 50/50
    return OutcomeDistribution<String>({fam1: 50.0, fam2: 50.0});
  }

  OutcomeDistribution<String> getElementDistribution(Creature p1, Creature p2) {
    final t1 = p1.types.isNotEmpty ? p1.types.first.trim() : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first.trim() : null;

    // super defensive
    if (t1 == null && t2 == null) {
      return OutcomeDistribution<String>({});
    }
    if (t1 != null && t2 == null) {
      return OutcomeDistribution<String>({t1: 100.0});
    }
    if (t2 != null && t1 == null) {
      return OutcomeDistribution<String>({t2: 100.0});
    }

    final a = t1!;
    final b = t2!;
    final key = ElementRecipeConfig.keyOf(a, b);

    // 1. try explicit fusion rule like "Air+Water" -> {Ice:70, Air:15, Water:15}
    Map<String, int>? weighted = elementRecipes.recipes[key];

    // 2. if no explicit pair rule:
    //    build a symmetric fallback from BOTH parents instead of favoring just `a`.
    if (weighted == null) {
      // grab each parent's self map ("Air": {"Air":100}, "Steam":{"Steam":100})
      final soloA = elementRecipes.recipes[a];
      final soloB = elementRecipes.recipes[b];

      if (soloA != null && soloB != null) {
        // merge them 50/50
        // soloA like {Air:100}, soloB like {Steam:100}
        final merged = <String, double>{};

        // add A's keys scaled by 0.5
        soloA.forEach((elem, w) {
          merged[elem] = (merged[elem] ?? 0) + (w.toDouble() * 0.5);
        });
        // add B's keys scaled by 0.5
        soloB.forEach((elem, w) {
          merged[elem] = (merged[elem] ?? 0) + (w.toDouble() * 0.5);
        });

        // convert back to ints-ish (not super important, analyzer normalizes anyway)
        final mergedInt = <String, int>{};
        merged.forEach((elem, w) {
          mergedInt[elem] = w.round();
        });

        weighted = mergedInt;
      }
    }

    // 3. final absolute fallback: if we STILL didn't get anything,
    //    just do {a:50, b:50}.
    weighted ??= {a: 50, b: 50};

    // 4. apply any elemental nature biasing (this is the original hook
    //    that leaned toward parents' primary element BEFORE homotypic/heterotypic)
    final biased = applyTypeNatureBias(Map<String, int>.from(weighted), p1, p2);

    // 5. wrap
    return OutcomeDistribution<String>(
      biased.map((elem, w) => MapEntry(elem, w.toDouble())),
    );
  }

  OutcomeDistribution<String> getSizeDistribution(Creature p1, Creature p2) {
    final track = GeneticsCatalog.all.firstWhere(
      (t) => t.key == 'size',
      orElse: () => GeneticsCatalog.all.first,
    );

    final mutationChance = track.mutationChance;
    final inheritChance = 1.0 - mutationChance;

    final p1VarId = p1.genetics?.get('size') ?? _defaultVariant(track);
    final p2VarId = p2.genetics?.get('size') ?? _defaultVariant(track);
    final p1Var = track.byId(p1VarId);
    final p2Var = track.byId(p2VarId);

    final inheritWeights = <String, double>{};
    void bumpInherit(String id, double w) {
      inheritWeights[id] = (inheritWeights[id] ?? 0) + w;
    }

    final bothGiant = (p1Var.id == 'giant' && p2Var.id == 'giant');
    final bothTiny = (p1Var.id == 'tiny' && p2Var.id == 'tiny');

    if (bothGiant) {
      bumpInherit('giant', 0.70);
      bumpInherit('normal', 0.20);
      bumpInherit('large', 0.10);
    } else if (bothTiny) {
      bumpInherit('tiny', 0.60);
      bumpInherit('normal', 0.30);
      bumpInherit('small', 0.10);
    } else {
      bumpInherit(p1Var.id, 0.35);
      bumpInherit(p2Var.id, 0.35);
      bumpInherit('normal', 0.50);
    }

    final mutationWeights = <String, double>{};
    for (final v in track.variants) {
      if (v.id == 'normal') continue;
      mutationWeights[v.id] = 1.0;
    }

    Map<String, double> _normalize(Map<String, double> src) {
      final total = src.values.fold<double>(0, (a, b) => a + b);
      if (total <= 0) {
        return src.map((k, v) => MapEntry(k, 0.0));
      }
      return src.map((k, v) => MapEntry(k, v / total));
    }

    final normInherit = _normalize(inheritWeights);
    final normMut = _normalize(mutationWeights);

    final blended = <String, double>{};
    final allKeys = {...normInherit.keys, ...normMut.keys};
    for (final id in allKeys) {
      final iW = normInherit[id] ?? 0.0;
      final mW = normMut[id] ?? 0.0;
      blended[id] = (inheritChance * iW) + (mutationChance * mW);
    }

    return OutcomeDistribution<String>(blended);
  }

  OutcomeDistribution<String> getPatternDistribution(Creature p1, Creature p2) {
    final track = GeneticsCatalog.all.firstWhere(
      (t) => t.key == 'patterning',
      orElse: () => GeneticsCatalog.all.first,
    );

    final p1VarId = p1.genetics?.get('patterning') ?? _defaultVariant(track);
    final p2VarId = p2.genetics?.get('patterning') ?? _defaultVariant(track);

    final p1Var = track.byId(p1VarId);
    final p2Var = track.byId(p2VarId);

    final weights = <String, double>{};
    void bump(String id, double w) {
      weights[id] = (weights[id] ?? 0) + w;
    }

    if (p1Var.id == p2Var.id) {
      bump(p1Var.id, 0.70); // stickiness
    }

    bump(p1Var.id, (p1Var.dominance.toDouble()) / 100.0 + 0.1);
    bump(p2Var.id, (p2Var.dominance.toDouble()) / 100.0 + 0.1);

    final pair = {p1Var.id, p2Var.id};
    if (pair.contains('spots') && pair.contains('stripes')) {
      bump('checkered', 0.15); // recombination bonus
    }

    for (final v in track.variants) {
      if (v.id == p1Var.id && v.id == p2Var.id) continue;
      if (pair.contains(v.id)) continue;
      final bonus = (v.id == 'checkered') ? 0.08 : 0.05;
      bump(v.id, bonus);
    }

    return OutcomeDistribution<String>(weights);
  }

  OutcomeDistribution<String> getNatureDistribution(Creature p1, Creature p2) {
    final inheritChance = tuning.inheritNatureChance.toDouble();
    final sameLockInChance = tuning.sameNatureLockInChance.toDouble();

    final parents = [p1.nature, p2.nature].whereType<NatureDef>().toList();

    Map<String, double> _poolDominance(List<NatureDef> pool) {
      final m = <String, double>{};
      for (final n in pool) {
        final dom = (n.dominance ?? 1).toDouble();
        m[n.id] = (m[n.id] ?? 0) + dom;
      }
      return m;
    }

    final globalDom = _poolDominance(NatureCatalog.all);

    if (parents.isEmpty) {
      return OutcomeDistribution<String>(globalDom);
    }

    if (parents.length == 2 && parents[0].id == parents[1].id) {
      final sharedNature = parents[0];
      final lockInChunk = sameLockInChance; // % that just locks it in

      final remaining = 100.0 - sameLockInChance;
      final inheritanceChunk = remaining * (inheritChance / 100.0);
      final catalogChunk = remaining * ((100.0 - inheritChance) / 100.0);

      final out = <String, double>{};

      out[sharedNature.id] = (out[sharedNature.id] ?? 0) + lockInChunk;
      out[sharedNature.id] =
          (out[sharedNature.id] ?? 0) + inheritanceChunk; // still them

      final totalGlobalDom = globalDom.values.fold<double>(0, (a, b) => a + b);
      if (totalGlobalDom > 0) {
        globalDom.forEach((natureId, domWeight) {
          final share = catalogChunk * (domWeight / totalGlobalDom);
          out[natureId] = (out[natureId] ?? 0) + share;
        });
      }

      return OutcomeDistribution<String>(out);
    }

    // mixed parent natures
    final parentDom = _poolDominance(parents);

    final out = <String, double>{};

    final inheritanceChunk = inheritChance;
    final totalParentDom = parentDom.values.fold<double>(0, (a, b) => a + b);
    if (totalParentDom > 0) {
      parentDom.forEach((natureId, domWeight) {
        final share = inheritanceChunk * (domWeight / totalParentDom);
        out[natureId] = (out[natureId] ?? 0) + share;
      });
    }

    final catalogChunk = 100.0 - inheritChance;
    final totalGlobalDom = globalDom.values.fold<double>(0, (a, b) => a + b);
    if (totalGlobalDom > 0) {
      globalDom.forEach((natureId, domWeight) {
        final share = catalogChunk * (domWeight / totalGlobalDom);
        out[natureId] = (out[natureId] ?? 0) + share;
      });
    }

    return OutcomeDistribution<String>(out);
  }

  OutcomeDistribution<String> getTintDistribution(Creature p1, Creature p2) {
    final track = GeneticsCatalog.all.firstWhere(
      (t) => t.key == 'tinting',
      orElse: () => GeneticsCatalog.all.first,
    );

    final p1VarId = p1.genetics?.get('tinting') ?? _defaultVariant(track);
    final p2VarId = p2.genetics?.get('tinting') ?? _defaultVariant(track);
    final p1Var = track.byId(p1VarId);
    final p2Var = track.byId(p2VarId);

    final baseDom = <String, double>{
      for (final v in track.variants) v.id: v.dominance.toDouble(),
    };

    Map<String, double> biased = _applyTintBiasInternal(
      baseDom: baseDom,
      p1Types: p1.types,
      p2Types: p2.types,
    );

    if (p1Var.id == p2Var.id) {
      final shared = p1Var.id;
      biased[shared] = (biased[shared] ?? 0) * 6.0; // ~70% stickiness
    }

    final mutationChance = track.mutationChance;
    final inheritChance = 1.0 - mutationChance;

    final mutPool = <String, double>{};
    final nonNormals = track.variants.where((v) => v.id != 'normal');
    for (final v in nonNormals) {
      mutPool[v.id] = 1.0;
    }

    Map<String, double> _normalize(Map<String, double> w) {
      final tot = w.values.fold<double>(0, (a, b) => a + b);
      if (tot <= 0) return w.map((k, v) => MapEntry(k, 0.0));
      return w.map((k, v) => MapEntry(k, v / tot));
    }

    final normInherit = _normalize(biased);
    final normMut = _normalize(mutPool);

    final finalWeights = <String, double>{};
    for (final id in {...normInherit.keys, ...normMut.keys}) {
      finalWeights[id] =
          (inheritChance * (normInherit[id] ?? 0.0)) +
          (mutationChance * (normMut[id] ?? 0.0));
    }

    return OutcomeDistribution<String>(finalWeights);
  }

  OutcomeDistribution<String> getBiasedElementDistribution(
    Creature p1,
    Creature p2,
  ) {
    // 1. base element blend from recipes / fusion rules / type-nature bias
    final base = getElementDistribution(p1, p2);

    // 2. penalize fused "third" elements if cross-family with no explicit family recipe
    final crossFamPenalized = _biasElementForCrossFamilyPenalty(base, p1, p2);

    // 3. apply parent nature's same-type multiplier (Homotypic / Heterotypic)
    final natureBiased = _applySameTypeNatureBias(crossFamPenalized, p1, p2);

    return natureBiased;
  }

  OutcomeDistribution<String> getBiasedFamilyDistribution(
    Creature p1,
    Creature p2,
  ) {
    // 1. base (recipe, same-family stickiness, etc.)
    final base = getFamilyDistribution(p1, p2);

    // 2. bias toward less rare parent
    final rarityBiased = _biasFamilyTowardLessRareParent(base, p1, p2);

    // 3. apply nature bias (Sympatric / Conspecific etc.)
    final natureBiased = _applySameSpeciesNatureBias(rarityBiased, p1, p2);

    return natureBiased;
  }

  OutcomeDistribution<String> _applySameTypeNatureBias(
    OutcomeDistribution<String> base,
    Creature p1,
    Creature p2,
  ) {
    final t1 = p1.types.isNotEmpty ? p1.types.first : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first : null;

    if (t1 == null && t2 == null) {
      return base;
    }

    final p1Mult = _natureMult(p1, 'breed_same_type_chance_mult');
    final p2Mult = _natureMult(p2, 'breed_same_type_chance_mult');

    // 🔍 DEBUG LOGGING
    debugPrint(
      '[NatureBias] ${p1.name}(${t1 ?? "?"}, mult=$p1Mult) × '
      '${p2.name}(${t2 ?? "?"}, mult=$p2Mult) '
      '→ base=${base.weights}',
    );

    final newWeights = <String, double>{};

    base.weights.forEach((elem, w) {
      double mult = 1.0;

      if (t1 != null && elem == t1) mult *= p1Mult;
      if (t2 != null && elem == t2) mult *= p2Mult;

      newWeights[elem] = w * mult;
    });

    debugPrint('[NatureBias] after mults=$newWeights');

    return OutcomeDistribution<String>(newWeights);
  }

  OutcomeDistribution<String> _applySameSpeciesNatureBias(
    OutcomeDistribution<String> base,
    Creature p1,
    Creature p2,
  ) {
    final fam1 = _familyOf(p1);
    final fam2 = _familyOf(p2);

    // pull each parent’s multiplier for "please make my species/family"
    final p1Mult = _natureMult(p1, 'breed_same_species_chance_mult');
    final p2Mult = _natureMult(p2, 'breed_same_species_chance_mult');

    final newWeights = <String, double>{};

    base.weights.forEach((fam, w) {
      double mult = 1.0;

      // if this family matches parent1's family, apply parent1's multiplier
      if (fam == fam1) {
        mult *= p1Mult;
      }

      // if this family matches parent2's family, apply parent2's multiplier
      if (fam == fam2) {
        mult *= p2Mult;
      }

      newWeights[fam] = w * mult;
    });

    return OutcomeDistribution<String>(newWeights);
  }

  // internal tint bias math
  Map<String, double> _applyTintBiasInternal({
    required Map<String, double> baseDom,
    required List<String> p1Types,
    required List<String> p2Types,
  }) {
    final w = Map<String, double>.from(baseDom);
    for (final t in [...p1Types, ...p2Types]) {
      final b = tintBiasPerType[t];
      if (b == null) continue;
      b.forEach((variantId, mult) {
        w[variantId] = (w[variantId] ?? 0) * mult;
      });
    }
    // always leave "normal" available
    w['normal'] = (w['normal'] ?? 0.01).clamp(0.01, double.infinity);
    return w;
  }

  double _natureMult(Creature c, String key) {
    final eff = c.nature?.effect;
    if (eff == null) return 1.0;
    final raw = eff[key];
    if (raw is num) return raw.toDouble();
    return 1.0;
  }

  // ─────────────────────────────────────
  // 3G. Low-level helpers / utils
  // ─────────────────────────────────────

  bool _roll(num pct) => _random.nextInt(100) < pct;

  String _familyOf(Creature c) => (c.mutationFamily ?? 'Unknown');

  int _rarityRank(String rarity) {
    const order = {
      'Common': 0,
      'Uncommon': 1,
      'Rare': 2,
      'Epic': 3,
      'Legendary': 4,
      'Mythic': 5,
    };
    return order[rarity] ?? 0;
  }

  String _higherRarity(String a, String b) =>
      (_rarityOrder.indexOf(a) >= _rarityOrder.indexOf(b)) ? a : b;

  bool _withinOneRarity(String base, String candidate) {
    final i = _rarityOrder.indexOf(base);
    final j = _rarityOrder.indexOf(candidate);
    if (i < 0 || j < 0) return true; // permissive if unknown
    return (j - i).abs() <= 1;
  }

  bool _passesRequiredTypes(Creature c, Creature p1, Creature p2) {
    // at least one elemental type overlap with either parent
    return c.types.any((t) => p1.types.contains(t) || p2.types.contains(t));
  }

  Creature? _tryCrossVariant(Creature p1, Creature p2) {
    final t1 = p1.types.first;
    final t2 = p2.types.first;

    if (p1.variantTypes.contains(t2) && _roll(tuning.variantChanceCross)) {
      return Creature.variant(
        baseId: p1.id,
        baseName: p1.name,
        primaryType: t1,
        secondaryType: t2,
        baseImage: p1.image,
        spriteVariantData: p1.spriteData,
      );
    }

    if (p2.variantTypes.contains(t1) && _roll(tuning.variantChanceCross)) {
      return Creature.variant(
        baseId: p2.id,
        baseName: p2.name,
        primaryType: t2,
        secondaryType: t1,
        baseImage: p2.image,
        spriteVariantData: p2.spriteData,
      );
    }

    return null;
  }

  double _noise(Random r, double mean, double sigma) =>
      (r.nextDouble() * 2 - 1) * sigma + mean;

  String _defaultVariant(GeneTrack t) {
    final normal = t.variants.where((v) => v.id == 'normal');
    if (normal.isNotEmpty) return normal.first.id;
    // fallback = highest dominance if no explicit "normal"
    return t.variants.reduce((a, b) => a.dominance >= b.dominance ? a : b).id;
  }

  GeneVariant _dominantPick(GeneVariant a, GeneVariant b, Random r) {
    if (a.dominance > b.dominance) return a;
    if (b.dominance > a.dominance) return b;
    return r.nextBool() ? a : b;
  }

  GeneVariant _nearestBy(
    GeneTrack track, {
    required double value,
    required double Function(GeneVariant) read,
  }) {
    GeneVariant best = track.variants.first;
    double bestD = (read(best) - value).abs();
    for (final v in track.variants.skip(1)) {
      final d = (read(v) - value).abs();
      if (d < bestD) {
        best = v;
        bestD = d;
      }
    }
    return best;
  }

  String _adjacentSnap(GeneTrack track, String currentId, Random r) {
    final list = track.variants;
    final idx = list.indexWhere((v) => v.id == currentId);
    if (idx < 0) return currentId;
    final options = <int>[];
    if (idx > 0) options.add(idx - 1);
    if (idx + 1 < list.length) options.add(idx + 1);
    if (options.isEmpty) return currentId;
    return list[options[r.nextInt(options.length)]].id;
  }

  String _snapTowardCenter(GeneTrack track, String currentId) {
    final list = track.variants;
    final idx = list.indexWhere((v) => v.id == currentId);
    if (idx < 0) return currentId;

    final centerIdx = list.indexWhere((v) => v.id == 'normal');
    if (centerIdx < 0) return currentId;

    if (idx == centerIdx) return currentId;
    final toward = idx < centerIdx ? idx + 1 : idx - 1;
    return list[toward].id;
  }

  GeneVariant _weightedPickByDominance(GeneTrack track, Random rng) {
    final items = track.variants;
    final total = items.fold<int>(0, (sum, v) => sum + v.dominance);
    if (total <= 0) return items.first;
    var roll = rng.nextInt(total);
    for (final v in items) {
      roll -= v.dominance;
      if (roll < 0) return v;
    }
    return items.last;
  }

  String _weightedPickFromMap(Map<String, double> weights, Random rng) {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return weights.keys.first;
    var roll = rng.nextDouble() * total;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return weights.keys.last;
  }

  void _log(String s) {
    if (logToConsole) debugPrint(s);
  }
}

// ───────────────────────────────────────────────────────────
// 4. Wild breeding helper (engine extension)
// ───────────────────────────────────────────────────────────

extension WildBreed on BreedingEngine {
  BreedingResult breedInstanceWithCreature(
    db.CreatureInstance a,
    Creature wild,
  ) {
    final baseA = repository.getCreatureById(a.baseId);
    if (baseA == null) return BreedingResult.failure();

    final gA = decodeGenetics(a.geneticsJson);

    final parentA = baseA.copyWith(
      genetics: gA ?? baseA.genetics,
      nature: (a.natureId != null)
          ? NatureCatalog.byId(a.natureId!)
          : baseA.nature,
      isPrismaticSkin: a.isPrismaticSkin || (baseA.isPrismaticSkin),
    );

    final snapA = ParentSnapshotFactory.fromDbInstance(a, repository);
    final snapB = ParentSnapshot.fromCreatureWithStats(wild, null);

    return _breedCore(parentA, wild, parentA: snapA, parentB: snapB);
  }
}

// ───────────────────────────────────────────────────────────
// 5. Parent snapshot helper for DB instances
// ───────────────────────────────────────────────────────────

class ParentSnapshotFactory {
  static ParentSnapshot fromDbInstance(
    db.CreatureInstance inst,
    CreatureRepository repo,
  ) {
    final base = repo.getCreatureById(inst.baseId);
    if (base == null) {
      // defensive "unknown" snapshot
      return ParentSnapshot(
        instanceId: inst.instanceId,
        baseId: inst.baseId,
        name: 'Unknown',
        types: const [],
        rarity: 'Common',
        isPrismaticSkin: inst.isPrismaticSkin,
        genetics: decodeGenetics(inst.geneticsJson),
        spriteData: null,
        image: '',
        nature: null,
      );
    }

    final genetics = decodeGenetics(inst.geneticsJson);

    return ParentSnapshot(
      instanceId: inst.instanceId,
      baseId: base.id,
      name: base.name,
      types: base.types,
      rarity: base.rarity,
      isPrismaticSkin: inst.isPrismaticSkin,
      genetics: genetics,
      spriteData: base.spriteData,
      image: base.image,
      nature: (inst.natureId != null)
          ? NatureCatalog.byId(inst.natureId!)
          : base.nature,
    );
  }
}
