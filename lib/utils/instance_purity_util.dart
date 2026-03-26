import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';

enum InstancePurityFilter {
  all,
  elemental,
  species,
  pure;

  InstancePurityFilter next() =>
      values[(index + 1) % InstancePurityFilter.values.length];

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

  return InstancePurityStatus(
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
