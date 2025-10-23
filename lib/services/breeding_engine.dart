// lib/services/breeding_engine.dart
//
// Family-first breeding + cross-variants + same-family mutation pop.
// Instance-aware: breed by species IDs OR by CreatureInstances rows.
//
// Depends on:
// - models: Creature, Parentage, ParentSnapshot, Genetics, NatureDef
// - catalogs: GeneticsCatalog, NatureCatalog
// - config: ElementRecipeConfig, FamilyRecipeConfig, SpecialRulesConfig, BreedingTuning
// - repo: CreatureRepository (loaded with base creatures + discovered variants)
// - db rows: alchemons_db.dart as `db` (for CreatureInstance only)

import 'dart:math';

import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_config.dart';

import '../models/creature.dart';
import 'creature_repository.dart';

class BreedingResult {
  final Creature? creature;
  final Creature? variantUnlocked; // optional UX unlock
  final bool success;
  BreedingResult({this.creature, this.variantUnlocked, this.success = true});
  BreedingResult.failure()
    : creature = null,
      variantUnlocked = null,
      success = false;
}

extension WildBreed on BreedingEngine {
  /// Breed a player's DB instance with a fully-hydrated wild Creature.
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
    // Get stats from instance
    final statsA = CreatureStats(
      speed: a.statSpeed,
      intelligence: a.statIntelligence,
      strength: a.statStrength,
      beauty: a.statBeauty,
    );

    // Snapshots with stats
    final snapA = ParentSnapshotFactory.fromDbInstance(a, repository);
    final snapB = ParentSnapshot.fromCreatureWithStats(
      wild,
      null,
    ); // Wild creatures don't have stats

