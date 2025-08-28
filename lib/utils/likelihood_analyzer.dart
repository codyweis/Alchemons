// lib/services/breeding_likelihood_analyzer.dart
//
// Analyzes breeding combinations to predict likelihood of various traits
// in offspring based on parent genetics, natures, families, and types.
// Also supports scoring an actual offspring against those predictions.

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

enum Likelihood {
  improbable, // 0-15%
  unlikely, // 16-35%
  likely, // 36-65%
  probable, // 66-100%
}

class LikelihoodResult {
  final String trait;
  final String value;
  final Likelihood likelihood;
  final double percentage;
  final String description;

  Map<String, dynamic> toJson() => {
    'trait': trait,
    'value': value,
    'likelihood': likelihood.index,
    'percentage': percentage,
    'description': description,
  };

  const LikelihoodResult({
    required this.trait,
    required this.value,
    required this.likelihood,
    required this.percentage,
    required this.description,
  });
}

class OffspringLikelihoodSummary {
  final Map<String, double>
  perTraitPct; // e.g. {'Color Tint': 42.1, 'Size': 28.0, ...}
  final double jointPct; // combined probability across considered traits
  final Likelihood overall; // mapped from jointPct
  final List<LikelihoodResult> matched; // matched results per trait (if any)

  const OffspringLikelihoodSummary({
    required this.perTraitPct,
    required this.jointPct,
    required this.overall,
    required this.matched,
  });

  Map<String, dynamic> toJson() => {
    'perTraitPct': perTraitPct,
    'jointPct': jointPct,
    'overall': overall.index,
    'matched': matched.map((r) => r.toJson()).toList(),
  };
}

class BreedingLikelihoodAnalysis {
  final List<LikelihoodResult> colorResults;
  final List<LikelihoodResult> sizeResults;
  final List<LikelihoodResult> natureResults;
  final List<LikelihoodResult> typeResults;
  final List<LikelihoodResult> familyResults;
  final List<LikelihoodResult> specialResults;

  /// If provided, this summarizes how likely the actual offspring was,
  /// given the distributions above.
  final OffspringLikelihoodSummary? outcome;

  const BreedingLikelihoodAnalysis({
    required this.colorResults,
    required this.sizeResults,
    required this.natureResults,
    required this.typeResults,
    required this.familyResults,
    required this.specialResults,
    this.outcome,
  });

  List<LikelihoodResult> get allResults => [
    ...colorResults,
    ...sizeResults,
    ...natureResults,
    ...typeResults,
    ...familyResults,
    ...specialResults,
  ];

  BreedingLikelihoodAnalysis copyWithOutcome(
    OffspringLikelihoodSummary summary,
  ) {
    return BreedingLikelihoodAnalysis(
      colorResults: colorResults,
      sizeResults: sizeResults,
      natureResults: natureResults,
      typeResults: typeResults,
      familyResults: familyResults,
      specialResults: specialResults,
      outcome: summary,
    );
  }

  Map<String, dynamic> toJson() => {
    'colorResults': colorResults.map((r) => (r).toJson()).toList(),
    'sizeResults': sizeResults.map((r) => (r).toJson()).toList(),
    'natureResults': natureResults.map((r) => (r).toJson()).toList(),
    'typeResults': typeResults.map((r) => (r).toJson()).toList(),
    'familyResults': familyResults.map((r) => (r).toJson()).toList(),
    'specialResults': specialResults.map((r) => (r).toJson()).toList(),
    'outcome': outcome?.toJson(),
  };
}

class BreedingLikelihoodAnalyzer {
  final CreatureRepository repository;
  final ElementRecipeConfig elementRecipes;
  final FamilyRecipeConfig familyRecipes;
  final SpecialRulesConfig specialRules;
  final BreedingTuning tuning;

  const BreedingLikelihoodAnalyzer({
    required this.repository,
    required this.elementRecipes,
    required this.familyRecipes,
    required this.specialRules,
    this.tuning = const BreedingTuning(),
  });

  // Tint bias mapping from your breeding engine
  static const Map<String, Map<String, double>> tintBiasPerType = {
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

  /// Analyze breeding between two creature instances (distribution only)
  BreedingLikelihoodAnalysis analyzeInstanceBreeding(
    db.CreatureInstance a,
    db.CreatureInstance b,
  ) {
    final baseA = repository.getCreatureById(a.baseId);
    final baseB = repository.getCreatureById(b.baseId);

    if (baseA == null || baseB == null) {
      return _emptyAnalysis();
    }

    final parentA = _buildCreatureFromInstance(a, baseA);
    final parentB = _buildCreatureFromInstance(b, baseB);

    return _analyzeBreeding(parentA, parentB);
  }

  /// Analyze breeding between catalog creatures (distribution only)
  BreedingLikelihoodAnalysis analyzeCatalogBreeding(
    String parent1Id,
    String parent2Id,
  ) {
    final p1 = repository.getCreatureById(parent1Id);
    final p2 = repository.getCreatureById(parent2Id);

    if (p1 == null || p2 == null) {
      return _emptyAnalysis();
    }

    return _analyzeBreeding(p1, p2);
  }

  /// Analyze breeding between instance and wild creature (distribution only)
  BreedingLikelihoodAnalysis analyzeInstanceWildBreeding(
    db.CreatureInstance instance,
    Creature wild,
  ) {
    final base = repository.getCreatureById(instance.baseId);
    if (base == null) return _emptyAnalysis();

    final parent = _buildCreatureFromInstance(instance, base);
    return _analyzeBreeding(parent, wild);
  }

  /// Convenience: distribution + attached outcome summary for a known offspring (instances).
  BreedingLikelihoodAnalysis analyzeInstanceBreedingWithOutcome(
    db.CreatureInstance a,
    db.CreatureInstance b,
    Creature offspring,
  ) {
    final baseA = repository.getCreatureById(a.baseId);
    final baseB = repository.getCreatureById(b.baseId);
    if (baseA == null || baseB == null) return _emptyAnalysis();

    final p1 = _buildCreatureFromInstance(a, baseA);
    final p2 = _buildCreatureFromInstance(b, baseB);

    final analysis = _analyzeBreeding(p1, p2);
    final outcome = _scoreOffspringLikelihood(
      analysis: analysis,
      p1: p1,
      p2: p2,
      offspring: offspring,
    );
    return analysis.copyWithOutcome(outcome);
  }

  Creature _buildCreatureFromInstance(
    db.CreatureInstance instance,
    Creature base,
  ) {
    final genetics = _decodeGenetics(instance.geneticsJson);
    final nature = (instance.natureId != null)
        ? NatureCatalog.byId(instance.natureId!)
        : base.nature;

    return base.copyWith(
      genetics: genetics ?? base.genetics,
      nature: nature,
      isPrismaticSkin:
          instance.isPrismaticSkin || (base.isPrismaticSkin ?? false),
    );
  }

  Genetics? _decodeGenetics(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final map = decoded.map((k, v) => MapEntry(k, v.toString()));
      return Genetics(map);
    } catch (_) {
      return null;
    }
  }

