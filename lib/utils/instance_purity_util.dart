import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';

enum InstancePurityFilter {
  all,
  elemental,
  species,
  pure;

  InstancePurityFilter next() => switch (this) {
    InstancePurityFilter.all => InstancePurityFilter.pure,
    InstancePurityFilter.pure => InstancePurityFilter.elemental,
    InstancePurityFilter.elemental => InstancePurityFilter.species,
    InstancePurityFilter.species => InstancePurityFilter.all,
  };

  String? get chipValueText => switch (this) {
    InstancePurityFilter.all => null,
    InstancePurityFilter.elemental => 'ELEMENTAL',
    InstancePurityFilter.species => 'SPECIES',
    InstancePurityFilter.pure => 'PURE',
  };
}

class InstancePurityStatus {
  final Map<String, int> elementLineage;
  final Map<String, int> speciesLineage;

  const InstancePurityStatus({
    required this.elementLineage,
    required this.speciesLineage,
  });

  bool get isElementallyPure => elementLineage.length == 1;
  bool get isSpeciesPure => speciesLineage.length == 1;
  bool get isPure => isElementallyPure && isSpeciesPure;

  String get label {
    if (isPure) return 'Pure';
    if (isElementallyPure) return 'Elementally Pure';
    if (isSpeciesPure) return 'Species Pure';
    return 'Mixed Lineage';
  }

  String get description {
    if (isPure) {
      return 'Single elemental and species lineages are recorded.';
    }
    if (isElementallyPure) {
      return 'Single elemental line, but the species line is mixed.';
    }
    if (isSpeciesPure) {
      return 'Single species line, but the elemental line is mixed.';
    }
    return 'Both elemental and species lines are mixed.';
  }
}

class PurityStatBonus {
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  const PurityStatBonus({
    this.speed = 0.0,
    this.intelligence = 0.0,
    this.strength = 0.0,
    this.beauty = 0.0,
  });

  bool get hasBonus =>
      speed > 0 || intelligence > 0 || strength > 0 || beauty > 0;

  double forStat(String statName) {
    switch (statName.toLowerCase()) {
      case 'speed':
        return speed;
      case 'intelligence':
        return intelligence;
      case 'strength':
        return strength;
      case 'beauty':
        return beauty;
      default:
        return 0.0;
    }
  }

  String get summary {
    final parts = <String>[];
    if (beauty > 0) parts.add('Beauty +${beauty.toStringAsFixed(2)}');
    if (strength > 0) parts.add('Strength +${strength.toStringAsFixed(2)}');
    if (intelligence > 0) {
      parts.add('Intelligence +${intelligence.toStringAsFixed(2)}');
    }
    if (speed > 0) parts.add('Speed +${speed.toStringAsFixed(2)}');
    return parts.isEmpty ? 'None' : parts.join(', ');
  }

  String explanationFor(InstancePurityStatus status) {
    if (!hasBonus) {
      return 'Mixed lineage grants no purity stat bonus.';
    }
    if (status.isPure) {
      return 'Pure specimens gain +0.25 Beauty, +0.25 Strength, and +0.25 Intelligence to base stats.';
    }
    if (status.isElementallyPure) {
      return 'Elementally pure specimens gain +0.25 Beauty to base stats.';
    }
    if (status.isSpeciesPure) {
      return 'Species pure specimens gain +0.25 Strength to base stats.';
    }
    return 'Mixed lineage grants no purity stat bonus.';
  }
}

InstancePurityStatus classifyPurityFromLineages({
  required Map<String, int> elementLineage,
  required Map<String, int> speciesLineage,
}) {
  final normalizedElements = Map<String, int>.from(elementLineage)
    ..removeWhere((_, value) => value <= 0);
  final normalizedSpecies = Map<String, int>.from(speciesLineage)
    ..removeWhere((_, value) => value <= 0);
  return InstancePurityStatus(
    elementLineage: normalizedElements,
    speciesLineage: normalizedSpecies,
  );
}

PurityStatBonus purityStatBonusForStatus(InstancePurityStatus status) {
  if (status.isPure) {
    return const PurityStatBonus(
      intelligence: 0.25,
      strength: 0.25,
      beauty: 0.25,
    );
  }
  if (status.isElementallyPure) {
    return const PurityStatBonus(beauty: 0.25);
  }
  if (status.isSpeciesPure) {
    return const PurityStatBonus(strength: 0.25);
  }
  return const PurityStatBonus();
}

InstancePurityStatus classifyInstancePurity(
  CreatureInstance instance, {
  Creature? species,
}) {
  final fallbackElement =
      (instance.generationDepth == 0 &&
          species != null &&
          species.types.isNotEmpty)
      ? species.types.first
      : null;
  final fallbackSpecies = (instance.generationDepth == 0)
      ? _normalizedSpeciesLine(species?.mutationFamily)
      : null;

  return classifyPurityFromLineages(
    elementLineage: decodePurityLineage(
      instance.elementLineageJson,
      fallbackKey: fallbackElement,
    ),
    speciesLineage: decodePurityLineage(
      instance.familyLineageJson,
      fallbackKey: fallbackSpecies,
    ),
  );
}

bool matchesPurityFilter(
  CreatureInstance instance, {
  required InstancePurityFilter filter,
  Creature? species,
}) {
  if (filter == InstancePurityFilter.all) return true;
  final status = classifyInstancePurity(instance, species: species);
  return switch (filter) {
    InstancePurityFilter.all => true,
    InstancePurityFilter.elemental => status.isElementallyPure,
    InstancePurityFilter.species => status.isSpeciesPure,
    InstancePurityFilter.pure => status.isPure,
  };
}

Map<String, int> decodePurityLineage(String? raw, {String? fallbackKey}) {
  if (raw != null && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final out = <String, int>{};
        decoded.forEach((key, value) {
          final normalizedKey = _normalizeLineageKey(key.toString());
          final count = value is num ? value.toInt() : int.tryParse('$value');
          if (normalizedKey.isNotEmpty && count != null && count > 0) {
            out[normalizedKey] = count;
          }
        });
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
  }

  final normalizedFallback = _normalizeLineageKey(fallbackKey);
  if (normalizedFallback.isNotEmpty) {
    return {normalizedFallback: 1};
  }
  return const {};
}

String founderSourceLabel(String source) {
  return switch (source) {
    'wild_capture' || 'wild' => 'Wild Capture',
    'starter' => 'Starter',
    'vial' || 'breeding_vial' => 'Vial Extraction',
    'planet_summon' => 'Planet Summon',
    'rift_portal' => 'Rift Portal',
    'quest' => 'Quest Reward',
    'elemental_nexus' => 'Elemental Nexus',
    _ => 'Discovery',
  };
}

String generationLabel(int generationDepth) {
  return generationDepth == 0 ? 'Founder' : 'Gen $generationDepth';
}

String _normalizeLineageKey(String? key) {
  if (key == null) return '';
  var normalized = key.trim();
  if (normalized.startsWith('CreatureFamily.')) {
    normalized = normalized.split('.').last;
  }
  return normalized;
}

String? _normalizedSpeciesLine(String? family) {
  final normalized = _normalizeLineageKey(family);
  return normalized.isEmpty ? null : normalized;
}
