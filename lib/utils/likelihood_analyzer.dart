// lib/services/breeding_likelihood_analyzer.dart
//
// RUNTIME-AWARE VERSION
// This version does NOT try to guess odds from scratch.
// Instead, for each trait (family, element, tint, size, pattern, nature...)
// it asks the BreedingEngine for that trait's distribution and then
// reports the % chance of what actually happened.
//
// Result: tweak BreedingEngine math → UI updates automatically.

import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:flutter/material.dart';

enum Likelihood {
  improbable, // 0-15%
  unlikely, // 16-35%
  likely, // 36-65%
  probable, // 66-100%
}

enum BreedingType {
  sameSpecies, // p1.id == p2.id (pure lineage)
  crossSpecies, // p1.id != p2.id (hybrid)
}

class InheritanceMechanic {
  final String category; // e.g. "Family Lineage", "Elemental Type"
  final String result; // e.g. "Wing", "Lava", "Albino"
  final String mechanism; // human readable explanation
  final double percentage; // numeric likelihood (0-100)
  final Likelihood likelihood;

  const InheritanceMechanic({
    required this.category,
    required this.result,
    required this.mechanism,
    required this.percentage,
    required this.likelihood,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'result': result,
    'mechanism': mechanism,
    'percentage': percentage,
    'likelihood': likelihood.index,
  };
}

class BreedingAnalysisReport {
  final BreedingType breedingType;
  final String summaryLine;
  final List<InheritanceMechanic> inheritanceMechanics;
  final List<InheritanceMechanic> specialEvents;
  final String
  outcomeCategory; // "Expected", "Somewhat Unexpected", "Surprising", "Rare"
  final String outcomeExplanation; // why it got that label
  final double overallLikelihood; // rolled-together rough "how expected?"

  const BreedingAnalysisReport({
    required this.breedingType,
    required this.summaryLine,
    required this.inheritanceMechanics,
    required this.specialEvents,
    required this.outcomeCategory,
    required this.outcomeExplanation,
    required this.overallLikelihood,
  });

  Map<String, dynamic> toJson() => {
    'breedingType': breedingType.name,
    'summaryLine': summaryLine,
    'inheritanceMechanics': inheritanceMechanics
        .map((m) => m.toJson())
        .toList(),
    'specialEvents': specialEvents.map((m) => m.toJson()).toList(),
    'outcomeCategory': outcomeCategory,
    'outcomeExplanation': outcomeExplanation,
    'overallLikelihood': overallLikelihood,
  };
}

class BreedingLikelihoodAnalyzer {
  final CreatureCatalog repository;
  final ElementRecipeConfig elementRecipes;
  final FamilyRecipeConfig familyRecipes;

  final BreedingTuning tuning;

  // NEW: we inject the live engine so we can ask it for distributions
  final BreedingEngine engine;

  const BreedingLikelihoodAnalyzer({
    required this.repository,
    required this.elementRecipes,
    required this.familyRecipes,
    required this.engine,
    this.tuning = const BreedingTuning(),
  });

  /// Main entry point: Analyze already-produced offspring
  BreedingAnalysisReport analyzeBreedingResult(
    Creature p1,
    Creature p2,
    Creature offspring,
  ) {
    return _analyzeBreedingResultWithSnapshots(p1, p2, offspring);
  }

