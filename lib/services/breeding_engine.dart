// lib/services/breeding_engine.dart
//
// BreedingEngine
//
// Flow:
//   0. global mutation (1% rarity bump + fused element)
//   1. guaranteed pair
//   2. same-species clone
//   3. hybrid:
//        3a. roll family (biased toward less-rare parent + nature bias)
//        3b. roll element (penalize fusion if cross-family + no recipe +
//            nature bias)
//        3c. pick catalog creature for (family, element)
//      if none ->
//   4. forced parent fallback (must succeed)
//
// Analyzer support:
//   getFamilyDistribution / getElementDistribution / etc return deterministic
//   weight maps so UI can show “% chance this happened”.
//
// Depends on:
//   CreatureRepository, ElementRecipeConfig, FamilyRecipeConfig,
//   SpecialRulesConfig, BreedingTuning, GeneticsCatalog, NatureCatalog.

import 'dart:convert';
import 'dart:math';

import 'package:alchemons/models/elemental_group.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/offspring_lineage.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/nature_utils.dart';

// ───────────────────────────────────────────────────────────
// SECTION 1. Public helper types / constants
// ───────────────────────────────────────────────────────────

/// Generic weighted distribution helper used by the analyzer and engine.
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
    // fallback, shouldn't normally hit
    return weights.keys.first;
  }
}

/// Cosmetic tint bias table keyed by elemental type.
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

/// Result of a breed() call.
class BreedingResult {
  final Creature? creature;
  final bool success;
  BreedingResult({this.creature, this.success = true});
  BreedingResult.failure() : creature = null, success = false;
}

/// Convenience for callers who want stats alongside the creature.
class BreedingResultWithStats {
  final Creature creature;
  final CreatureStats stats;
  BreedingResultWithStats({required this.creature, required this.stats});
}

// ───────────────────────────────────────────────────────────
// SECTION 2. BreedingEngine
// ───────────────────────────────────────────────────────────

class BreedingEngine {
  // ── 2.1 Fields / ctor ─────────────────────────────────────

  final CreatureCatalog repository;
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

  static const _rarityOrder = [
    "Common",
    "Uncommon",
    "Rare",
    "Legendary",
    "Mythic",
  ];

  // ── 2.2 Public entrypoints ────────────────────────────────

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

    // parent 1 and 2 as live "actual" parents (their genetics/nature as owned)
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

  // ── 2.3 Core pipeline (_breedCore) ────────────────────────
  //
  // This is the "what species do we get?" decision tree.
  //

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

    // STEP 0: rare global mutation
    if (_roll(tuning.globalMutationChance)) {
      final mutatedBase = _tryGlobalMutation(p1, p2);
      if (mutatedBase != null) {
        _log('[Breeding] Step0 hit → ${mutatedBase.id}');
        final mutatedFinal = _finalizeChild(
          mutatedBase,
          p1,
          p2,
          parentA: parentA,
          parentB: parentB,
        );
        _log('[Breeding] RESULT (mutated): ${mutatedFinal.id}');
        _log('[Breeding] === BREED END ===');
        return BreedingResult(creature: mutatedFinal);
      }
      _log('[Breeding] Step0 rolled but no candidate found');
    } else {
      _log('[Breeding] Step0 miss');
    }

    // STEP 1: special guaranteed pair overrides
    final gk = SpecialRulesConfig.idKey(p1.id, p2.id);
    final outs = specialRules.guaranteedPairs[gk];
    if (outs != null && outs.isNotEmpty) {
      for (final rule in outs) {
        if (_roll(rule.chance)) {
          final fixed = repository.getCreatureById(rule.resultId);
          if (fixed != null && _passesRequiredTypes(fixed, p1, p2)) {
            _log('[Breeding] Step1 hit → ${fixed.id}');
            final fixedChild = _finalizeChild(
              fixed,
              p1,
              p2,
              parentA: parentA,
              parentB: parentB,
            );
            _log('[Breeding] RESULT (guaranteed): ${fixedChild.id}');
            _log('[Breeding] === BREED END ===');
            return BreedingResult(creature: fixedChild);
          }
        }
      }
      _log('[Breeding] Step1: rules exist but did not hit');
    } else {
      _log('[Breeding] Step1: none');
    }