  BreedingLikelihoodAnalysis _analyzeBreeding(Creature p1, Creature p2) {
    return BreedingLikelihoodAnalysis(
      colorResults: _analyzeColorLikelihood(p1, p2),
      sizeResults: _analyzeSizeLikelihood(p1, p2),
      natureResults: _analyzeNatureLikelihood(p1, p2),
      typeResults: _analyzeTypeLikelihood(p1, p2),
      familyResults: _analyzeFamilyLikelihood(p1, p2),
      specialResults: _analyzeSpecialLikelihood(p1, p2),
    );
  }

  List<LikelihoodResult> _analyzeColorLikelihood(Creature p1, Creature p2) {
    final results = <LikelihoodResult>[];

    // Get tinting track
    final tintTrack = GeneticsCatalog.all.firstWhere(
      (t) => t.key == 'tinting',
      orElse: () => throw StateError('Tinting track not found'),
    );

    // Get parent tints
    final p1Tint = p1.genetics?.get('tinting') ?? 'normal';
    final p2Tint = p2.genetics?.get('tinting') ?? 'normal';

    // Base dominance weights
    final baseDominance = <String, double>{};
    for (final variant in tintTrack.variants) {
      baseDominance[variant.id] = variant.dominance.toDouble();
    }

    // Apply elemental bias
    final biasedWeights = _applyTintBias(
      baseDom: baseDominance.map((k, v) => MapEntry(k, v.toInt())),
      p1Types: p1.types,
      p2Types: p2.types,
    );

    // Same-variant stickiness (~70% after normalization by weighting)
    if (p1Tint == p2Tint) {
      biasedWeights[p1Tint] = (biasedWeights[p1Tint] ?? 0) * 2.33;
    }

    // Calculate percentages and create results
    final total = biasedWeights.values.fold<double>(0, (a, b) => a + b);

    for (final entry in biasedWeights.entries) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
      if (percentage >= 5) {
        results.add(
          LikelihoodResult(
            trait: 'Color Tint',
            value: _formatTintName(entry.key),
            likelihood: _getLikelihood(percentage),
            percentage: percentage,
            description: _getTintDescription(entry.key, p1, p2),
          ),
        );
      }
    }