  BreedingAnalysisReport _analyzeBreedingResultWithSnapshots(
    Creature p1,
    Creature p2,
    Creature offspring, {
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final breedingType = (p1.id == p2.id)
        ? BreedingType.sameSpecies
        : BreedingType.crossSpecies;

    if (_usesRecipeDrivenSameSpeciesPath(p1, p2)) {
      return _analyzeRecipeDrivenSameSpeciesBreeding(
        p1,
        p2,
        offspring,
        parentA: parentA,
        parentB: parentB,
      );
    }

    if (breedingType == BreedingType.sameSpecies) {
      return _analyzeSameSpeciesBreeding(
        p1,
        p2,
        offspring,
        parentA: parentA,
        parentB: parentB,
      );
    } else {
      return _analyzeCrossSpeciesBreeding(
        p1,
        p2,
        offspring,
        parentA: parentA,
        parentB: parentB,
      );
    }
  }

  /// Analyze by DB instances (player-owned creatures)
  BreedingAnalysisReport analyzeInstanceBreedingResult(
    db.CreatureInstance a,
    db.CreatureInstance b,
    Creature offspring,
  ) {
    final baseA = repository.getCreatureById(a.baseId);
    final baseB = repository.getCreatureById(b.baseId);
    if (baseA == null || baseB == null) {
      return _emptyReport(offspring);
    }

    final p1 = _buildCreatureFromInstance(a, baseA);
    final p2 = _buildCreatureFromInstance(b, baseB);
    final snapA = ParentSnapshotFactory.fromDbInstance(a, repository);
    final snapB = ParentSnapshotFactory.fromDbInstance(b, repository);

    return _analyzeBreedingResultWithSnapshots(
      p1,
      p2,
      offspring,
      parentA: snapA,
      parentB: snapB,
    );
  }

  BreedingAnalysisReport _analyzeRecipeDrivenSameSpeciesBreeding(
    Creature p1,
    Creature p2,
    Creature baby, {
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final mechanics = <InheritanceMechanic>[];
    final specials = <InheritanceMechanic>[];
    final surprises = <String>[];

    final speciesPct = _crossSpeciesOutcomePct(
      p1: p1,
      p2: p2,
      baby: baby,
      parentA: parentA,
      parentB: parentB,
    );

    mechanics.add(
      InheritanceMechanic(
        category: 'Species',
        result: baby.name,
        mechanism: baby.id == p1.id
            ? 'Same-species Let breeding resolved back to the parent species'
            : 'Same-species Let breeding followed the normal recipe path',
        percentage: speciesPct,
        likelihood: _likelihoodFor(speciesPct),
      ),
    );

    if (speciesPct < 25.0) {
      surprises.add('Less common species outcome');
    }

    _appendFamilyMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
      parentA: parentA,
      parentB: parentB,
    );

    _appendElementMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
      parentA: parentA,
      parentB: parentB,
    );

    _appendGeneticMechanics(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    _appendNatureMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    _maybeAppendPrismatic(
      baby: baby,
      specialsOut: specials,
      surprisesOut: surprises,
    );

    _maybeAppendVariantFaction(
      baby: baby,
      specialsOut: specials,
      surprisesOut: surprises,
    );

    final outcomeCategory = _categorizeCrossSpeciesOutcome(
      surprises,
      mechanics,
      specials,
    );
    final outcomeExplanation = _explainCrossSpeciesOutcome(
      surprises,
      mechanics,
      specials,
    );

    return BreedingAnalysisReport(
      breedingType: BreedingType.sameSpecies,
      summaryLine:
          '${p1.name} × ${p2.name} → ${baby.name}: Same-species Let recipe path',
      inheritanceMechanics: mechanics,
      specialEvents: specials,
      outcomeCategory: outcomeCategory,
      outcomeExplanation: outcomeExplanation,
      overallLikelihood: _overallLikelihoodFromMechanics(mechanics),
    );
  }

  /// Analyze owned-instance x wild-catalog breeding using lineage snapshots.
  BreedingAnalysisReport analyzeWildBreedingResult(
    db.CreatureInstance owned,
    Creature wild,
    Creature offspring,
  ) {
    final ownedBase = repository.getCreatureById(owned.baseId);
    if (ownedBase == null) return _emptyReport(offspring);

    final p1 = _buildCreatureFromInstance(owned, ownedBase);
    final p2 = wild;
    final snapA = ParentSnapshotFactory.fromDbInstance(owned, repository);
    final snapB = ParentSnapshot.fromCreatureWithStats(wild, null);

    return _analyzeBreedingResultWithSnapshots(
      p1,
      p2,
      offspring,
      parentA: snapA,
      parentB: snapB,
    );
  }

  // ───────────────────────────────────────────────────────────
  // SAME-SPECIES ANALYSIS
  // ───────────────────────────────────────────────────────────

  BreedingAnalysisReport _analyzeSameSpeciesBreeding(
    Creature p1,
    Creature p2,
    Creature baby, {
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final mechanics = <InheritanceMechanic>[];
    final specials = <InheritanceMechanic>[];
    final surprises = <String>[];

    final speciesPct = _sameSpeciesSpeciesOutcomePct(
      p1: p1,
      p2: p2,
      baby: baby,
    );
    final sameSpeciesClone = baby.id == p1.id;

    // Species lock consistency
    mechanics.add(
      InheritanceMechanic(
        category: 'Species',
        result: baby.name,
        mechanism: sameSpeciesClone
            ? 'Same-species breeding stayed on the parent species path'
            : 'Global mutation overrode the normal same-species clone path',
        percentage: speciesPct,
        likelihood: _likelihoodFor(speciesPct),
      ),
    );

    if (speciesPct < 25.0) {
      surprises.add('Rare species mutation outcome');
    }

    // GENETICS (tint, size, pattern/etc)
    _appendGeneticMechanics(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    // ELEMENT (elemental type)
    _appendElementMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
      parentA: parentA,
      parentB: parentB,
    );

    // NATURE
    _appendNatureMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    // SPECIAL COSMETICS (prismatic)
    _maybeAppendPrismatic(
      baby: baby,
      specialsOut: specials,
      surprisesOut: surprises,
    );

    _maybeAppendVariantFaction(
      baby: baby,
      specialsOut: specials,
      surprisesOut: surprises,
    );

    // outcome label + explanation
    final outcomeCategory = _categorizeSameSpeciesOutcome(surprises);
    final outcomeExplanation = _explainSameSpeciesOutcome(surprises, mechanics);

    // simple "overall likelihood" = multiply key mechanic %s
    final overallLikelihood = _overallLikelihoodFromMechanics(mechanics);

    return BreedingAnalysisReport(
      breedingType: BreedingType.sameSpecies,
      summaryLine:
          '${p1.name} × ${p2.name} → ${baby.name}: '
          '${sameSpeciesClone ? "Pure lineage breeding" : "Global mutation event"}',
      inheritanceMechanics: mechanics,
      specialEvents: specials,
      outcomeCategory: outcomeCategory,
      outcomeExplanation: outcomeExplanation,
      overallLikelihood: overallLikelihood,
    );
  }

  // ───────────────────────────────────────────────────────────
  // CROSS-SPECIES ANALYSIS
  // ───────────────────────────────────────────────────────────

  BreedingAnalysisReport _analyzeCrossSpeciesBreeding(
    Creature p1,
    Creature p2,
    Creature baby, {
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final mechanics = <InheritanceMechanic>[];
    final specials = <InheritanceMechanic>[];
    final surprises = <String>[];

    _maybeAppendCrossVariant(p1: p1, p2: p2, baby: baby, specialsOut: specials);

    _maybeAppendParentRepeat(
      p1: p1,
      p2: p2,
      baby: baby,
      specialsOut: specials,
      parentA: parentA,
      parentB: parentB,
    );

    // FAMILY LINEAGE
    _appendFamilyMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
      parentA: parentA,
      parentB: parentB,
    );

    // ELEMENTAL TYPE
    _appendElementMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
      parentA: parentA,
      parentB: parentB,
    );

    // GENETICS (tint, size, pattern/etc)
    _appendGeneticMechanics(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    // NATURE
    _appendNatureMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    // PRISMATIC
    _maybeAppendPrismatic(
      baby: baby,
      specialsOut: specials,
      surprisesOut: surprises,
    );

    _maybeAppendVariantFaction(
      baby: baby,
      specialsOut: specials,
      surprisesOut: surprises,
    );

    // Categorize
    final outcomeCategory = _categorizeCrossSpeciesOutcome(
      surprises,
      mechanics,
      specials,
    );
    final outcomeExplanation = _explainCrossSpeciesOutcome(
      surprises,
      mechanics,
      specials,
    );

    // Overall "how expected"
    final overallLikelihood = _overallLikelihoodFromMechanics(mechanics);

    return BreedingAnalysisReport(
      breedingType: BreedingType.crossSpecies,
      summaryLine:
          '${p1.name} × ${p2.name} → ${baby.name}: ${_getBreedingSummary(p1, p2, baby)}',
      inheritanceMechanics: mechanics,
      specialEvents: specials,
      outcomeCategory: outcomeCategory,
      outcomeExplanation: outcomeExplanation,
      overallLikelihood: overallLikelihood,
    );
  }

  // ───────────────────────────────────────────────────────────
  // MECHANIC BUILDERS (these now ask the engine)
  // ───────────────────────────────────────────────────────────

  void _appendFamilyMechanic({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    required List<InheritanceMechanic> mechanicsOut,
    required List<String> surprisesOut,
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final babyFamily = baby.mutationFamily ?? 'Unknown';

    final familyDist = (parentA != null && parentB != null)
        ? engine.getLineageAwareFamilyDistribution(p1, p2, parentA, parentB)
        : engine.getBiasedFamilyDistribution(p1, p2);

    // normalize to 0-100
    final familyPctMap = familyDist.asPercentages();
    final pct = familyPctMap[babyFamily] ?? 0.0;

    mechanicsOut.add(
      InheritanceMechanic(
        category: 'Family Lineage',
        result: babyFamily,
        mechanism: _describeFamilyMechanism(p1, p2, babyFamily),
        percentage: pct,
        likelihood: _likelihoodFor(pct),
      ),
    );

    if (pct < 25.0) {
      surprisesOut.add('Less common family outcome');
    }
  }

  void _appendElementMechanic({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    required List<InheritanceMechanic> mechanicsOut,
    required List<String> surprisesOut,
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final babyElem = baby.types.isNotEmpty ? baby.types.first : 'Unknown';

    final elemDist = (parentA != null && parentB != null)
        ? engine.getLineageAwareElementDistribution(p1, p2, parentA, parentB)
        : engine.getBiasedElementDistribution(p1, p2);
    final elemPctMap = elemDist.asPercentages();

    debugPrint(
      '[Analyzer] Element baby=${baby.name} '
      'id=${baby.id} elem=$babyElem',
    );
    debugPrint('[Analyzer] Element dist = $elemPctMap');

    final pct = elemPctMap[babyElem] ?? 0.0;

    mechanicsOut.add(
      InheritanceMechanic(
        category: 'Elemental Type',
        result: babyElem,
        mechanism: _describeElementMechanism(p1, p2, babyElem),
        percentage: pct,
        likelihood: _likelihoodFor(pct),
      ),
    );

    if (pct < 25.0) {
      surprisesOut.add('Uncommon elemental outcome');
    }
  }

  void _appendGeneticMechanics({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    required List<InheritanceMechanic> mechanicsOut,
    required List<String> surprisesOut,
  }) {
    final g = baby.genetics;
    if (g == null) return;

    // TINTING
    {
      final childTint = g.get('tinting') ?? 'normal';

      final tintDist = engine.getTintDistribution(p1, p2);
      final tintPctMap = tintDist.asPercentages();
      final tintPct = tintPctMap[childTint] ?? 0.0;

      mechanicsOut.add(
        InheritanceMechanic(
          category: 'Color Tinting',
          result: _prettyName(childTint),
          mechanism: _describeTintMechanism(p1, p2, childTint),
          percentage: tintPct,
          likelihood: _likelihoodFor(tintPct),
        ),
      );

      if (tintPct < 15.0) {
        surprisesOut.add('Rare color tint outcome');
      }
    }

    // SIZE
    {
      final childSize = g.get('size') ?? 'normal';

      final sizeDist = engine.getSizeDistribution(p1, p2);
      final sizePctMap = sizeDist.asPercentages();
      final sizePct = sizePctMap[childSize] ?? 0.0;

      mechanicsOut.add(
        InheritanceMechanic(
          category: 'Size',
          result: _prettyName(childSize),
          mechanism: _describeSizeMechanism(p1, p2, childSize),
          percentage: sizePct,
          likelihood: _likelihoodFor(sizePct),
        ),
      );

      if (sizePct < 20.0) {
        surprisesOut.add('Unusual size inheritance');
      }
    }

    // PATTERNING (optional)
    {
      final childPattern = g.get('patterning');
      if (childPattern != null) {
        final patternDist = engine.getPatternDistribution(p1, p2);
        final patternPctMap = patternDist.asPercentages();
        final patPct = patternPctMap[childPattern] ?? 0.0;

        mechanicsOut.add(
          InheritanceMechanic(
            category: 'Patterning',
            result: _prettyName(childPattern),
            mechanism: _describePatternMechanism(p1, p2, childPattern),
            percentage: patPct,
            likelihood: _likelihoodFor(patPct),
          ),
        );

        if (patPct < 10.0) {
          surprisesOut.add('Rare pattern recombination');
        }
      }
    }
  }

  void _appendNatureMechanic({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    required List<InheritanceMechanic> mechanicsOut,
    required List<String> surprisesOut,
  }) {
    final childNature = baby.nature;
    if (childNature == null) return;

    final natureDist = engine.getNatureDistribution(p1, p2);
    final naturePctMap = natureDist.asPercentages();
    final pct = naturePctMap[childNature.id] ?? 0.0;

    mechanicsOut.add(
      InheritanceMechanic(
        category: 'Nature',
        result: childNature.id,
        mechanism: _describeNatureMechanism(p1, p2, childNature.id),
        percentage: pct,
        likelihood: _likelihoodFor(pct),
      ),
    );

    if (pct < 20.0) {
      surprisesOut.add('Unexpected nature outcome');
    }
  }

  void _maybeAppendPrismatic({
    required Creature baby,
    required List<InheritanceMechanic> specialsOut,
    required List<String> surprisesOut,
  }) {
    if (baby.isPrismaticSkin == true) {
      final prismaticPct = tuning.prismaticSkinChance * 100.0;
      specialsOut.add(
        InheritanceMechanic(
          category: 'Cosmetic Mutation',
          result: 'Prismatic Skin',
          mechanism:
              '${prismaticPct.toStringAsFixed(1)}% spontaneous visual mutation',
          percentage: prismaticPct,
          likelihood: _likelihoodFor(prismaticPct),
        ),
      );
      surprisesOut.add('Prismatic skin mutation');
    }
  }

  void _maybeAppendVariantFaction({
    required Creature baby,
    required List<InheritanceMechanic> specialsOut,
    required List<String> surprisesOut,
  }) {
    final odds = engine.computeVariantFactionOdds(child: baby);
    if (odds == null) return;

    final pct = odds.pickedFactionPct;
    final factionId = odds.pickedFactionId;
    final depth = baby.lineageData?.generationDepth ?? 0;

    specialsOut.add(
      InheritanceMechanic(
        category: 'Lineage Variant',
        result: factionId,
        mechanism:
            '${pct.toStringAsFixed(2)}% chance to express ancestral faction bloodline (depth $depth)',
        percentage: pct,
        likelihood: _likelihoodFor(pct),
      ),
    );

    if (pct < 10.0) {
      surprisesOut.add('Bloodline variant expression');
    }
  }

  void _maybeAppendCrossVariant({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    required List<InheritanceMechanic> specialsOut,
  }) {
    // heuristic: "variant" child from cross typing.
    // We can't 100% detect with no flag, so here's a rule:
    final looksVariant = baby.id.contains('_variant_');
    final t1 = p1.types.isNotEmpty ? p1.types.first : null;
    final t2 = p2.types.isNotEmpty ? p2.types.first : null;
    final canMakeVariant =
        (t1 != null && p1.variantTypes.contains(t2)) ||
        (t2 != null && p2.variantTypes.contains(t1));

    if (looksVariant && canMakeVariant) {
      final pct = tuning.variantChanceCross.toDouble();
      specialsOut.add(
        InheritanceMechanic(
          category: 'Cross-Variant',
          result: 'Generated ${baby.name}',
          mechanism:
              'Cross-type variant emerged (${pct.toStringAsFixed(1)}% chance)',
          percentage: pct,
          likelihood: _likelihoodFor(pct),
        ),
      );
    }
  }

  void _maybeAppendParentRepeat({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    required List<InheritanceMechanic> specialsOut,
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    // engine logic: sometimes we just "return one of the parents"
    final isParentRepeat = (baby.id == p1.id || baby.id == p2.id);
    if (!isParentRepeat) return;

    final pct = _crossSpeciesOutcomePct(
      p1: p1,
      p2: p2,
      baby: baby,
      parentA: parentA,
      parentB: parentB,
    );

    specialsOut.add(
      InheritanceMechanic(
        category: 'Parent Species Repeat',
        result: baby.name,
        mechanism:
            'Offspring matched a parent species via hybrid selection or fallback (${pct.toStringAsFixed(1)}% chance)',
        percentage: pct,
        likelihood: _likelihoodFor(pct),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // TEXT HELPERS (non-probability explanations only)
  // ───────────────────────────────────────────────────────────

  String _describeFamilyMechanism(Creature p1, Creature p2, String babyFamily) {
    final f1 = p1.mutationFamily ?? 'Unknown';
    final f2 = p2.mutationFamily ?? 'Unknown';

    if (f1 == f2) {
      if (babyFamily == f1) {
        return 'Both parents share $f1 lineage → high inheritance stability';
      } else {
        return 'Family mutation occurred despite shared lineage';
      }
    }

    // hybrid
    return 'Hybridization of $f1 × $f2 produced $babyFamily';
  }

  String _describeElementMechanism(Creature p1, Creature p2, String babyElem) {
    final t1 = p1.types.isNotEmpty ? p1.types.first : 'Unknown';
    final t2 = p2.types.isNotEmpty ? p2.types.first : 'Unknown';

    if (t1 == t2 && babyElem == t1) {
      return 'Both parents share $t1 element → direct inheritance';
    }

    if (babyElem == t1) {
      return 'Inherited elemental type from parent 1 ($t1)';
    }
    if (babyElem == t2) {
      return 'Inherited elemental type from parent 2 ($t2)';
    }

    return '$t1 + $t2 combined into $babyElem via elemental fusion';
  }

  String _describeTintMechanism(Creature p1, Creature p2, String tint) {
    final p1Tint = p1.genetics?.get('tinting') ?? 'normal';
    final p2Tint = p2.genetics?.get('tinting') ?? 'normal';

    if (p1Tint == p2Tint && tint == p1Tint) {
      return 'Both parents shared this coloration';
    }

    // else talking weighted bias:
    final types = {...p1.types, ...p2.types}.join('/');
    return 'Coloration weighted by dominance and $types elemental bias';
  }

  String _describeSizeMechanism(Creature p1, Creature p2, String size) {
    final s1 = p1.genetics?.get('size') ?? 'normal';
    final s2 = p2.genetics?.get('size') ?? 'normal';

    if (s1 == 'giant' && s2 == 'giant') {
      if (size == 'giant') {
        return 'Extreme size lock-in from both giant parents';
      }
      return 'Size drifted toward midpoint despite both parents being giant';
    }
    if (s1 == 'tiny' && s2 == 'tiny') {
      if (size == 'tiny') return 'Extreme size lock-in from both tiny parents';
      return 'Size drifted toward midpoint despite both parents being tiny';
    }

    return 'Blended physical scale from parental averages';
  }

  String _describePatternMechanism(Creature p1, Creature p2, String pattern) {
    final pa = p1.genetics?.get('patterning') ?? 'normal';
    final pb = p2.genetics?.get('patterning') ?? 'normal';

    if (pa == pb && pattern == pa) {
      return 'Both parents shared this pattern → sticky inheritance';
    }

    final pair = {pa, pb};
    if (pair.contains('spots') &&
        pair.contains('stripes') &&
        pattern == 'checkered') {
      return 'Recombination event: spots + stripes → checkered pattern';
    }

    return 'Pattern was dominance-weighted and may include mutation drift';
  }

  String _describeNatureMechanism(Creature p1, Creature p2, String natureId) {
    final n1 = p1.nature?.id;
    final n2 = p2.nature?.id;

    if (n1 != null && n1 == n2 && natureId == n1) {
      return 'Inherited parents nature with strong likelihood';
    }

    if (natureId == n1 || natureId == n2) {
      return 'Inherited a parent nature';
    }

    return 'Random nature mutated';
  }

  // ───────────────────────────────────────────────────────────
  // OUTCOME SUMMARIES / CATEGORIZATION
  // ───────────────────────────────────────────────────────────

  String _categorizeSameSpeciesOutcome(List<String> surprises) {
    if (surprises.length >= 2) return 'Surprising';
    if (surprises.length == 1) return 'Somewhat Unexpected';
    return 'Expected';
  }

  String _explainSameSpeciesOutcome(
    List<String> surprises,
    List<InheritanceMechanic> mechanics,
  ) {
    if (surprises.isEmpty) {
      return 'All traits followed normal same-species inheritance.';
    }

    final rareBits = mechanics
        .where((m) => m.percentage < 30.0)
        .map(
          (m) =>
              '${m.category}: ${m.result} (${m.percentage.toStringAsFixed(1)}%)',
        )
        .join(', ');

    if (rareBits.isNotEmpty) {
      return 'Less common outcomes occurred: $rareBits';
    }

    return 'Genetic variation appeared but within acceptable range.';
  }

  String _categorizeCrossSpeciesOutcome(
    List<String> surprises,
    List<InheritanceMechanic> mechanics,
    List<InheritanceMechanic> specials,
  ) {
    // any special with <20% chance pushes us toward "Rare"
    final hasVeryLowSpecial = specials.any((s) => s.percentage < 20.0);
    if (hasVeryLowSpecial) return 'Rare';

    // more than one mechanic under 15% also counts as rare weird stuff
    final ultraRares = mechanics.where((m) => m.percentage < 15.0).length;
    if (ultraRares >= 2) return 'Rare';

    if (surprises.length >= 3) return 'Surprising';
    if (surprises.isNotEmpty) return 'Somewhat Unexpected';
    return 'Expected';
  }

  String _explainCrossSpeciesOutcome(
    List<String> surprises,
    List<InheritanceMechanic> mechanics,
    List<InheritanceMechanic> specials,
  ) {
    final lowChanceMechanics = _lessLikelyMechanics(mechanics);

    if (lowChanceMechanics.isEmpty && surprises.isEmpty && specials.isEmpty) {
      return 'All inheritance followed expected hybridization rules.';
    }

    final parts = <String>[];

    if (lowChanceMechanics.isNotEmpty) {
      final mechList = lowChanceMechanics
          .map(
            (m) =>
                '${m.category}: ${m.result} (${m.percentage.toStringAsFixed(1)}%)',
          )
          .join(', ');
      parts.add('Less likely outcomes: $mechList');
    }

    return parts.join('. ');
  }

  String _getBreedingSummary(Creature p1, Creature p2, Creature baby) {
    final f1 = p1.mutationFamily ?? 'Unknown';
    final f2 = p2.mutationFamily ?? 'Unknown';
    final cf = baby.mutationFamily ?? 'Unknown';

    if (f1 == f2 && f1 == cf) {
      return 'Family lineage maintained';
    } else if (f1 == f2 && f1 != cf) {
      return 'Family mutation occurred';
    } else {
      return 'Hybrid cross';
    }
  }

  // ───────────────────────────────────────────────────────────
  // MATH HELPERS
  // ───────────────────────────────────────────────────────────

  Likelihood _likelihoodFor(double pct) {
    if (pct >= 66) return Likelihood.probable;
    if (pct >= 36) return Likelihood.likely;
    if (pct >= 16) return Likelihood.unlikely;
    return Likelihood.improbable;
  }

  double _overallLikelihoodFromMechanics(List<InheritanceMechanic> mechanics) {
    // We'll consider only the "core" mechanics in this score, not cosmetics.
    final core = mechanics.where((m) {
      return m.category == 'Family Lineage' ||
          m.category == 'Elemental Type' ||
          m.category == 'Species';
    }).toList();

    if (core.isEmpty) return 100.0;

    // geometric-ish mean
    final product = core.fold<double>(
      1.0,
      (acc, m) => acc * (m.percentage / 100.0),
    );
    return (math.pow(product, 1.0 / core.length) * 100).toDouble();
  }

  double _sameSpeciesSpeciesOutcomePct({
    required Creature p1,
    required Creature p2,
    required Creature baby,
  }) {
    final mutationPct = tuning.globalMutationChance.toDouble().clamp(
      0.0,
      100.0,
    );
    final mutationCandidates = _globalMutationCandidatesFor(p1, p2);

    // If mutation path cannot produce anything, species is always the same.
    if (mutationCandidates.isEmpty) {
      return (baby.id == p1.id) ? 100.0 : 0.0;
    }

    final nonMutationPct = 100.0 - mutationPct;
    final nonMutationShare = (baby.id == p1.id) ? 1.0 : 0.0;

    final mutationMatches = mutationCandidates
        .where((c) => c.id == baby.id)
        .length;
    final mutationShare = mutationMatches / mutationCandidates.length;

    final pct =
        (nonMutationPct * nonMutationShare) + (mutationPct * mutationShare);
    return pct.clamp(0.0, 100.0);
  }

  double _crossSpeciesOutcomePct({
    required Creature p1,
    required Creature p2,
    required Creature baby,
    ParentSnapshot? parentA,
    ParentSnapshot? parentB,
  }) {
    final mutationChance =
        tuning.globalMutationChance.toDouble().clamp(0.0, 100.0) / 100.0;
    final mutationCandidates = _globalMutationCandidatesFor(p1, p2);
    final mutationMatches = mutationCandidates
        .where((c) => c.id == baby.id)
        .length;

    final mutationShare = mutationCandidates.isEmpty
        ? 0.0
        : (mutationMatches / mutationCandidates.length);

    final famDist = (parentA != null && parentB != null)
        ? engine.getLineageAwareFamilyDistribution(p1, p2, parentA, parentB)
        : engine.getBiasedFamilyDistribution(p1, p2);
    final elemDist = (parentA != null && parentB != null)
        ? engine.getLineageAwareElementDistribution(p1, p2, parentA, parentB)
        : engine.getBiasedElementDistribution(p1, p2);

    final familyProb = famDist.asPercentages().map(
      (k, v) => MapEntry(k, (v / 100.0).clamp(0.0, 1.0)),
    );
    final elemProb = elemDist.asPercentages().map(
      (k, v) => MapEntry(k, (v / 100.0).clamp(0.0, 1.0)),
    );

    final fam1 = p1.mutationFamily ?? 'Unknown';
    final fam2 = p2.mutationFamily ?? 'Unknown';
    final higherParentRarity = _higherRarityLabel(p1.rarity, p2.rarity);

    double nonMutationShare = 0.0;

    for (final fe in familyProb.entries) {
      if (fe.value <= 0.0) continue;
      for (final ee in elemProb.entries) {
        if (ee.value <= 0.0) continue;

        final branchShare = fe.value * ee.value;

        final pool = repository.creatures
            .where((c) {
              if ((c.mutationFamily ?? 'Unknown') != fe.key) return false;
              if (c.types.isEmpty || c.types.first != ee.key) return false;
              return true;
            })
            .toList(growable: false);

        if (pool.isEmpty) {
          if (baby.id == p1.id || baby.id == p2.id) {
            nonMutationShare += branchShare * 0.5;
          }
          continue;
        }

        final pref = pool
            .where((c) => _withinOneRarityLabel(higherParentRarity, c.rarity))
            .toList(growable: false);
        final sel = pref.isNotEmpty ? pref : pool;

        double totalWeight = 0.0;
        double matchWeight = 0.0;

        for (final c in sel) {
          final w =
              ((c.mutationFamily ?? 'Unknown') == fam1 ||
                  (c.mutationFamily ?? 'Unknown') == fam2)
              ? 3.0
              : 1.0;
          totalWeight += w;
          if (c.id == baby.id) {
            matchWeight += w;
          }
        }

        if (totalWeight > 0.0 && matchWeight > 0.0) {
          nonMutationShare += branchShare * (matchWeight / totalWeight);
        }
      }
    }

    final totalShare =
        (mutationChance * mutationShare) +
        ((1.0 - mutationChance) * nonMutationShare);
    return (totalShare * 100.0).clamp(0.0, 100.0);
  }

  List<Creature> _globalMutationCandidatesFor(Creature p1, Creature p2) {
    String nextRarity(String rarity) {
      const tiers = ['Common', 'Uncommon', 'Rare', 'Legendary'];
      final i = tiers.indexOf(rarity);
      if (i < 0 || i >= tiers.length - 1) return rarity;
      return tiers[i + 1];
    }

    final parentTopRarity = (_rarityRank(p1.rarity) >= _rarityRank(p2.rarity))
        ? p1.rarity
        : p2.rarity;
    final targetRarity = nextRarity(parentTopRarity);

    final elem1 = p1.types.isNotEmpty ? p1.types.first : null;
    final elem2 = p2.types.isNotEmpty ? p2.types.first : null;
    if (elem1 == null && elem2 == null) return const [];

    final elementSet = <String>{};
    if (elem1 != null) elementSet.add(elem1);
    if (elem2 != null) elementSet.add(elem2);

    final fusionKey = ElementRecipeConfig.keyOf(elem1 ?? '', elem2 ?? '');
    final fusionRecipe = elementRecipes.recipes[fusionKey];
    if (fusionRecipe != null) {
      elementSet.addAll(fusionRecipe.keys);
    }

    final parentsBothMystic =
        ((p1.mutationFamily ?? 'Unknown') == 'Mystic' &&
        (p2.mutationFamily ?? 'Unknown') == 'Mystic');

    return repository.creatures
        .where((c) {
          final primary = c.types.isNotEmpty ? c.types.first : null;
          if (primary == null) return false;
          if (!parentsBothMystic && c.mutationFamily == 'Mystic') return false;
          return elementSet.contains(primary) && c.rarity == targetRarity;
        })
        .toList(growable: false);
  }

  bool _usesRecipeDrivenSameSpeciesPath(Creature p1, Creature p2) {
    final fam1 = p1.mutationFamily ?? 'Unknown';
    final fam2 = p2.mutationFamily ?? 'Unknown';
    return p1.id == p2.id && fam1 == 'Let' && fam2 == 'Let';
  }

  int _rarityRank(String rarity) {
    const order = {'Common': 0, 'Uncommon': 1, 'Rare': 2, 'Legendary': 3};
    return order[rarity] ?? 0;
  }

  String _higherRarityLabel(String a, String b) =>
      (_rarityRank(a) >= _rarityRank(b)) ? a : b;

  bool _withinOneRarityLabel(String base, String candidate) {
    final i = _rarityRank(base);
    final j = _rarityRank(candidate);
    if (i < 0 || j < 0) return true;
    return (j - i).abs() <= 1;
  }

  List<InheritanceMechanic> _lessLikelyMechanics(
    List<InheritanceMechanic> mechanics,
  ) {
    // group by category
    final byCategory = <String, List<InheritanceMechanic>>{};
    for (final m in mechanics) {
      byCategory.putIfAbsent(m.category, () => []).add(m);
    }

    final result = <InheritanceMechanic>[];

    for (final entry in byCategory.entries) {
      final bucket = entry.value;
      final bestPct = bucket
          .map((m) => m.percentage)
          .fold<double>(0, (a, b) => a > b ? a : b);

      final multipleOptionsInThisCategory = bucket.length > 1;

      for (final m in bucket) {
        final isCategoryLeader =
            (m.percentage + 0.0001) >= bestPct; // "tied for best"
        final isSuperLow = m.percentage < 10.0; // you can tune this

        // Rule:
        // - if there were multiple options in this category:
        //     only call out the NOT-best ones that are super low
        // - if there was only one option in this category:
        //     call it out if it's super low anyway (2%, 4%, etc.)
        final shouldFlag = multipleOptionsInThisCategory
            ? (!isCategoryLeader && isSuperLow)
            : isSuperLow;

        if (shouldFlag) {
          result.add(m);
        }
      }
    }

    return result;
  }

  // ───────────────────────────────────────────────────────────
  // INSTANCE RECONSTRUCTION / FALLBACKS
  // ───────────────────────────────────────────────────────────

  BreedingAnalysisReport _emptyReport(Creature baby) {
    return BreedingAnalysisReport(
      breedingType: BreedingType.crossSpecies,
      summaryLine: 'Unable to analyze breeding',
      inheritanceMechanics: [],
      specialEvents: [],
      outcomeCategory: 'Unknown',
      outcomeExplanation: 'Missing parent data',
      overallLikelihood: 0.0,
    );
  }

  Creature _buildCreatureFromInstance(db.CreatureInstance row, Creature base) {
    final genetics = _decodeGenetics(row.geneticsJson);
    final nature = (row.natureId != null)
        ? NatureCatalog.byId(row.natureId!)
        : base.nature;

    return base.copyWith(
      genetics: genetics ?? base.genetics,
      nature: nature,
      isPrismaticSkin: row.isPrismaticSkin || base.isPrismaticSkin,
    );
  }

  Genetics? _decodeGenetics(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final map = decoded.map((k, v) => MapEntry(k, v.toString()));
      return Genetics(map);
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  // MISC SMALL HELPERS
  // ───────────────────────────────────────────────────────────

  String _prettyName(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

// Extension for UI badges/emoji
extension LikelihoodDisplay on Likelihood {
  String get displayName {
    switch (this) {
      case Likelihood.improbable:
        return 'Improbable';
      case Likelihood.unlikely:
        return 'Unlikely';
      case Likelihood.likely:
        return 'Likely';
      case Likelihood.probable:
        return 'Probable';
    }
  }
}
