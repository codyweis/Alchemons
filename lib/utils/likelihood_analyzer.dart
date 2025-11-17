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
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/genetics.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/utils/nature_utils.dart';
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
    final breedingType = (p1.id == p2.id)
        ? BreedingType.sameSpecies
        : BreedingType.crossSpecies;

    if (breedingType == BreedingType.sameSpecies) {
      return _analyzeSameSpeciesBreeding(p1, p2, offspring);
    } else {
      return _analyzeCrossSpeciesBreeding(p1, p2, offspring);
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
    return analyzeBreedingResult(p1, p2, offspring);
  }

  // ───────────────────────────────────────────────────────────
  // SAME-SPECIES ANALYSIS
  // ───────────────────────────────────────────────────────────

  BreedingAnalysisReport _analyzeSameSpeciesBreeding(
    Creature p1,
    Creature p2,
    Creature baby,
  ) {
    final mechanics = <InheritanceMechanic>[];
    final specials = <InheritanceMechanic>[];
    final surprises = <String>[];

    final normalPathPct = (100.0 - tuning.globalMutationChance.toDouble())
        .clamp(0.0, 100.0);

    // Species lock consistency
    mechanics.add(
      InheritanceMechanic(
        category: 'Species',
        result: baby.name,
        mechanism: 'Same-species breeding tends to reproduce the same species',
        percentage: normalPathPct,
        likelihood: Likelihood.probable,
      ),
    );

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
          '${p1.name} × ${p2.name} → ${baby.name}: Pure lineage breeding',
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
    Creature baby,
  ) {
    final mechanics = <InheritanceMechanic>[];
    final specials = <InheritanceMechanic>[];
    final surprises = <String>[];

    _maybeAppendCrossVariant(p1: p1, p2: p2, baby: baby, specialsOut: specials);

    _maybeAppendParentRepeat(p1: p1, p2: p2, baby: baby, specialsOut: specials);

    // FAMILY LINEAGE
    _appendFamilyMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
    );

    // ELEMENTAL TYPE
    _appendElementMechanic(
      p1: p1,
      p2: p2,
      baby: baby,
      mechanicsOut: mechanics,
      surprisesOut: surprises,
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
  }) {
    final babyFamily = baby.mutationFamily ?? 'Unknown';

    // ask engine for distribution
    final familyDist = engine.getBiasedFamilyDistribution(p1, p2);

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
  }) {
    final babyElem = baby.types.isNotEmpty ? baby.types.first : 'Unknown';

    final elemDist = engine.getBiasedElementDistribution(p1, p2);
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
  }) {
    // engine logic: sometimes we just "return one of the parents"
    final isParentRepeat = (baby.id == p1.id || baby.id == p2.id);
    if (!isParentRepeat) return;

    // replicate the math the engine uses so analyzer doesn't get out of sync:
    final basePr = tuning.parentRepeatChance;
    final prMult = combinedNatureMult(p1, p2, 'breed_same_species_chance_mult');
    final pr = (basePr * prMult).clamp(0, 100);

    specialsOut.add(
      InheritanceMechanic(
        category: 'Parent Species Repeat',
        result: baby.name,
        mechanism:
            'Offspring reverted to parent species (${pr.toStringAsFixed(1)}% chance, nature-modified)',
        percentage: pr.toDouble(),
        likelihood: _likelihoodFor(pr.toDouble()),
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
      if (size == 'giant')
        return 'Extreme size lock-in from both giant parents';
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
    // guaranteed pair always "Expected" regardless of rarity
    final hasGuaranteed = specials.any((s) => s.category == 'Guaranteed Pair');
    if (hasGuaranteed) return 'Expected';

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
    final hasGuaranteed = specials.any((s) => s.category == 'Guaranteed Pair');
    if (hasGuaranteed) {
      return 'Special breeding pair produced a predetermined result.';
    }

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
      isPrismaticSkin: row.isPrismaticSkin || (base.isPrismaticSkin ?? false),
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