    // STEP 2: identical species just clones the line
    if (p1.id == p2.id) {
      _log('[Breeding] Step2: same-species → ${p1.id}');
      final pure = _finalizeChild(
        p1,
        p1,
        p2,
        parentA: parentA,
        parentB: parentB,
      );
      _log('[Breeding] RESULT (pure): ${pure.id}');
      _log('[Breeding] === BREED END ===');
      return BreedingResult(creature: pure);
    }

    // STEP 3: hybrid
    //    3a pick family
    //    3b pick element
    //    3c choose catalog creature that matches those

    final famDist = getLineageAwareFamilyDistribution(p1, p2, parentA, parentB);
    final childFamily = famDist.sample(_random);

    final elemDist = getLineageAwareElementDistribution(
      p1,
      p2,
      parentA,
      parentB,
    );
    final childElement = elemDist.sample(_random);

    // build pool of catalog creatures with (family, element)
    final pool = repository.creatures.where((c) {
      if (_familyOf(c) != childFamily) return false;
      if (c.types.isEmpty || c.types.first != childElement) return false;
      return true;
    }).toList();

    _log('[Breeding] Step3c pool size: ${pool.length}');

    if (pool.isNotEmpty) {
      final higherParentRarity = _higherRarity(p1.rarity, p2.rarity);

      // prefer stuff near parent rarity
      final pref = pool
          .where((c) => _withinOneRarity(higherParentRarity, c.rarity))
          .toList();
      final sel = pref.isNotEmpty ? pref : pool;

      // bias selection toward either parent's family (gives lineage feel)
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
      final offspringBase = pickList[_random.nextInt(pickList.length)];

      _log('[Breeding] Step3c picked ${offspringBase.id}');

      final finalized = _finalizeChild(
        offspringBase,
        p1,
        p2,
        parentA: parentA,
        parentB: parentB,
      );

      _log(
        '[Breeding] RESULT (hybrid): ${finalized.id} • fam=${_familyOf(finalized)} • ${finalized.types.first} • ${finalized.rarity}',
      );
      _log('[Breeding] === BREED END ===');
      return BreedingResult(creature: finalized);
    }

    _log('[Breeding] Step3c no valid hybrid species found');

    // STEP 4: forced fallback to one parent species
    final fallbackBase = _random.nextBool() ? p1 : p2;
    _log('[Breeding] Step4 fallback → ${fallbackBase.id}');

    final fallbackFinal = _finalizeChild(
      fallbackBase,
      p1,
      p2,
      parentA: parentA,
      parentB: parentB,
    );

    _log(
      '[Breeding] RESULT (forced-parent): ${fallbackFinal.id} • fam=${_familyOf(fallbackFinal)} • ${fallbackFinal.types.first} • ${fallbackFinal.rarity}',
    );
    _log('[Breeding] === BREED END ===');