    return _breedCore(parentA, wild, parentA: snapA, parentB: snapB);
  }
}

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

  // ───────────────────────────────────────────────────────────
  // Public APIs
  // ───────────────────────────────────────────────────────────

  /// Breed by **species/catalog IDs** (original behavior).
  BreedingResult breed(String parent1Id, String parent2Id) {
    _log('[Breeding] === BREED START (IDs) ===');

    final p1 = repository.getCreatureById(parent1Id);
    final p2 = repository.getCreatureById(parent2Id);
    if (p1 == null || p2 == null) return BreedingResult.failure();

    return _breedCore(
      p1,
      p2,
      // parentage in the baby will snapshot these *templates*
      parentA: ParentSnapshot.fromCreature(p1),
      parentB: ParentSnapshot.fromCreature(p2),
    );
  }

  /// Breed by **player-owned DB instances**.
  /// Maps the instance overlays (nature / prismatic / genetics) onto the base Creature.
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

    // Include stats in parent snapshots
    final snapA = ParentSnapshotFactory.fromDbInstance(a, repository);
    final snapB = ParentSnapshotFactory.fromDbInstance(b, repository);

    return _breedCore(p1, p2, parentA: snapA, parentB: snapB);
  }

  // ───────────────────────────────────────────────────────────
  // Core engine (unchanged logic, but accepts explicit parent snapshots)
  // ───────────────────────────────────────────────────────────

  static const _rarityOrder = ["Common", "Uncommon", "Rare", "Mythic"];
  static const int _sameFamilyStickinessPct = 99;

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

    // 0) Same species → that species
    if (p1.id == p2.id) {
      _log('[Breeding] Step0: same-species → return parent template.');
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

    // 1) Guaranteed pairs
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
            _log('[Breeding] RESULT: ${fixedChild.id} • ${fixedChild.name}');
            _log('[Breeding] === BREED END ===');
            return BreedingResult(creature: fixedChild);
          }
        }
      }
      _log('[Breeding] Step1: no guaranteed-pair rules matched.');
    } else {
      _log('[Breeding] Step1: no guaranteed-pair rules.');
    }

    // 2) Cross VARIANT
    final maybeVariant = _tryCrossVariant(p1, p2);
    if (maybeVariant != null) {
      _log('[Breeding] Step2: cross-variant produced → ${maybeVariant.id}');
      final finalized = _finalizeChild(
        maybeVariant,
        p1,
        p2,
        parentA: parentA,
        parentB: parentB,
      );
      _log('[Breeding] RESULT: ${finalized.id} • ${finalized.name}');
      _log('[Breeding] === BREED END ===');
      return BreedingResult(creature: finalized, variantUnlocked: maybeVariant);
    } else {
      _log('[Breeding] Step2: no cross-variant or roll failed.');
    }

    // 3) Parent-repeat chance (same-species bias via nature)
    final basePr = tuning.parentRepeatChance; // existing % from your tuning
    final prMult = combinedNatureMult(p1, p2, 'breed_same_species_chance_mult');
    final pr = (basePr * prMult).clamp(0, 100).toInt();

    final rollParent = _random.nextInt(100);
    _log(
      '[Breeding] ROLL [parent-repeat]: need <${pr}%, rolled=$rollParent → ${rollParent < pr ? 'success' : 'fail'}',
    );
    if (rollParent < pr) {
      final base = _random.nextBool() ? p1 : p2;
      _log('[Breeding] Step3: parent-repeat → ${base.id}');
      final sameSpeciesChild = _finalizeChild(
        base,
        p1,
        p2,
        parentA: parentA,
        parentB: parentB,
      );
      _log(
        '[Breeding] RESULT: ${sameSpeciesChild.id} • ${sameSpeciesChild.name}',
      );
      _log('[Breeding] === BREED END ===');
      return BreedingResult(creature: sameSpeciesChild);
    }
    _log('[Breeding] Step3: no parent-repeat.');

    // F) FAMILY resolution
    String childFamily = _resolveChildFamily(fam1, fam2);
    _log('[Breeding] StepF: child family = $childFamily');

    // M) SAME-FAMILY MUTATION
    if (fam1 == fam2) {
      final mc = tuning.sameFamilyMutationChancePct;
      final roll = _random.nextInt(100);
      _log(
        '[Breeding] ROLL [same-family mutation]: need <${mc}%, rolled=$roll → ${roll < mc ? 'mutate' : 'stay'}',
      );
      if (roll < mc) {
        childFamily = _pickMutationFamily(fam1);
        _log('[Breeding] StepM: mutation → new family: $childFamily');
      }
    }

    // 4) ELEMENT resolution
    final t1 = p1.types.first;
    final t2 = p2.types.first;
    final childElement = _resolveChildElement(t1, t2, p1: p1, p2: p2);

    // does this pair have an explicit element rule?
    final pairKey = ElementRecipeConfig.keyOf(t1, t2);
    final hasExplicitElementRule = elementRecipes.recipes.containsKey(pairKey);

    // 5) Pool: (family + element)
    final pool = repository.creatures.where((c) {
      if (_familyOf(c) != childFamily) return false;
      if (c.types.first != childElement) return false;
      return c.id != p1.id && c.id != p2.id;
    }).toList();

    _log(
      '[Breeding] Step5: pool size for (fam=$childFamily, elem=$childElement) = ${pool.length}.',
    );

    // If intended stay in-family and empty, allow returning matching parent
    if (pool.isEmpty && fam1 == fam2 && fam1 == childFamily) {
      final parentMatches = <Creature>[
        if (_familyOf(p1) == childFamily && p1.types.first == childElement) p1,
        if (_familyOf(p2) == childFamily && p2.types.first == childElement) p2,
      ];
      if (parentMatches.isNotEmpty) {
        final picked = parentMatches[_random.nextInt(parentMatches.length)];
        _log(
          '[Breeding] Step5: empty in-family pool → returning matching parent ${picked.id}.',
        );
        final finalized = _finalizeChild(
          picked,
          p1,
          p2,
          parentA: parentA,
          parentB: parentB,
        );
        return BreedingResult(creature: finalized);
      }
    }

    // Choose offspring (pool / fallback)
    late Creature offspring;
    if (pool.isNotEmpty) {
      final higher = _higherRarity(p1.rarity, p2.rarity);
      final pref = pool
          .where((c) => _withinOneRarity(higher, c.rarity))
          .toList();
      final sel = pref.isNotEmpty ? pref : pool;

      final biased = <Creature>[];
      for (final c in sel) {
        final bias = (c.mutationFamily == fam1 || c.mutationFamily == fam2)
            ? 3
            : 1;
        for (int i = 0; i < bias; i++) biased.add(c);
      }
      final pickList = biased.isNotEmpty ? biased : sel;
      final idx = _random.nextInt(pickList.length);
      offspring = pickList[idx];
      _log(
        '[Breeding] pick: list=${pickList.length} → index=$idx (preferred=${pref.isNotEmpty})',
      );
    } else {
      // Fallback A: element-only (ignore family)
      final elemOnly = repository.creatures.where((c) {
        if (c.types.first != childElement) return false;
        if (!hasExplicitElementRule && !_passesRequiredTypes(c, p1, p2))
          return false;
        return c.id != p1.id && c.id != p2.id;
      }).toList();

      if (elemOnly.isNotEmpty) {
        final idx = _random.nextInt(elemOnly.length);
        offspring = elemOnly[idx];
        _log(
          '[Breeding] fallback A: (elem only) size=${elemOnly.length} → index=$idx',
        );
      } else {
        offspring = _fallbackAnyNonParent(p1, p2);
        _log('[Breeding] fallback B: any non-parent.');
      }
    }

    // With:
    final finalized = _finalizeChild(
      offspring,
      p1,
      p2,
      parentA: parentA,
      parentB: parentB,
    );

    _log(
      '[Breeding] RESULT: ${finalized.id} • ${finalized.name} • fam=${_familyOf(finalized)} • ${finalized.types.first} • ${finalized.rarity}',
    );
    _log('[Breeding] === BREED END ===');

    return BreedingResult(creature: finalized);
  }

  // ───────────────────────────────────────────────────────────
  // Finalization
  // ───────────────────────────────────────────────────────────

  // Generate child stats based on parents
  CreatureStats _generateChildStats(
    ParentSnapshot parentA,
    ParentSnapshot parentB,
    NatureDef? childNature,
    Genetics? childGenetics,
  ) {
    // Get parent stats from snapshots (if they exist)
    final statsA = parentA.stats;
    final statsB = parentB.stats;

    CreatureStats childStats;

    if (statsA != null && statsB != null) {
      // Both parents have stats - breed them
      childStats = CreatureStats.breed(
        statsA,
        statsB,
        _random,
        mutationChance: 0.15,
        mutationStrength: 1.0,
      );
      _log('[Breeding] Stats inherited from parents with blending');
    } else if (statsA != null) {
      // Only parent A has stats - use with variance
      childStats = CreatureStats.breed(
        statsA,
        CreatureStats.generate(_random), // Generate random for missing parent
        _random,
        mutationChance: 0.20,
        mutationStrength: 1.2,
      );
      _log('[Breeding] Stats partially inherited from parent A');
    } else if (statsB != null) {
      // Only parent B has stats - use with variance
      childStats = CreatureStats.breed(
        CreatureStats.generate(_random),
        statsB,
        _random,
        mutationChance: 0.20,
        mutationStrength: 1.2,
      );
      _log('[Breeding] Stats partially inherited from parent B');
    } else {
      // Neither parent has stats - generate fresh
      childStats = CreatureStats.generate(_random);
      _log('[Breeding] Stats freshly generated');
    }

    // Apply nature bonus if applicable
    childStats = childStats.applyNature(childNature?.id);
    childStats = childStats.applyGenetics(childGenetics);

    _log(
      '[Breeding] Final stats: Speed=${childStats.speed.toStringAsFixed(1)}, Int=${childStats.intelligence.toStringAsFixed(1)}, Str=${childStats.strength.toStringAsFixed(1)}, Beauty=${childStats.beauty.toStringAsFixed(1)}',
    );

    return childStats;
  }

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

    // Parentage snapshot (use provided parent snapshots)
    final parentage = Parentage(
      parentA: parentA,
      parentB: parentB,
      bredAt: DateTime.now(),
    );
    child = child.copyWith(parentage: parentage);

    final childStats = _generateChildStats(
      parentA,
      parentB,
      child.nature,
      child.genetics,
    );
    child = child.copyWith(stats: childStats);

    return child;
  }

  // ───────────────────────────────────────────────────────────
  // Nature inheritance
  // ───────────────────────────────────────────────────────────

  NatureDef? _chooseChildNature(Creature p1, Creature p2) {
    final rng = _random;
    final inheritChance = tuning.inheritNatureChance; // set to 60
    final sameLockInChance = tuning.sameNatureLockInChance; // set to 50

    final parents = [p1.nature, p2.nature].whereType<NatureDef>().toList();
    if (NatureCatalog.all.isEmpty) return null;

    if (parents.isEmpty) {
      // fresh roll from catalog, weighted by dominance
      return NatureCatalogWeighted.weightedRandom(rng);
    }

    // Optional: strong lock-in if both parents share a nature
    if (parents.length == 2 && parents[0].id == parents[1].id) {
      if (rng.nextInt(100) < sameLockInChance) return parents[0];
    }

    // Inherit from parents with dominance weight
    if (rng.nextInt(100) < inheritChance) {
      return NatureCatalogWeighted.weightedFromPool(parents, rng);
    }

    // Fresh roll from catalog (optionally exclude parents for variety)
    // return NatureCatalogWeighted.weightedRandom(rng, excludeIds: parents.map((n)=>n.id).toSet());
    return NatureCatalogWeighted.weightedRandom(rng);
  }

  // ───────────────────────────────────────────────────────────
  // Patterning (weighted + recombination bonus) and Albino (dominant + sticky)
  // ───────────────────────────────────────────────────────────

  String _inheritPatterning(
    GeneTrack track,
    GeneVariant p1Var,
    GeneVariant p2Var,
    Random rng, {
    required bool didMutate,
  }) {
    // Same-variant stickiness (70%)
    if (p1Var.id == p2Var.id && rng.nextDouble() < 0.70) {
      return p1Var.id;
    }

    // Recombination: spots + stripes has an extra direct roll to checkered
    final pair = {p1Var.id, p2Var.id};
    if (pair.contains('spots') && pair.contains('stripes')) {
      // ~15% shot at checkered before normal weighting
      if (rng.nextDouble() < 0.15) return 'checkered';
    }

    // Normal dominance-weighted pick
    String picked = _weightedPickByDominance(track, rng).id;

    // Mutation: try to jump to a non-parent pattern; bias toward checkered
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

  // ───────────────────────────────────────────────────────────
  // Cross-variant generation
  // ───────────────────────────────────────────────────────────

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
        spriteVariantData: p1.spriteData, // reuse sheet if you have recolors
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

  // ───────────────────────────────────────────────────────────
  // Family & element resolution
  // ───────────────────────────────────────────────────────────

  String _resolveChildFamily(String f1, String f2) {
    final key = FamilyRecipeConfig.keyOf(f1, f2);
    final recipe = familyRecipes.recipes[key];

    if (f1 == f2) {
      if (recipe != null && recipe.isNotEmpty) {
        _log(
          '[Breeding] StepF: explicit same-family override for $key → $recipe',
        );
        return _weightedPick(recipe);
      }
      final roll = _random.nextInt(100);
      _log(
        '[Breeding] StepF: same-family stickiness $f1: need <$_sameFamilyStickinessPct%, rolled=$roll → stay',
      );
      return f1; // stick by default
    }

    if (recipe != null && recipe.isNotEmpty) {
      _log('[Breeding] StepF: recipe($key) → $recipe');
      return _weightedPick(recipe);
    }

    _log('[Breeding] StepF: default 50/50 → {$f1:50, $f2:50}');
    return _weightedPick({f1: 50, f2: 50});
  }

  String _weightedPick(Map<String, int> weighted) {
    final total = weighted.values.fold<int>(0, (a, b) => a + b);
    int roll = _random.nextInt(total);
    _log('[Breeding]  → family roll: 0..${total - 1} = $roll');
    for (final e in weighted.entries) {
      roll -= e.value;
      if (roll < 0) {
        _log('[Breeding]  → family picked: ${e.key}');
        return e.key;
      }
    }
    return weighted.keys.first;
  }

  String _pickMutationFamily(String current) {
    final key = FamilyRecipeConfig.keyOf(current, current);
    final override = familyRecipes.recipes[key];
    if (override != null && override.isNotEmpty) {
      final filtered = Map<String, int>.fromEntries(
        override.entries.where((e) => e.key != current),
      );
      if (filtered.isNotEmpty) {
        return _weightedPick(filtered);
      }
    }

    final families = repository.creatures
        .map((c) => _familyOf(c))
        .where((f) => f != 'Unknown' && f != current)
        .toSet()
        .toList();
    if (families.isEmpty) return current;
    return families[_random.nextInt(families.length)];
  }

  String _resolveChildElement(
    String e1,
    String e2, {
    Creature? p1,
    Creature? p2,
  }) {
    final a = e1.trim();
    final b = e2.trim();
    final key = ElementRecipeConfig.keyOf(a, b);
    Map<String, int>? weighted = elementRecipes.recipes[key];

    if (weighted != null) {
      _log('[Breeding] Step4: recipe($key) → $weighted');
    } else {
      weighted = elementRecipes.recipes[a] ?? elementRecipes.recipes[b];
      if (weighted != null) {
        _log('[Breeding] Step4: single-element rule → $weighted');
      } else {
        weighted = {a: 50, b: 50};
        _log('[Breeding] Step4: default 50/50 → $weighted');
      }
    }

    // NEW: apply same-type nature bias (Homotypic/Heterotypic)
    if (p1 != null || p2 != null) {
      weighted = applyTypeNatureBias(weighted, p1, p2);
      _log('[Breeding] Step4: after nature type bias → $weighted');
    }

    final total = weighted.values.fold<int>(0, (x, y) => x + y);
    int roll = _random.nextInt(total);
    _log('[Breeding]  → element roll: 0..${total - 1} = $roll');
    for (final entry in weighted.entries) {
      if ((roll -= entry.value) < 0) {
        _log('[Breeding]  → element picked: ${entry.key}');
        return entry.key;
      }
    }
    return a;
  }

  // ───────────────────────────────────────────────────────────
  // Genetics
  // ───────────────────────────────────────────────────────────

  Map<String, int> _dominanceMap(GeneTrack track) {
    // Build a {variantId: dominance} map for convenience
    final m = <String, int>{};
    for (final v in track.variants) {
      m[v.id] = v.dominance;
    }
    return m;
  }

  Map<String, double> _applyTintBias({
    required Map<String, int>
    baseDom, // dominance weights (e.g., normal:6, cool:2…)
    required List<String> p1Types,
    required List<String> p2Types,
  }) {
    // Start with dominance-as-double
    final w = baseDom.map((k, v) => MapEntry(k, v.toDouble()));
    // Apply each parent's elemental multipliers
    for (final t in [...p1Types, ...p2Types]) {
      final b = tintBiasPerType[t];
      if (b == null) continue;
      b.forEach((variantId, mult) {
        w[variantId] = (w[variantId] ?? 0) * mult;
      });
    }
    // Safety: ensure "normal" exists
    w['normal'] = (w['normal'] ?? 0).clamp(0.01, double.infinity);
    return w;
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

          // extra stickiness at extremes + slight drift toward center
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
          // Same-variant stickiness (like your giant/tiny handling for blended)
          final bothSame = p1Var.id == p2Var.id;
          final bool stick =
              bothSame && rng.nextDouble() < 0.70; // 70% stickiness

          if (track.key == 'tinting') {
            // Build dominance map for this track
            final baseDom = _dominanceMap(track);

            // Elemental bias using parents' types (use first type if you want; here we use full list)
            final p1Types = p1.types;
            final p2Types = p2.types;

            // Apply bias → get a weighted pool
            final biased = _applyTintBias(
              baseDom: baseDom,
              p1Types: p1Types,
              p2Types: p2Types,
            );

            // If stickiness triggers, force parent tint (but still allow mutation later)
            String prelim = stick
                ? p1Var.id
                : _weightedPickFromMap(biased, rng);

            // Mutation override (your existing behavior): pick any non-normal randomly
            if (didMutate) {
              final pool = track.variants
                  .where((v) => v.id != 'normal')
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
            // Other weighted traits (no elemental bias, but keep same-variant stickiness)
            String prelim = stick
                ? p1Var.id
                : _weightedPickByDominance(track, rng).id;

            if (didMutate) {
              final pool = track.variants
                  .where((v) => v.id != 'normal')
                  .toList();
              if (pool.isNotEmpty) prelim = pool[rng.nextInt(pool.length)].id;
            }

            resultId = prelim;
          }
          break;
        case 'dominant_recessive':
          final dom = _dominantPick(p1Var, p2Var, rng).id;
          resultId = dom;
          break;

        default:
          resultId = _dominantPick(p1Var, p2Var, rng).id;
      }

      chosen[track.key] = resultId;
    }

    return child.copyWith(genetics: Genetics(chosen));
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

  // ───────────────────────────────────────────────────────────
  // Utilities
  // ───────────────────────────────────────────────────────────

  bool _roll(num pct) => _random.nextInt(100) < pct;

  Creature _fallbackAnyNonParent(Creature p1, Creature p2) {
    final any = repository.creatures
        .where((c) => c.id != p1.id && c.id != p2.id)
        .toList();
    return any[_random.nextInt(any.length)];
  }

  String _familyOf(Creature c) => (c.mutationFamily ?? 'Unknown');

  double _noise(Random r, double mean, double sigma) =>
      (r.nextDouble() * 2 - 1) * sigma + mean;

  String _defaultVariant(GeneTrack t) {
    final normal = t.variants.where((v) => v.id == 'normal');
    if (normal.isNotEmpty) return normal.first.id;
    return t.variants.reduce((a, b) => a.dominance >= b.dominance ? a : b).id;
  }

  GeneVariant _dominantPick(GeneVariant a, GeneVariant b, Random r) {
    if (a.dominance > b.dominance) return a;
    if (b.dominance > a.dominance) return b;
    return r.nextBool() ? a : b; // tie-break
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

  bool _withinOneRarity(String base, String candidate) {
    final i = _rarityOrder.indexOf(base);
    final j = _rarityOrder.indexOf(candidate);
    if (i < 0 || j < 0) return true; // permissive if unknown
    return (j - i).abs() <= 1;
  }

  String _higherRarity(String a, String b) =>
      (_rarityOrder.indexOf(a) >= _rarityOrder.indexOf(b)) ? a : b;

  bool _passesRequiredTypes(Creature c, Creature p1, Creature p2) {
    // Example: require at least one matching elemental type
    return c.types.any((t) => p1.types.contains(t) || p2.types.contains(t));
  }

  void _log(String s) {
    if (logToConsole) debugPrint(s);
  }
}

// ───────────────────────────────────────────────────────────
// Parent snapshot helper for DB instances
// ───────────────────────────────────────────────────────────

class ParentSnapshotFactory {
  static ParentSnapshot fromDbInstance(
    db.CreatureInstance inst,
    CreatureRepository repo,
  ) {
    final base = repo.getCreatureById(inst.baseId); // repo must be loaded
    if (base == null) {
      // Defensive fallback – shouldn’t happen if repo is loaded.
      return ParentSnapshot(
        instanceId: inst.instanceId,
        baseId: inst.baseId, // fallback to instance base ID
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
      instanceId: inst.instanceId, // instance ID for audit
      baseId: base.id, // base ID from catalog
      name: base.name, // name from catalog
      types: base.types, // from catalog
      rarity: base.rarity, // from catalog
      isPrismaticSkin: inst.isPrismaticSkin,
      genetics: genetics, // snapshot of instance genetics
      spriteData: base.spriteData, // for animated thumb (if any)
      image: base.image,
      nature: (inst.natureId != null)
          ? NatureCatalog.byId(inst.natureId!)
          : base.nature,
    );
  }
}

class BreedingResultWithStats {
  final Creature creature;
  final CreatureStats stats;

  BreedingResultWithStats({required this.creature, required this.stats});
}

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