    return results..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  List<LikelihoodResult> _analyzeSizeLikelihood(Creature p1, Creature p2) {
    final results = <LikelihoodResult>[];

    // Get size track
    final scaleTrack = GeneticsCatalog.all.firstWhere(
      (t) => t.key == 'size',
      orElse: () => GeneticsCatalog.all.firstWhere(
        (t) => t.key == 'size',
        orElse: () => GeneticsCatalog.all.first,
      ),
    );

    // Use 'size' key
    final p1Scale = p1.genetics?.get('size') ?? 'normal';
    final p2Scale = p2.genetics?.get('size') ?? 'normal';

    final p1Variant = scaleTrack.byId(p1Scale);
    final p2Variant = scaleTrack.byId(p2Scale);

    final p1Value = (p1Variant.effect['scale'] ?? 1.0).toDouble();
    final p2Value = (p2Variant.effect['scale'] ?? 1.0).toDouble();

    // Blended inheritance - average with some variance notion
    final avgValue = (p1Value + p2Value) / 2.0;

    // Stickiness for extremes
    final bothGiant = (p1Scale == 'giant' && p2Scale == 'giant');
    final bothTiny = (p1Scale == 'tiny' && p2Scale == 'tiny');

    if (bothGiant) {
      results.add(
        LikelihoodResult(
          trait: 'Size',
          value: 'Giant',
          likelihood: Likelihood.probable,
          percentage: 70.0,
          description: 'Both parents are giant-sized',
        ),
      );
    } else if (bothTiny) {
      results.add(
        LikelihoodResult(
          trait: 'Size',
          value: 'Tiny',
          likelihood: Likelihood.likely,
          percentage: 60.0,
          description: 'Both parents are tiny-sized',
        ),
      );
    } else {
      // Inverse distance weighting to nearest variants
      final candidates = <String, double>{};
      for (final variant in scaleTrack.variants) {
        final value = (variant.effect['scale'] ?? 1.0).toDouble();
        final distance = (value - avgValue).abs();
        candidates[variant.id] = 1.0 / (distance + 0.1);
      }

      final total = candidates.values.fold<double>(0, (a, b) => a + b);
      for (final entry in candidates.entries) {
        final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
        if (percentage >= 10) {
          results.add(
            LikelihoodResult(
              trait: 'Size',
              value: _formatSizeName(entry.key),
              likelihood: _getLikelihood(percentage),
              percentage: percentage,
              description: _getSizeDescription(entry.key, p1Scale, p2Scale),
            ),
          );
        }
      }
    }

    return results..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  List<LikelihoodResult> _analyzeNatureLikelihood(Creature p1, Creature p2) {
    final results = <LikelihoodResult>[];
    final parents = [p1.nature, p2.nature].whereType<NatureDef>().toList();

    if (parents.isEmpty) {
      results.add(
        LikelihoodResult(
          trait: 'Nature',
          value: 'Random Nature',
          likelihood: Likelihood.probable,
          percentage: 100.0,
          description:
              'Parents have no nature, offspring will get random nature',
        ),
      );
      return results;
    }

    final inheritChance = tuning.inheritNatureChance.toDouble(); // e.g. 60%
    final sameLockInChance = tuning.sameNatureLockInChance
        .toDouble(); // e.g. 50%

    if (parents.length == 2 && parents[0].id == parents[1].id) {
      final lockInPercentage = sameLockInChance;
      results.add(
        LikelihoodResult(
          trait: 'Nature',
          value: parents[0].id,
          likelihood: _getLikelihood(lockInPercentage),
          percentage: lockInPercentage,
          description: 'Both parents share this nature',
        ),
      );

      final remaining = 100.0 - lockInPercentage;
      results.add(
        LikelihoodResult(
          trait: 'Nature',
          value: 'Random Nature',
          likelihood: _getLikelihood(remaining),
          percentage: remaining,
          description: 'Alternative nature from catalog',
        ),
      );
    } else {
      final inheritPercentage = inheritChance;

      for (final nature in parents) {
        final dominanceWeight = nature.dominance?.toDouble() ?? 1.0;
        final totalDominance = parents.fold<double>(
          0,
          (sum, n) => sum + (n.dominance?.toDouble() ?? 1.0),
        );
        final natureChance =
            (dominanceWeight / (totalDominance == 0 ? 1 : totalDominance)) *
            inheritPercentage;

        results.add(
          LikelihoodResult(
            trait: 'Nature',
            value: nature.id,
            likelihood: _getLikelihood(natureChance),
            percentage: natureChance,
            description:
                'Inherited from parent with dominance ${nature.dominance ?? 1}',
          ),
        );
      }

      final randomChance = 100.0 - inheritPercentage;
      results.add(
        LikelihoodResult(
          trait: 'Nature',
          value: 'Random Nature',
          likelihood: _getLikelihood(randomChance),
          percentage: randomChance,
          description: 'Fresh nature from catalog',
        ),
      );
    }

    return results..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  List<LikelihoodResult> _analyzeTypeLikelihood(Creature p1, Creature p2) {
    final results = <LikelihoodResult>[];
    final t1 = p1.types.isNotEmpty ? p1.types.first : 'Unknown';
    final t2 = p2.types.isNotEmpty ? p2.types.first : 'Unknown';

    if (t1 == t2) {
      results.add(
        LikelihoodResult(
          trait: 'Primary Type',
          value: t1,
          likelihood: Likelihood.probable,
          percentage: 100.0,
          description: 'Both parents share this type',
        ),
      );
      return results;
    }

    // Get element recipe
    final key = ElementRecipeConfig.keyOf(t1, t2);
    Map<String, int>? weighted = elementRecipes.recipes[key];

    weighted ??=
        elementRecipes.recipes[t1] ??
        elementRecipes.recipes[t2] ??
        {t1: 50, t2: 50};

    // Apply nature bias if applicable (placeholder)
    weighted = _applyTypeNatureBias(weighted, p1, p2);

    final total = weighted.values.fold<int>(0, (a, b) => a + b);

    for (final entry in weighted.entries) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
      results.add(
        LikelihoodResult(
          trait: 'Primary Type',
          value: entry.key,
          likelihood: _getLikelihood(percentage),
          percentage: percentage,
          description: _getTypeDescription(entry.key, t1, t2),
        ),
      );
    }

    return results..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  List<LikelihoodResult> _analyzeFamilyLikelihood(Creature p1, Creature p2) {
    final results = <LikelihoodResult>[];
    final f1 = p1.mutationFamily ?? 'Unknown';
    final f2 = p2.mutationFamily ?? 'Unknown';

    if (f1 == f2) {
      final mutationChance = tuning.sameFamilyMutationChancePct.toDouble();

      results.add(
        LikelihoodResult(
          trait: 'Family',
          value: f1,
          likelihood: _getLikelihood(100.0 - mutationChance),
          percentage: 100.0 - mutationChance,
          description: 'Both parents belong to this family',
        ),
      );

      if (mutationChance > 0) {
        results.add(
          LikelihoodResult(
            trait: 'Family',
            value: 'Mutated Family',
            likelihood: _getLikelihood(mutationChance),
            percentage: mutationChance,
            description: 'Family mutation to a different lineage',
          ),
        );
      }
    } else {
      final key = FamilyRecipeConfig.keyOf(f1, f2);
      final recipe = familyRecipes.recipes[key] ?? {f1: 50, f2: 50};

      final total = recipe.values.fold<int>(0, (a, b) => a + b);

      for (final entry in recipe.entries) {
        final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
        results.add(
          LikelihoodResult(
            trait: 'Family',
            value: entry.key,
            likelihood: _getLikelihood(percentage),
            percentage: percentage,
            description: _getFamilyDescription(entry.key, f1, f2),
          ),
        );
      }
    }

    return results..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  List<LikelihoodResult> _analyzeSpecialLikelihood(Creature p1, Creature p2) {
    final results = <LikelihoodResult>[];

    // Guaranteed pairs
    final gk = SpecialRulesConfig.idKey(p1.id, p2.id);
    final outs = specialRules.guaranteedPairs[gk];

    if (outs != null && outs.isNotEmpty) {
      for (final rule in outs) {
        final creature = repository.getCreatureById(rule.resultId);
        if (creature != null) {
          results.add(
            LikelihoodResult(
              trait: 'Guaranteed Result',
              value: creature.name,
              likelihood: _getLikelihood(rule.chance.toDouble()),
              percentage: rule.chance.toDouble(),
              description: 'Special breeding combination result',
            ),
          );
        }
      }
    }

    // Cross-variant chances
    final t1 = p1.types.isNotEmpty ? p1.types.first : 'Unknown';
    final t2 = p2.types.isNotEmpty ? p2.types.first : 'Unknown';

    if (p1.variantTypes.contains(t2)) {
      results.add(
        LikelihoodResult(
          trait: 'Cross-Variant',
          value: '${p1.name} ($t1/$t2)',
          likelihood: _getLikelihood(tuning.variantChanceCross.toDouble()),
          percentage: tuning.variantChanceCross.toDouble(),
          description: 'Cross-variant of ${p1.name} with secondary type $t2',
        ),
      );
    }

    if (p2.variantTypes.contains(t1)) {
      results.add(
        LikelihoodResult(
          trait: 'Cross-Variant',
          value: '${p2.name} ($t2/$t1)',
          likelihood: _getLikelihood(tuning.variantChanceCross.toDouble()),
          percentage: tuning.variantChanceCross.toDouble(),
          description: 'Cross-variant of ${p2.name} with secondary type $t1',
        ),
      );
    }

    // Parent repeat chance
    final repeatChance = tuning.parentRepeatChance.toDouble();
    if (repeatChance > 0) {
      results.add(
        LikelihoodResult(
          trait: 'Parent Species',
          value: 'Same as Parent',
          likelihood: _getLikelihood(repeatChance),
          percentage: repeatChance,
          description: 'Offspring identical to one parent',
        ),
      );
    }

    // Prismatic skin
    final prismaticChance = (tuning.prismaticSkinChance * 100);
    results.add(
      LikelihoodResult(
        trait: 'Prismatic Skin',
        value: 'Enabled',
        likelihood: _getLikelihood(prismaticChance),
        percentage: prismaticChance,
        description: 'Rare cosmetic variant',
      ),
    );

    return results..sort((a, b) => b.percentage.compareTo(a.percentage));
  }

  // ===== Outcome scoring and helpers =====

  OffspringLikelihoodSummary _scoreOffspringLikelihood({
    required BreedingLikelihoodAnalysis analysis,
    required Creature p1,
    required Creature p2,
    required Creature offspring,
  }) {
    final per = <String, double>{};
    final matched = <LikelihoodResult>[];
    const eps = 0.0001;

    double safePct(double? v) =>
        (v == null || v.isNaN) ? 0.0 : v.clamp(0.0, 100.0);

    LikelihoodResult? _pick(
      List<LikelihoodResult> list,
      String trait,
      String value,
    ) {
      final exact = list.where((r) => r.trait == trait && r.value == value);
      if (exact.isNotEmpty) return exact.first;

      // Special case for nature fallback
      if (trait == 'Nature') {
        final rn = list.where(
          (r) => r.trait == 'Nature' && r.value == 'Random Nature',
        );
        if (rn.isNotEmpty) return rn.first;
      }
      return null;
    }

    double _pctOf(List<LikelihoodResult> list, String trait, String value) {
      final m = _pick(list, trait, value);
      if (m != null) {
        matched.add(m);
        return safePct(m.percentage);
      }
      // If predictions exist but UI pruned some tails, attribute leftover mass.
      final forTrait = list.where((r) => r.trait == trait).toList();
      if (forTrait.isNotEmpty) {
        final sumForTrait = forTrait.fold<double>(
          0,
          (s, r) => s + safePct(r.percentage),
        );
        final leftover = (100.0 - sumForTrait).clamp(0.0, 100.0);
        return leftover > 0 ? leftover : eps;
      }
      // If no predictions at all for this trait, use tiny epsilon.
      return eps;
    }

    // Color Tint
    final tint = offspring.genetics?.get('tinting') ?? 'normal';
    per['Color Tint'] = _pctOf(
      analysis.colorResults,
      'Color Tint',
      _formatTintName(tint),
    );

    // Size
    final size = offspring.genetics?.get('size') ?? 'normal';
    per['Size'] = _pctOf(analysis.sizeResults, 'Size', _formatSizeName(size));

    // Nature
    final natureId = offspring.nature?.id ?? 'Random Nature';
    per['Nature'] = _pctOf(analysis.natureResults, 'Nature', natureId);

    // Primary Type
    final primaryType = offspring.types.isNotEmpty
        ? offspring.types.first
        : 'Unknown';
    per['Primary Type'] = _pctOf(
      analysis.typeResults,
      'Primary Type',
      primaryType,
    );

    // Family
    final fam = offspring.mutationFamily ?? 'Unknown';
    per['Family'] = _pctOf(analysis.familyResults, 'Family', fam);

    // Specials → blend to one "Special" dimension (average)
    final specialMatches = <double>[];
    for (final r in analysis.specialResults) {
      switch (r.trait) {
        case 'Guaranteed Result':
          if (r.value == offspring.name) {
            specialMatches.add(safePct(r.percentage));
            matched.add(r);
          }
          break;
        case 'Cross-Variant':
          // Heuristic: offspring name appears in label
          if (r.value.contains(offspring.name)) {
            specialMatches.add(safePct(r.percentage));
            matched.add(r);
          }
          break;
        case 'Parent Species':
          final sameAsParent = offspring.id == p1.id || offspring.id == p2.id;
          if (sameAsParent && r.value == 'Same as Parent') {
            specialMatches.add(safePct(r.percentage));
            matched.add(r);
          }
          break;
        case 'Prismatic Skin':
          final isPrismatic = offspring.isPrismaticSkin == true;
          final prismaticPct = safePct(r.percentage);
          specialMatches.add(
            isPrismatic ? prismaticPct : (100.0 - prismaticPct),
          );
          matched.add(r);
          break;
      }
    }
    if (specialMatches.isNotEmpty) {
      final avgSpecial =
          specialMatches.reduce((a, b) => a + b) / specialMatches.length;
      per['Special'] = avgSpecial;
    }

    // Joint probability (assume independence across buckets)
    final considered = per.values.where((v) => v > 0).toList();
    final logSum = considered.fold<double>(
      0.0,
      (s, v) => s + ((v / 100.0) <= 0 ? math.log(eps) : math.log(v / 100.0)),
    );
    final joint = math.exp(logSum) * 100.0;

    return OffspringLikelihoodSummary(
      perTraitPct: per,
      jointPct: joint,
      overall: _getLikelihood(joint),
      matched: matched,
    );
  }

  // ===== Helpers =====

  Likelihood _getLikelihood(double percentage) {
    if (percentage >= 66) return Likelihood.probable;
    if (percentage >= 36) return Likelihood.likely;
    if (percentage >= 16) return Likelihood.unlikely;
    return Likelihood.improbable;
  }

  Map<String, double> _applyTintBias({
    required Map<String, int> baseDom,
    required List<String> p1Types,
    required List<String> p2Types,
  }) {
    final w = baseDom.map((k, v) => MapEntry(k, v.toDouble()));

    for (final t in [...p1Types, ...p2Types]) {
      final b = tintBiasPerType[t];
      if (b == null) continue;
      b.forEach((variantId, mult) {
        w[variantId] = (w[variantId] ?? 0) * mult;
      });
    }

    w['normal'] = (w['normal'] ?? 0).clamp(0.01, double.infinity);
    return w;
  }

  Map<String, int> _applyTypeNatureBias(
    Map<String, int> weights,
    Creature? p1,
    Creature? p2,
  ) {
    // Placeholder for future nature-based type bias.
    return weights;
  }

  String _formatTintName(String tintId) {
    if (tintId.isEmpty) return tintId;
    return tintId.replaceFirst(tintId[0], tintId[0].toUpperCase());
  }

  String _formatSizeName(String sizeId) {
    if (sizeId.isEmpty) return sizeId;
    return sizeId.replaceFirst(sizeId[0], sizeId[0].toUpperCase());
  }

  String _getTintDescription(String tintId, Creature p1, Creature p2) {
    final p1Tint = p1.genetics?.get('tinting') ?? 'normal';
    final p2Tint = p2.genetics?.get('tinting') ?? 'normal';

    if (tintId == p1Tint && tintId == p2Tint) {
      return 'Both parents have this tint';
    } else if (tintId == p1Tint || tintId == p2Tint) {
      return 'Inherited from one parent';
    } else {
      return 'Enhanced by elemental affinity';
    }
  }

  String _getSizeDescription(String sizeId, String p1Scale, String p2Scale) {
    if (sizeId == p1Scale && sizeId == p2Scale) {
      return 'Both parents are this size';
    } else if (sizeId == p1Scale || sizeId == p2Scale) {
      return 'Inherited from one parent';
    } else {
      return 'Blended from parent sizes';
    }
  }

  String _getTypeDescription(String type, String t1, String t2) {
    if (type == t1 && type == t2) {
      return 'Shared parent type';
    } else if (type == t1) {
      return 'From first parent';
    } else if (type == t2) {
      return 'From second parent';
    } else {
      return 'Elemental combination result';
    }
  }

  String _getFamilyDescription(String family, String f1, String f2) {
    if (family == f1 && family == f2) {
      return 'Shared parent family';
    } else if (family == f1) {
      return 'From first parent lineage';
    } else if (family == f2) {
      return 'From second parent lineage';
    } else {
      return 'Cross-family combination';
    }
  }

  BreedingLikelihoodAnalysis _emptyAnalysis() {
    return const BreedingLikelihoodAnalysis(
      colorResults: [],
      sizeResults: [],
      natureResults: [],
      typeResults: [],
      familyResults: [],
      specialResults: [],
      outcome: null,
    );
  }
}

enum JustificationCategory {
  familyLineage,
  elementalType,
  genetics,
  nature,
  special,
  cosmetic,
}

class TraitJustification {
  final String trait;
  final String actualValue;
  final double actualChance;
  final String mechanism;
  final String explanation;
  final JustificationCategory category;
  final bool wasUnexpected;

  const TraitJustification({
    required this.trait,
    required this.actualValue,
    required this.actualChance,
    required this.mechanism,
    required this.explanation,
    required this.category,
    required this.wasUnexpected,
  });

  Map<String, dynamic> toJson() => {
    'trait': trait,
    'actualValue': actualValue,
    'actualChance': actualChance,
    'mechanism': mechanism,
    'explanation': explanation,
    'category': category.name,
    'wasUnexpected': wasUnexpected,
  };
}

class BreedingResultJustification {
  final Creature offspring;
  final List<TraitJustification> traitJustifications;
  final String overallOutcome; // "Expected", "Surprising", "Rare"
  final double overallLikelihood;
  final String summaryExplanation;

  const BreedingResultJustification({
    required this.offspring,
    required this.traitJustifications,
    required this.overallOutcome,
    required this.overallLikelihood,
    required this.summaryExplanation,
  });

  List<TraitJustification> get familyJustifications => traitJustifications
      .where((t) => t.category == JustificationCategory.familyLineage)
      .toList();

  List<TraitJustification> get typeJustifications => traitJustifications
      .where((t) => t.category == JustificationCategory.elementalType)
      .toList();

  List<TraitJustification> get geneticsJustifications => traitJustifications
      .where((t) => t.category == JustificationCategory.genetics)
      .toList();

  Map<String, dynamic> toJson() => {
    'offspring': {
      'id': offspring.id,
      'name': offspring.name,
      'types': offspring.types,
      'family': offspring.mutationFamily,
    },
    'traitJustifications': traitJustifications.map((t) => t.toJson()).toList(),
    'overallOutcome': overallOutcome,
    'overallLikelihood': overallLikelihood,
    'summaryExplanation': summaryExplanation,
  };
}

// Extension to add justification capabilities to existing analyzer
extension BreedingLikelihoodAnalyzerJustification
    on BreedingLikelihoodAnalyzer {
  /// Generate full justification for an offspring result
  BreedingResultJustification justifyBreedingResult(
    Creature parent1,
    Creature parent2,
    Creature offspring,
  ) {
    // Use existing analysis logic
    final analysis = _analyzeBreeding(parent1, parent2);
    final outcome = _scoreOffspringLikelihood(
      analysis: analysis,
      p1: parent1,
      p2: parent2,
      offspring: offspring,
    );
    final analysisWithOutcome = analysis.copyWithOutcome(outcome);

    // Generate justifications by interpreting the analysis results
    return _buildJustificationFromAnalysis(
      parent1,
      parent2,
      offspring,
      analysisWithOutcome,
    );
  }

  /// Justify instance breeding result
  BreedingResultJustification justifyInstanceBreeding(
    db.CreatureInstance a,
    db.CreatureInstance b,
    Creature offspring,
  ) {
    final analysisWithOutcome = analyzeInstanceBreedingWithOutcome(
      a,
      b,
      offspring,
    );

    final baseA = repository.getCreatureById(a.baseId);
    final baseB = repository.getCreatureById(b.baseId);
    if (baseA == null || baseB == null) {
      return _emptyJustification(offspring);
    }

    final p1 = _buildCreatureFromInstance(a, baseA);
    final p2 = _buildCreatureFromInstance(b, baseB);

    return _buildJustificationFromAnalysis(
      p1,
      p2,
      offspring,
      analysisWithOutcome,
    );
  }

  BreedingResultJustification _buildJustificationFromAnalysis(
    Creature p1,
    Creature p2,
    Creature offspring,
    BreedingLikelihoodAnalysis analysis,
  ) {
    final justifications = <TraitJustification>[];

    // Family Lineage - use existing family results
    if (analysis.familyResults.isNotEmpty) {
      final actualFamily = offspring.mutationFamily ?? 'Unknown';
      final matchingResult = analysis.familyResults.firstWhere(
        (r) => r.value == actualFamily,
        orElse: () => analysis.familyResults.first,
      );

      justifications.add(
        TraitJustification(
          trait: 'Family Lineage',
          actualValue: actualFamily,
          actualChance: matchingResult.percentage,
          mechanism: _getFamilyMechanism(p1, p2, actualFamily),
          explanation: _getFamilyExplanation(
            p1,
            p2,
            actualFamily,
            matchingResult.percentage,
          ),
          category: JustificationCategory.familyLineage,
          wasUnexpected: matchingResult.percentage < 30.0,
        ),
      );
    }

    // Elemental Type - use existing type results
    if (analysis.typeResults.isNotEmpty) {
      final actualType = offspring.types.isNotEmpty
          ? offspring.types.first
          : 'Unknown';
      final matchingResult = analysis.typeResults.firstWhere(
        (r) => r.value == actualType,
        orElse: () => analysis.typeResults.first,
      );

      justifications.add(
        TraitJustification(
          trait: 'Elemental Type',
          actualValue: actualType,
          actualChance: matchingResult.percentage,
          mechanism: _getTypeMechanism(p1, p2, actualType),
          explanation: _getTypeExplanation(
            p1,
            p2,
            actualType,
            matchingResult.percentage,
          ),
          category: JustificationCategory.elementalType,
          wasUnexpected: matchingResult.percentage < 35.0,
        ),
      );
    }

    // Genetics - use existing color/size results
    if (analysis.colorResults.isNotEmpty) {
      final actualTint = offspring.genetics?.get('tinting') ?? 'normal';
      final matchingResult = analysis.colorResults.firstWhere(
        (r) =>
            r.value.toLowerCase() == _formatTintName(actualTint).toLowerCase(),
        orElse: () => analysis.colorResults.first,
      );

      justifications.add(
        TraitJustification(
          trait: 'Color Tinting',
          actualValue: _formatTintName(actualTint),
          actualChance: matchingResult.percentage,
          mechanism: _getTintMechanism(p1, p2, actualTint),
          explanation: _getTintExplanation(
            p1,
            p2,
            actualTint,
            matchingResult.percentage,
          ),
          category: JustificationCategory.genetics,
          wasUnexpected: matchingResult.percentage < 25.0,
        ),
      );
    }

    if (analysis.sizeResults.isNotEmpty) {
      final actualSize = offspring.genetics?.get('size') ?? 'normal';
      final matchingResult = analysis.sizeResults.firstWhere(
        (r) =>
            r.value.toLowerCase() == _formatSizeName(actualSize).toLowerCase(),
        orElse: () => analysis.sizeResults.first,
      );

      justifications.add(
        TraitJustification(
          trait: 'Size',
          actualValue: _formatSizeName(actualSize),
          actualChance: matchingResult.percentage,
          mechanism: _getSizeMechanism(p1, p2, actualSize),
          explanation: _getSizeExplanation(
            p1,
            p2,
            actualSize,
            matchingResult.percentage,
          ),
          category: JustificationCategory.genetics,
          wasUnexpected: matchingResult.percentage < 20.0,
        ),
      );
    }

    if (analysis.natureResults.isNotEmpty) {
      final actualNature = offspring.nature?.id ?? 'Random Nature';
      final matchingResult = analysis.natureResults.firstWhere(
        (r) => r.value == actualNature,
        orElse: () => analysis.natureResults.first,
      );

      justifications.add(
        TraitJustification(
          trait: 'Nature',
          actualValue: actualNature,
          actualChance: matchingResult.percentage,
          mechanism: _getNatureMechanism(p1, p2, actualNature),
          explanation: _getNatureExplanation(
            p1,
            p2,
            actualNature,
            matchingResult.percentage,
          ),
          category: JustificationCategory.nature,
          wasUnexpected: matchingResult.percentage < 30.0,
        ),
      );
    }

    // Special results - interpret existing special results
    for (final special in analysis.specialResults) {
      if (_isSpecialRelevant(special, offspring, p1, p2)) {
        justifications.add(
          TraitJustification(
            trait: special.trait,
            actualValue: special.value,
            actualChance: special.percentage,
            mechanism: _getSpecialMechanism(special.trait),
            explanation: special.description,
            category: JustificationCategory.special,
            wasUnexpected: special.percentage < 20.0,
          ),
        );
      }
    }

    // Use simple outcome categorization based on individual traits
    final outcomeCategory = _categorizeOutcomeByTraits(justifications);
    final summary = _generateSimpleSummary(
      p1,
      p2,
      offspring,
      justifications,
      outcomeCategory,
    );

    return BreedingResultJustification(
      offspring: offspring,
      traitJustifications: justifications,
      overallOutcome: outcomeCategory,
      overallLikelihood: 0.0, // No longer using flawed joint probability
      summaryExplanation: summary,
    );
  }

  // Helper methods for generating explanations
  String _getFamilyMechanism(Creature p1, Creature p2, String actualFamily) {
    final f1 = p1.mutationFamily ?? 'Unknown';
    final f2 = p2.mutationFamily ?? 'Unknown';

    if (f1 == f2) {
      return actualFamily == f1
          ? "Same-Family Inheritance"
          : "Same-Family Mutation";
    }
    return "Cross-Family Breeding";
  }

  String _getNatureMechanism(Creature p1, Creature p2, String actualNature) {
    final n1 = p1.nature?.id;
    final n2 = p2.nature?.id;

    if (n1 == null && n2 == null) return "Random Assignment";
    if (n1 != null && n2 != null && n1 == n2) return "Same-Nature Lock-in";
    return "Nature Inheritance";
  }

  String _getNatureExplanation(
    Creature p1,
    Creature p2,
    String actualNature,
    double chance,
  ) {
    final n1 = p1.nature?.id;
    final n2 = p2.nature?.id;

    if (n1 == null && n2 == null) {
      return "Both parents lack nature traits. Offspring received random nature from catalog (${chance.toStringAsFixed(1)}% chance).";
    }

    if (n1 != null && n2 != null && n1 == n2) {
      return actualNature == n1
          ? "Both parents share $n1 nature. Same-nature lock-in succeeded (${chance.toStringAsFixed(1)}% chance)."
          : "Despite both parents having $n1 nature, lock-in was overcome by catalog randomization (${chance.toStringAsFixed(1)}% chance).";
    }

    return actualNature == n1 || actualNature == n2
        ? "Inherited from parent with dominance weighting (${chance.toStringAsFixed(1)}% chance)."
        : "Fresh nature selected from catalog (${chance.toStringAsFixed(1)}% chance).";
  }

  String _getFamilyExplanation(
    Creature p1,
    Creature p2,
    String actualFamily,
    double chance,
  ) {
    final f1 = p1.mutationFamily ?? 'Unknown';
    final f2 = p2.mutationFamily ?? 'Unknown';

    if (f1 == f2) {
      if (actualFamily == f1) {
        return "Both parents belong to the $f1 family. Same-family stickiness resulted in offspring inheriting the shared lineage (${chance.toStringAsFixed(1)}% chance).";
      } else {
        return "Despite both parents being $f1 family, a rare mutation occurred, resulting in $actualFamily lineage (${chance.toStringAsFixed(1)}% chance).";
      }
    } else {
      return "Cross-breeding between $f1 and $f2 families. Family recipes determined $actualFamily outcome (${chance.toStringAsFixed(1)}% chance).";
    }
  }

  String _getTypeMechanism(Creature p1, Creature p2, String actualType) {
    final t1 = p1.types.isNotEmpty ? p1.types.first : 'Unknown';
    final t2 = p2.types.isNotEmpty ? p2.types.first : 'Unknown';

    if (t1 == t2) return "Same-Type Inheritance";
    if (actualType != t1 && actualType != t2) return "Elemental Fusion";
    return "Elemental Inheritance";
  }

  String _getTypeExplanation(
    Creature p1,
    Creature p2,
    String actualType,
    double chance,
  ) {
    final t1 = p1.types.isNotEmpty ? p1.types.first : 'Unknown';
    final t2 = p2.types.isNotEmpty ? p2.types.first : 'Unknown';

    if (t1 == t2) {
      return "Both parents share the $t1 element, guaranteeing offspring inherits this type.";
    } else if (actualType != t1 && actualType != t2) {
      return "$t1 + $t2 elements fused to create $actualType through alchemical combination (${chance.toStringAsFixed(1)}% chance).";
    } else {
      return "Despite elemental recipe rules, offspring inherited pure $actualType element from parents (${chance.toStringAsFixed(1)}% chance).";
    }
  }

  String _getTintMechanism(Creature p1, Creature p2, String actualTint) {
    final p1Tint = p1.genetics?.get('tinting') ?? 'normal';
    final p2Tint = p2.genetics?.get('tinting') ?? 'normal';

    if (p1Tint == p2Tint && actualTint == p1Tint) return "Same-Tint Stickiness";

    // Check for elemental bias
    final types = [...p1.types, ...p2.types];
    final hasBias = types.any(
      (t) => BreedingLikelihoodAnalyzer.tintBiasPerType.containsKey(t),
    );

    return hasBias ? "Elemental Tint Bias" : "Weighted Dominance";
  }

  String _getTintExplanation(
    Creature p1,
    Creature p2,
    String actualTint,
    double chance,
  ) {
    final p1Tint = p1.genetics?.get('tinting') ?? 'normal';
    final p2Tint = p2.genetics?.get('tinting') ?? 'normal';

    if (p1Tint == p2Tint && actualTint == p1Tint) {
      return "Both parents share $p1Tint tinting. Same-tint stickiness (~70%) successfully maintained parental coloration.";
    }

    var explanation = "Tint determined by dominance weights";

    // Check for elemental bias
    final types = [...p1.types, ...p2.types];
    final biasTypes = types
        .where((t) => BreedingLikelihoodAnalyzer.tintBiasPerType.containsKey(t))
        .toList();

    if (biasTypes.isNotEmpty) {
      explanation += " enhanced by ${biasTypes.join(', ')} elemental affinity";
    }

    return "$explanation. Result: ${chance.toStringAsFixed(1)}% likelihood.";
  }

  String _getSizeMechanism(Creature p1, Creature p2, String actualSize) {
    final p1Size = p1.genetics?.get('size') ?? 'normal';
    final p2Size = p2.genetics?.get('size') ?? 'normal';

    if ((p1Size == 'giant' && p2Size == 'giant') ||
        (p1Size == 'tiny' && p2Size == 'tiny')) {
      return "Extreme Size Stickiness";
    }
    return "Blended Inheritance";
  }

  String _getSizeExplanation(
    Creature p1,
    Creature p2,
    String actualSize,
    double chance,
  ) {
    final p1Size = p1.genetics?.get('size') ?? 'normal';
    final p2Size = p2.genetics?.get('size') ?? 'normal';

    if ((p1Size == 'giant' && p2Size == 'giant') ||
        (p1Size == 'tiny' && p2Size == 'tiny')) {
      final stickyPct = p1Size == 'giant' ? 70.0 : 60.0;
      if (actualSize == p1Size) {
        return "Both parents are $p1Size size. Extreme size stickiness (~${stickyPct}%) successfully maintained parental size.";
      } else {
        return "Both parents are $p1Size size, but extreme size stickiness was overcome, resulting in size drift toward center.";
      }
    }

    return "Parent sizes blended through genetic averaging with slight random variance. Result represents blend with ${chance.toStringAsFixed(1)}% likelihood.";
  }

  String _getSpecialMechanism(String trait) {
    switch (trait) {
      case 'Guaranteed Result':
        return "Special Breeding Pair";
      case 'Cross-Variant':
        return "Cross-Variant Generation";
      case 'Parent Species':
        return "Parent Repeat Chance";
      case 'Prismatic Skin':
        return "Cosmetic Mutation";
      default:
        return "Special Event";
    }
  }

  bool _isSpecialRelevant(
    LikelihoodResult special,
    Creature offspring,
    Creature p1,
    Creature p2,
  ) {
    switch (special.trait) {
      case 'Guaranteed Result':
        return special.value == offspring.name;
      case 'Cross-Variant':
        return special.value.contains(offspring.name);
      case 'Parent Species':
        return offspring.id == p1.id || offspring.id == p2.id;
      case 'Prismatic Skin':
        return offspring.isPrismaticSkin == true;
      default:
        return false;
    }
  }

  // New simple categorization based on individual trait probabilities
  String _categorizeOutcomeByTraits(List<TraitJustification> justifications) {
    final unexpectedCount = justifications.where((j) => j.wasUnexpected).length;
    final veryLowChance = justifications
        .where((j) => j.actualChance < 15.0)
        .length;

    if (veryLowChance >= 2) return "Rare";
    if (unexpectedCount >= 2) return "Surprising";
    if (unexpectedCount == 1) return "Surprising";
    return "Expected";
  }

  String _generateSimpleSummary(
    Creature p1,
    Creature p2,
    Creature offspring,
    List<TraitJustification> justifications,
    String outcome,
  ) {
    final unexpected = justifications.where((j) => j.wasUnexpected).toList();

    String summary = "Breeding ${p1.name} × ${p2.name} → ${offspring.name}: ";

    switch (outcome) {
      case "Expected":
        summary += "This outcome followed typical breeding patterns. ";
        break;
      case "Surprising":
        summary += "This outcome had some unexpected traits. ";
        break;
      case "Rare":
        summary += "This was an extremely rare outcome! ";
        break;
    }

    // Add individual trait breakdown
    final mainTraits = justifications
        .where(
          (j) =>
              j.category == JustificationCategory.familyLineage ||
              j.category == JustificationCategory.elementalType,
        )
        .toList();

    if (mainTraits.isNotEmpty) {
      summary += "\nKey Results:";
      for (final trait in mainTraits) {
        summary +=
            "\n• ${trait.trait}: ${trait.actualValue} (${trait.actualChance.toStringAsFixed(1)}% chance)";
      }
    }

    if (unexpected.isNotEmpty) {
      summary +=
          "\nUnexpected aspects: ${unexpected.map((j) => "${j.trait} (${j.actualChance.toStringAsFixed(1)}%)").join(', ')}.";
    }

    return summary;
  }

  BreedingResultJustification _emptyJustification(Creature offspring) {
    return BreedingResultJustification(
      offspring: offspring,
      traitJustifications: [],
      overallOutcome: "Unknown",
      overallLikelihood: 0.0,
      summaryExplanation:
          "Unable to analyze breeding result due to missing parent data.",
    );
  }
}

// Combined result class for breeding with justification
class BreedingResultWithJustification {
  final BreedingResult result;
  final BreedingResultJustification? justification;
  final bool success;

  const BreedingResultWithJustification({
    required this.result,
    this.justification,
    this.success = true,
  });

  BreedingResultWithJustification.failure()
    : result = BreedingResult.failure(),
      justification = null,
      success = false;
}

// Extension to add justification to breeding engine
extension BreedingEngineJustification on BreedingEngine {
  BreedingResultWithJustification breedWithJustification(
    String parent1Id,
    String parent2Id,
  ) {
    final result = breed(parent1Id, parent2Id);
    if (!result.success || result.creature == null) {
      return BreedingResultWithJustification.failure();
    }

    final analyzer = BreedingLikelihoodAnalyzer(
      repository: repository,
      elementRecipes: elementRecipes,
      familyRecipes: familyRecipes,
      specialRules: specialRules,
      tuning: tuning,
    );

    final p1 = repository.getCreatureById(parent1Id)!;
    final p2 = repository.getCreatureById(parent2Id)!;

    final justification = analyzer.justifyBreedingResult(
      p1,
      p2,
      result.creature!,
    );

    return BreedingResultWithJustification(
      result: result,
      justification: justification,
    );
  }

  BreedingResultWithJustification breedInstancesWithJustification(
    db.CreatureInstance a,
    db.CreatureInstance b,
  ) {
    final result = breedInstances(a, b);
    if (!result.success || result.creature == null) {
      return BreedingResultWithJustification.failure();
    }

    final analyzer = BreedingLikelihoodAnalyzer(
      repository: repository,
      elementRecipes: elementRecipes,
      familyRecipes: familyRecipes,
      specialRules: specialRules,
      tuning: tuning,
    );

    final justification = analyzer.justifyInstanceBreeding(
      a,
      b,
      result.creature!,
    );

    return BreedingResultWithJustification(
      result: result,
      justification: justification,
    );
  }
}

// ===== Extension for easy likelihood display =====
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

  String get emoji {
    switch (this) {
      case Likelihood.improbable:
        return '🔮';
      case Likelihood.unlikely:
        return '🎲';
      case Likelihood.likely:
        return '⚖️';
      case Likelihood.probable:
        return '🎯';
    }
  }
}