    return BreedingResult(creature: fallbackFinal);
  }

  // ── 2.4 Child finalization (stats, genetics, lineage, parentage) ──────────

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
    if (n != null) {
      child = child.copyWith(nature: n);
    }

    // Prismatic cosmetic roll
    if (_random.nextDouble() < tuning.prismaticSkinChance) {
      _log('[Breeding] prismatic skin applied');
      child = child.copyWith(isPrismaticSkin: true);
    }

    // Parent snapshot and timestamp
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
    // figure out factions/elements/families at this point
    final nativeFaction = elementalGroupNameOf(child);
    final factionA = elementalGroupNameOf(p1);
    final factionB = elementalGroupNameOf(p2);

    final primaryElemChild = child.types.isNotEmpty ? child.types.first : null;
    final primaryElemA = p1.types.isNotEmpty ? p1.types.first : null;
    final primaryElemB = p2.types.isNotEmpty ? p2.types.first : null;

    final famChild = _familyOf(child);
    final famA = _familyOf(p1);
    final famB = _familyOf(p2);

    // generation depth still tracked
    final depth = _computeChildDepth(parentA, parentB);

    // MERGE & INCREMENT — faction
    final factionLineage = _mergeLineageCounts(
      a: parentA,
      b: parentB,
      childNativeFaction: nativeFaction,
    );

    // MERGE & INCREMENT — elements
    final elementLineage = _mergeCounts(
      aMap: parentA.elementLineage,
      bMap: parentB.elementLineage,
      incrementKeys: [
        if (primaryElemA != null) primaryElemA,
        if (primaryElemB != null) primaryElemB,
        if (primaryElemChild != null) primaryElemChild,
      ],
    );

    // MERGE & INCREMENT — families
    final familyLineage = _mergeCounts(
      aMap: parentA.familyLineage,
      bMap: parentB.familyLineage,
      incrementKeys: [famA, famB, famChild],
    );

    // roll variant faction (existing logic)
    final rolledAFaction = _rollVariantFaction(
      childNativeFaction: nativeFaction,
      lineageCounts: factionLineage,
      partnerFaction: factionA,
      rng: _random,
    );
    final rolledBFaction = _rollVariantFaction(
      childNativeFaction: nativeFaction,
      lineageCounts: factionLineage,
      partnerFaction: factionB,
      rng: _random,
    );

    String? finalVariantFaction;
    if (rolledAFaction != null && rolledBFaction != null) {
      final scoreA = factionLineage[rolledAFaction] ?? 0;
      final scoreB = factionLineage[rolledBFaction] ?? 0;
      finalVariantFaction = (scoreA >= scoreB)
          ? rolledAFaction
          : rolledBFaction;
    } else {
      finalVariantFaction = rolledAFaction ?? rolledBFaction;
    }

    // lineage payload
    final lineageData = OffspringLineageData(
      generationDepth: depth,
      factionLineage: factionLineage,
      nativeFaction: nativeFaction,
      variantFaction: finalVariantFaction,

      // NEW
      elementLineage: elementLineage,
      familyLineage: familyLineage,
    );

    final isPure = _computeIsPure(lineageData);

    child = child.copyWith(lineageData: lineageData, isPure: isPure);

    return child;
  }

  // ── 2.5 Analyzer-facing distributions (deterministic) ────────────────────
  //
  // UI/inspector calls these to say “there was a 22% chance of X”.
  //

  OutcomeDistribution<String> getLineageAwareFamilyDistribution(
    Creature p1,
    Creature p2,
    ParentSnapshot a,
    ParentSnapshot b,
  ) {
    final base = getBiasedFamilyDistribution(p1, p2); // your existing steps

    // Merge parents’ lineage without the child increment yet
    final merged = _mergeCounts(
      aMap: a.familyLineage,
      bMap: b.familyLineage,
      incrementKeys: [
        _familyOf(p1),
        _familyOf(p2),
      ], // credit parents’ current families
    );

    final biased = _applyLineageBias(
      base,
      merged,
      perPoint: tuning.familyLineageBiasPerPoint,
      capMult: tuning.familyLineageBiasCapMult,
    );

    return biased;
  }

  OutcomeDistribution<String> getLineageAwareElementDistribution(
    Creature p1,
    Creature p2,
    ParentSnapshot a,
    ParentSnapshot b,
  ) {
    final base = getBiasedElementDistribution(
      p1,
      p2,
    ); // existing steps (recipes, cross-family penalty, nature)

    final e1 = p1.types.isNotEmpty ? p1.types.first : null;
    final e2 = p2.types.isNotEmpty ? p2.types.first : null;

    // Merge parents’ element lineage and increment parents’ current primary types
    final merged = _mergeCounts(
      aMap: a.elementLineage,
      bMap: b.elementLineage,
      incrementKeys: [if (e1 != null) e1, if (e2 != null) e2],
    );

    final biased = _applyLineageBias(
      base,
      merged,
      perPoint: tuning.elementLineageBiasPerPoint,
      capMult: tuning.elementLineageBiasCapMult,
    );

    return biased;
  }

  OutcomeDistribution<String> getFamilyDistribution(Creature p1, Creature p2) {
    final fam1 = _familyOf(p1);
    final fam2 = _familyOf(p2);

    // same-family: mostly stick, tiny mutation chance
    if (fam1 == fam2) {
      final mutationPct = tuning.sameFamilyMutationChancePct.toDouble();
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

    // cross-family: prefer authored combos first
    final key = FamilyRecipeConfig.keyOf(fam1, fam2);
    final recipe = familyRecipes.recipes[key];
    if (recipe != null && recipe.isNotEmpty) {
      return OutcomeDistribution<String>(
        recipe.map((k, v) => MapEntry(k, v.toDouble())),
      );
    }

    // default 50/50 lineage tug-of-war
    return OutcomeDistribution<String>({fam1: 50.0, fam2: 50.0});
  }

  OutcomeDistribution<String> getElementDistribution(Creature p1, Creature p2) {
    final t1 = p1.types.isNotEmpty ? p1.types.first.trim() : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first.trim() : null;

    // defensive fallbacks
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

    // 1. explicit fusion rule: e.g. Air+Water -> {Ice:70, Air:15, Water:15}
    Map<String, int>? weighted = elementRecipes.recipes[key];

    // 2. no explicit: mix both self maps 50/50 if we have them
    if (weighted == null) {
      final soloA = elementRecipes.recipes[a];
      final soloB = elementRecipes.recipes[b];

      if (soloA != null && soloB != null) {
        final merged = <String, double>{};

        soloA.forEach((elem, w) {
          merged[elem] = (merged[elem] ?? 0) + (w.toDouble() * 0.5);
        });
        soloB.forEach((elem, w) {
          merged[elem] = (merged[elem] ?? 0) + (w.toDouble() * 0.5);
        });

        final mergedInt = <String, int>{};
        merged.forEach((elem, w) {
          mergedInt[elem] = w.round();
        });

        weighted = mergedInt;
      }
    }

    // 3. still nothing? just 50/50 parent types
    weighted ??= {a: 50, b: 50};

    // 4. apply parent natures' same-type push/pull
    final biased = applyTypeNatureBias(Map<String, int>.from(weighted), p1, p2);

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
      bump(p1Var.id, 0.70); // sticky if both match
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

  OutcomeDistribution<String> analyzeFamilyWithLineage(
    Creature p1,
    Creature p2,
    ParentSnapshot a,
    ParentSnapshot b,
  ) => getLineageAwareFamilyDistribution(p1, p2, a, b);

  OutcomeDistribution<String> analyzeElementWithLineage(
    Creature p1,
    Creature p2,
    ParentSnapshot a,
    ParentSnapshot b,
  ) => getLineageAwareElementDistribution(p1, p2, a, b);

  OutcomeDistribution<String> getNatureDistribution(Creature p1, Creature p2) {
    final inheritChance = tuning.inheritNatureChance.toDouble();
    final sameLockInChance = tuning.sameNatureLockInChance.toDouble();

    final parents = [p1.nature, p2.nature].whereType<NatureDef>().toList();

    Map<String, double> _poolDom(List<NatureDef> pool) {
      final m = <String, double>{};
      for (final n in pool) {
        final dom = (n.dominance ?? 1).toDouble();
        m[n.id] = (m[n.id] ?? 0) + dom;
      }
      return m;
    }

    final globalDom = _poolDom(NatureCatalog.all);

    if (parents.isEmpty) {
      return OutcomeDistribution<String>(globalDom);
    }

    if (parents.length == 2 && parents[0].id == parents[1].id) {
      final sharedNature = parents[0];

      final lockInChunk = sameLockInChance;
      final remaining = 100.0 - sameLockInChance;

      final inheritanceChunk = remaining * (inheritChance / 100.0);
      final catalogChunk = remaining * ((100.0 - inheritChance) / 100.0);

      final out = <String, double>{};

      out[sharedNature.id] = (out[sharedNature.id] ?? 0) + lockInChunk;
      out[sharedNature.id] = (out[sharedNature.id] ?? 0) + inheritanceChunk;

      final totalGlobalDom = globalDom.values.fold<double>(0, (a, b) => a + b);
      if (totalGlobalDom > 0) {
        globalDom.forEach((natureId, domWeight) {
          final share = catalogChunk * (domWeight / totalGlobalDom);
          out[natureId] = (out[natureId] ?? 0) + share;
        });
      }

      return OutcomeDistribution<String>(out);
    }

    // mixed parent natures:
    final parentDom = _poolDom(parents);
    final out = <String, double>{};

    final totalParentDom = parentDom.values.fold<double>(0, (a, b) => a + b);
    if (totalParentDom > 0) {
      parentDom.forEach((natureId, domWeight) {
        final share = inheritChance * (domWeight / totalParentDom);
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

    // apply per-type tint bias
    Map<String, double> biased = _applyTintBiasInternal(
      baseDom: baseDom,
      p1Types: p1.types,
      p2Types: p2.types,
    );

    // sticky if parents match
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

  OutcomeDistribution<String> getBiasedFamilyDistribution(
    Creature p1,
    Creature p2,
  ) {
    // 1. base (recipe, same-family stickiness, etc.)
    final base = getFamilyDistribution(p1, p2);

    // 2. rarity bias (favor less-rare parent's family)
    final rarityBiased = _biasFamilyTowardLessRareParent(base, p1, p2);

    // 3. parental nature bias (breed_same_species_chance_mult)
    final natureBiased = _applySameSpeciesNatureBias(rarityBiased, p1, p2);

    return natureBiased;
  }

  OutcomeDistribution<String> getBiasedElementDistribution(
    Creature p1,
    Creature p2,
  ) {
    // 1. base element blend (recipes / nature bias toward parent types)
    final base = getElementDistribution(p1, p2);

    // 2. penalize weird fusion elements if cross-family without explicit recipe
    final crossFamPenalized = _biasElementForCrossFamilyPenalty(base, p1, p2);

    // 3. apply per-parent nature multiplier for "keep my same type"
    final natureBiased = _applySameTypeNatureBias(crossFamPenalized, p1, p2);

    return natureBiased;
  }

  // ── 2.6 Nature / Genetics / Stats helpers ────────────────────────────────

  NatureDef? _chooseChildNature(Creature p1, Creature p2) {
    final rng = _random;
    final inheritChance = tuning.inheritNatureChance;
    final sameLockInChance = tuning.sameNatureLockInChance;

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
          {
            // "size"-like scalar blend
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
          }

        case 'weighted':
          {
            // tinting / patterning / etc (dominance-weighted + mutation spice)
            final bothSame = p1Var.id == p2Var.id;
            final stick = bothSame && rng.nextDouble() < 0.70;

            if (track.key == 'tinting') {
              final baseDom = <String, int>{
                for (final v in track.variants) v.id: v.dominance,
              };

              final biasedDoubles = _applyTintBiasInternal(
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
          }

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

  // In breeding_engine.dart, update _generateChildStats method:

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
        mutationStrength: 0.3,
        parent1NatureId: parentA.nature?.id, // NEW: pass nature IDs
        parent2NatureId: parentB.nature?.id, // NEW: pass nature IDs
        childNatureId: childNature?.id, // NEW: pass child nature
      );
      _log('[Breeding] Stats from both parents (blend with nature awareness)');
    } else if (statsA != null) {
      childStats = CreatureStats.breed(
        statsA,
        CreatureStats.generate(_random),
        _random,
        mutationChance: 0.20,
        mutationStrength: 0.3,
        parent1NatureId: parentA.nature?.id,
        childNatureId: childNature?.id,
      );
      _log('[Breeding] Stats mostly parent A');
    } else if (statsB != null) {
      childStats = CreatureStats.breed(
        CreatureStats.generate(_random),
        statsB,
        _random,
        mutationChance: 0.20,
        mutationStrength: 0.3,
        parent2NatureId: parentB.nature?.id,
        childNatureId: childNature?.id,
      );
      _log('[Breeding] Stats mostly parent B');
    } else {
      childStats = CreatureStats.generate(_random);
      _log('[Breeding] Stats fresh roll');
    }

    // Apply modifiers from nature / genetics
    childStats = childStats.applyNature(childNature?.id);
    childStats = childStats.applyGenetics(childGenetics);

    _log(
      '[Breeding] Final stats: '
      'Speed=${childStats.speed.toStringAsFixed(2)}, '
      'Int=${childStats.intelligence.toStringAsFixed(2)}, '
      'Str=${childStats.strength.toStringAsFixed(2)}, '
      'Beauty=${childStats.beauty.toStringAsFixed(2)} | '
      'Potentials: '
      'Speed=${childStats.speedPotential.toStringAsFixed(2)}, '
      'Int=${childStats.intelligencePotential.toStringAsFixed(2)}, '
      'Str=${childStats.strengthPotential.toStringAsFixed(2)}, '
      'Beauty=${childStats.beautyPotential.toStringAsFixed(2)}',
    );

    return childStats;
  }
  // ── 2.7 Lineage helpers (depth, ancestry map, variantFaction) ────────────

  int _computeChildDepth(ParentSnapshot a, ParentSnapshot b) {
    final da = a.generationDepth;
    final db = b.generationDepth;
    return (da > db ? da : db) + 1;
  }

  Map<String, int> _mergeLineageCounts({
    required ParentSnapshot a,
    required ParentSnapshot b,
    required String childNativeFaction,
  }) {
    final out = <String, int>{};

    // bring forward lineage counts from both parents
    void absorb(Map<String, int> src) {
      src.forEach((faction, count) {
        final prev = out[faction] ?? 0;
        if (count > prev) {
          out[faction] = count;
        }
      });
    }

    absorb(a.factionLineage);
    absorb(b.factionLineage);

    // increment each parent's faction
    out[a.nativeFaction] = (out[a.nativeFaction] ?? 0) + 1;
    out[b.nativeFaction] = (out[b.nativeFaction] ?? 0) + 1;

    // increment child's own faction
    out[childNativeFaction] = (out[childNativeFaction] ?? 0) + 1;

    return out;
  }

  String? _rollVariantFaction({
    required String childNativeFaction,
    required Map<String, int> lineageCounts,
    required String
    partnerFaction, // the faction of the parent you're breeding WITH
    required Random rng,
  }) {
    // You can’t variant into the same faction you already are.
    if (partnerFaction == childNativeFaction) {
      return null;
    }

    // How much heritage do we already have in THAT partner's faction?
    final score = lineageCounts[partnerFaction] ?? 0;
    if (score <= 0) {
      // zero history in that faction = no variant shot
      return null;
    }

    // Each lineage point = +1%, capped at 10%
    double chancePct = score * 1.0; // 1 point -> 1%
    if (chancePct > 10.0) {
      chancePct = 10.0;
    }

    final roll = rng.nextDouble() * 100.0;
    if (roll > chancePct) {
      return partnerFaction;
    }

    return null;
  }

  /// Compute the chance (0-100) that we would have rolled *any* variantFaction
  /// for this child lineage, AND the weighted share for the specific faction
  /// we actually landed on.
  ///
  /// Returns null if:
  ///   - there was no variantFaction (i.e. child stayed native),
  ///   - or there were no valid candidate factions.
  ///
  /// Otherwise returns a tuple-ish struct with:
  ///   triggerChancePct   ~ how likely were we to trigger "variant mode" at all
  ///   pickedFactionPct   ~ conditional weight share for that specific faction,
  ///                        multiplied in, so it's the *final* % for that exact
  ///                        faction happening.
  VariantFactionOdds? computeVariantFactionOdds({required Creature child}) {
    final lineageData = child.lineageData;
    if (lineageData == null) return null;

    final rolledFaction = lineageData.variantFaction;
    if (rolledFaction == null) return null; // no variant at all

    final depth = lineageData.generationDepth;
    final childNative = lineageData.nativeFaction;
    final lineageCounts = lineageData.factionLineage;

    // 1. candidate pool excluding child's native faction
    final candidates = <String, int>{};
    lineageCounts.forEach((faction, score) {
      if (faction != childNative && score > 0) {
        candidates[faction] = score;
      }
    });

    if (candidates.isEmpty) return null;

    // 2. trigger chance
    final baseChance = 0.02; // 2%
    final depthBonus = 0.01 * depth; // +1% per depth
    final triggerChance = baseChance + depthBonus; // 0-1
    final triggerChancePct = (triggerChance * 100.0).clamp(0.0, 100.0);

    // 3. pick weight for the specific rolled faction
    final totalWeight = candidates.values.fold<int>(0, (sum, v) => sum + v);
    if (totalWeight <= 0) return null;

    final chosenWeight = candidates[rolledFaction] ?? 0;
    if (chosenWeight <= 0) return null;

    final share = chosenWeight / totalWeight; // 0-1

    // final chance for THAT faction (trigger * share)
    final finalPct = (triggerChance * share * 100.0).clamp(0.0, 100.0);

    return VariantFactionOdds(
      triggerChancePct: triggerChancePct,
      pickedFactionPct: finalPct,
      pickedFactionId: rolledFaction,
    );
  }

  // ── 2.8 Low-level / math / misc utils ───────────────────────────────────

  bool _computeIsPure(OffspringLineageData data) {
    // Pure if it only ever bred within its own native faction
    // i.e., lineage map has only one entry and it matches nativeFaction
    return data.factionLineage.keys.length == 1 &&
        data.factionLineage.containsKey(data.nativeFaction);
  }

  Creature? _tryGlobalMutation(Creature p1, Creature p2) {
    // escalate rarity one tier above the higher parent, up to Legendary
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

      // If they're already near the top tier (Legendary/Mythic),
      // don't escalate further.
      if (i < 0 || i >= tiers.length - 2) return rarity;

      return tiers[i + 1];
    }

    final parentTopRarity = [
      p1.rarity,
      p2.rarity,
    ].reduce((a, b) => _rarityRank(a) >= _rarityRank(b) ? a : b);

    final targetRarity = nextRarity(parentTopRarity);

    // candidate elemental types = parents' primaries + fusion outputs
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

    // pick any catalog entry at that new rarity with an allowed element
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

    // lower rarityRank = more common = "less rare"
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

    // If families match OR we explicitly authored this cross-family combo,
    // don't penalize fusion.
    if (sameFamily || hasRecipe) {
      return base;
    }

    // otherwise, penalize "third" fusion types (Steam, Lava...) a bit
    final t1 = p1.types.isNotEmpty ? p1.types.first : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first : null;
    if (t1 == null || t2 == null) return base;

    final fusionKey = ElementRecipeConfig.keyOf(t1, t2);
    final fusionRecipe = elementRecipes.recipes[fusionKey];
    if (fusionRecipe == null || fusionRecipe.isEmpty) return base;

    // all fusion outcomes not literally a parent type
    final fusionOutcomes = fusionRecipe.keys
        .where((elem) => elem != t1 && elem != t2)
        .toSet();
    if (fusionOutcomes.isEmpty) return base;

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

  OutcomeDistribution<String> _applySameTypeNatureBias(
    OutcomeDistribution<String> base,
    Creature p1,
    Creature p2,
  ) {
    final t1 = p1.types.isNotEmpty ? p1.types.first : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first : null;

    if (t1 == null && t2 == null) return base;

    final p1Mult = _natureMult(p1, 'breed_same_type_chance_mult');
    final p2Mult = _natureMult(p2, 'breed_same_type_chance_mult');

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

    final p1Mult = _natureMult(p1, 'breed_same_species_chance_mult');
    final p2Mult = _natureMult(p2, 'breed_same_species_chance_mult');

    final newWeights = <String, double>{};

    base.weights.forEach((fam, w) {
      double mult = 1.0;
      if (fam == fam1) mult *= p1Mult;
      if (fam == fam2) mult *= p2Mult;
      newWeights[fam] = w * mult;
    });

    return OutcomeDistribution<String>(newWeights);
  }

  // pure math/util helpers

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

  Map<String, int> _mergeCounts({
    required Map<String, int> aMap,
    required Map<String, int> bMap,
    List<String> incrementKeys = const [],
  }) {
    final out = <String, int>{};

    void absorb(Map<String, int> src) {
      src.forEach((k, v) {
        final prev = out[k] ?? 0;
        if (v > prev) out[k] = v;
      });
    }

    absorb(aMap);
    absorb(bMap);

    for (final k in incrementKeys) {
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  OutcomeDistribution<String> _applyLineageBias(
    OutcomeDistribution<String> base,
    Map<String, int> lineage, {
    required double perPoint,
    required double capMult,
  }) {
    if (base.weights.isEmpty || lineage.isEmpty) return base;

    final out = Map<String, double>.from(base.weights);

    out.updateAll((key, w) {
      final pts = lineage[key] ?? 0;
      if (pts <= 0) return w;
      final mult = (1.0 + (pts * perPoint)).clamp(0.0, capMult);
      return w * mult;
    });

    return OutcomeDistribution<String>(out);
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
    // require offspring to share at least one element with a parent
    return c.types.any((t) => p1.types.contains(t) || p2.types.contains(t));
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

  // per-element tint bias helper
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
    // always keep "normal" at some min
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

  void _log(String s) {
    if (logToConsole) debugPrint(s);
  }
}

// ───────────────────────────────────────────────────────────
// SECTION 3. Wild breeding helper (engine extension)
// ───────────────────────────────────────────────────────────

extension WildBreed on BreedingEngine {
  /// Breed a player-owned instance with a wild (catalog) creature.
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

class VariantFactionOdds {
  final double triggerChancePct; // chance to trigger "variant" at all
  final double pickedFactionPct; // final chance of THIS faction
  final String pickedFactionId;

  const VariantFactionOdds({
    required this.triggerChancePct,
    required this.pickedFactionPct,
    required this.pickedFactionId,
  });
}

// ───────────────────────────────────────────────────────────
// SECTION 4. Parent snapshot helper for DB instances
// ───────────────────────────────────────────────────────────

class ParentSnapshotFactory {
  static ParentSnapshot fromDbInstance(
    db.CreatureInstance inst,
    CreatureCatalog repo,
  ) {
    final base = repo.getCreatureById(inst.baseId);

    Genetics? decodedGenetics = decodeGenetics(inst.geneticsJson);

    Map<String, int> decodeLineage(String? raw) {
      if (raw == null || raw.isEmpty) return {};
      try {
        final map = (jsonDecode(raw) as Map<String, dynamic>);
        return map.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {
        return {};
      }
    }

    if (base == null) {
      // Defensive fallback snapshot (shouldn't happen unless data’s corrupt)
      return ParentSnapshot(
        instanceId: inst.instanceId,
        baseId: inst.baseId,
        name: 'Unknown',
        types: const [],
        rarity: 'Common',
        image: '',
        isPrismaticSkin: inst.isPrismaticSkin,
        genetics: decodedGenetics,
        nature: null,
        spriteData: null,
        stats: CreatureStats(
          speed: inst.statSpeed,
          intelligence: inst.statIntelligence,
          strength: inst.statStrength,
          beauty: inst.statBeauty,
          speedPotential: inst.statSpeedPotential,
          intelligencePotential: inst.statIntelligencePotential,
          strengthPotential: inst.statStrengthPotential,
          beautyPotential: inst.statBeautyPotential,
        ),
        generationDepth: inst.generationDepth ?? 0,
        factionLineage: decodeLineage(inst.factionLineageJson),
        nativeFaction: 'Unknown',
        variantFaction: inst.variantFaction,
        elementLineage: decodeLineage(inst.elementLineageJson), // NEW
        familyLineage: decodeLineage(inst.familyLineageJson), // NEW
      );
    }

    final nativeFaction = elementalGroupNameOf(base);

    return ParentSnapshot(
      instanceId: inst.instanceId,
      baseId: base.id,
      name: base.name,
      types: base.types,
      rarity: base.rarity,
      image: base.image,
      isPrismaticSkin: inst.isPrismaticSkin || (base.isPrismaticSkin ?? false),
      genetics: decodedGenetics ?? base.genetics,
      nature: (inst.natureId != null)
          ? NatureCatalog.byId(inst.natureId!)
          : base.nature,
      spriteData: base.spriteData,
      stats: CreatureStats(
        speed: inst.statSpeed,
        intelligence: inst.statIntelligence,
        strength: inst.statStrength,
        beauty: inst.statBeauty,
        speedPotential: inst.statSpeedPotential,
        intelligencePotential: inst.statIntelligencePotential,
        strengthPotential: inst.statStrengthPotential,
        beautyPotential: inst.statBeautyPotential,
      ),
      generationDepth: inst.generationDepth ?? 0,
      factionLineage: decodeLineage(inst.factionLineageJson),
      nativeFaction: nativeFaction,
      variantFaction: inst.variantFaction,
      elementLineage: decodeLineage(inst.elementLineageJson), // NEW
      familyLineage: decodeLineage(inst.familyLineageJson), // NEW
    );
  }
}
