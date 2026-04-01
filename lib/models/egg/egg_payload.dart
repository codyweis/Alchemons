import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/wilderness_stat_ranges.dart';
import 'package:alchemons/services/creature_repository.dart';

class EggPayload {
  // Required fields
  final String baseId;
  final String rarity;
  final String source; // 'breeding', 'wild', 'starter', 'quest', etc.
  final String? vialName;

  // Creature attributes
  final String? natureId;
  final bool isPrismaticSkin;
  final Map<String, String> genetics;

  // Stats (current values)
  final CreatureStats stats;

  // Potentials
  final CreatureStatPotentials potentials;

  // Lineage data
  final LineageData lineage;

  // Optional breeding context
  final ParentageData? parentage;
  final String? likelihoodAnalysisJson;

  EggPayload({
    required this.baseId,
    required this.rarity,
    required this.source,
    this.vialName,
    this.natureId,
    this.isPrismaticSkin = false,
    required this.genetics,
    required this.stats,
    required this.potentials,
    required this.lineage,
    this.parentage,
    this.likelihoodAnalysisJson,
  });

  Map<String, dynamic> toJson() {
    return {
      'baseId': baseId,
      'rarity': rarity,
      'source': source,
      if (vialName != null) 'vialName': vialName,
      'natureId': natureId,
      'isPrismaticSkin': isPrismaticSkin,
      'genetics': genetics,
      'stats': stats.toJson(),
      'statPotentials': potentials.toJson(),
      'lineage': lineage.toJson(),
      if (parentage != null) 'parentage': parentage!.toJson(),
      if (likelihoodAnalysisJson != null)
        'likelihoodAnalysis': likelihoodAnalysisJson,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory EggPayload.fromJson(Map<String, dynamic> json) {
    return EggPayload(
      baseId: json['baseId'] as String,
      rarity: json['rarity'] as String,
      source: json['source'] as String? ?? 'unknown',
      vialName: (json['vialName'] as String?) ?? (json['name'] as String?),
      natureId: json['natureId'] as String?,
      isPrismaticSkin: json['isPrismaticSkin'] as bool? ?? false,
      genetics: Map<String, String>.from(json['genetics'] as Map? ?? {}),
      stats: CreatureStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      potentials: CreatureStatPotentials.fromJson(
        json['statPotentials'] as Map<String, dynamic>? ?? {},
      ),
      lineage: LineageData.fromJson(
        json['lineage'] as Map<String, dynamic>? ?? {},
      ),
      parentage: json['parentage'] != null
          ? ParentageData.fromJson(json['parentage'] as Map<String, dynamic>)
          : null,
      likelihoodAnalysisJson: json['likelihoodAnalysis'] as String?,
    );
  }
}

// Supporting classes with toJson/fromJson
class CreatureStats {
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  const CreatureStats({
    required this.speed,
    required this.intelligence,
    required this.strength,
    required this.beauty,
  });

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'intelligence': intelligence,
    'strength': strength,
    'beauty': beauty,
  };

  factory CreatureStats.fromJson(Map<String, dynamic> json) {
    return CreatureStats(
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      intelligence: (json['intelligence'] as num?)?.toDouble() ?? 0.0,
      strength: (json['strength'] as num?)?.toDouble() ?? 0.0,
      beauty: (json['beauty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CreatureStatPotentials {
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  const CreatureStatPotentials({
    required this.speed,
    required this.intelligence,
    required this.strength,
    required this.beauty,
  });

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'intelligence': intelligence,
    'strength': strength,
    'beauty': beauty,
  };

  factory CreatureStatPotentials.fromJson(Map<String, dynamic> json) {
    return CreatureStatPotentials(
      speed: (json['speed'] as num?)?.toDouble() ?? 3.0,
      intelligence: (json['intelligence'] as num?)?.toDouble() ?? 3.0,
      strength: (json['strength'] as num?)?.toDouble() ?? 3.0,
      beauty: (json['beauty'] as num?)?.toDouble() ?? 3.0,
    );
  }
}

class LineageData {
  final int generationDepth;
  final String? nativeFaction;
  final String? variantFaction;
  final Map<String, int> factionLineage;
  final Map<String, int> elementLineage;
  final Map<String, int> familyLineage;
  final bool isPure;

  const LineageData({
    required this.generationDepth,
    this.nativeFaction,
    this.variantFaction,
    required this.factionLineage,
    required this.elementLineage,
    required this.familyLineage,
    this.isPure = false,
  });

  Map<String, dynamic> toJson() => {
    'generationDepth': generationDepth,
    'nativeFaction': nativeFaction,
    'variantFaction': variantFaction,
    'factionLineage': factionLineage,
    'elementLineage': elementLineage,
    'familyLineage': familyLineage,
    'isPure': isPure,
  };

  factory LineageData.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseLineageMap(dynamic value) {
      if (value is! Map) return {};
      return value.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      );
    }

    return LineageData(
      generationDepth: (json['generationDepth'] as num?)?.toInt() ?? 0,
      nativeFaction: json['nativeFaction'] as String?,
      variantFaction: json['variantFaction'] as String?,
      factionLineage: parseLineageMap(json['factionLineage']),
      elementLineage: parseLineageMap(json['elementLineage']),
      familyLineage: parseLineageMap(json['familyLineage']),
      isPure: json['isPure'] as bool? ?? false,
    );
  }
}

class ParentageData {
  final ParentSnapshot parentA;
  final ParentSnapshot parentB;

  ParentageData({required this.parentA, required this.parentB});

  Map<String, dynamic> toJson() => {
    'parentA': parentA.toJson(),
    'parentB': parentB.toJson(),
  };

  factory ParentageData.fromJson(Map<String, dynamic> json) {
    return ParentageData(
      parentA: ParentSnapshot.fromJson(json['parentA'] as Map<String, dynamic>),
      parentB: ParentSnapshot.fromJson(json['parentB'] as Map<String, dynamic>),
    );
  }
}

// lib/services/egg_payload_factory.dart

class EggPayloadFactory {
  final CreatureCatalog repository;
  final Random _random;

  EggPayloadFactory(this.repository, {Random? random})
    : _random = random ?? Random();

  EggPayload createWildCapturePayload(
    Creature creature, {
    String? sourceOverride,
    bool arcaneBoostUnlocked = false,
  }) {
    final rng = _random;
    final statRange = wildernessStatRangeForRarity(
      creature.rarity,
      arcaneBoostUnlocked: arcaneBoostUnlocked,
    );
    final rolledStats = _rollStatBlock(rng, statRange);
    final primaryElement = creature.types.isNotEmpty
        ? creature.types.first
        : null;
    final nativeFaction = elementalGroupNameOf(creature);
    final family = creature.mutationFamily;
    // If the creature already has stats set (e.g. nexus fixed-stat encounters),
    // honour them instead of re-rolling from rarity ranges.
    final hasFixedStats = creature.stats != null;

    return EggPayload(
      baseId: creature.id,
      rarity: creature.rarity,
      source: sourceOverride ?? 'wild_capture',
      natureId: creature.nature?.id,
      isPrismaticSkin: creature.isPrismaticSkin,
      genetics: creature.genetics?.variants ?? {},
      stats: hasFixedStats
          ? CreatureStats(
              speed: creature.stats!.speed,
              intelligence: creature.stats!.intelligence,
              strength: creature.stats!.strength,
              beauty: creature.stats!.beauty,
            )
          : rolledStats.stats,
      potentials: hasFixedStats
          ? CreatureStatPotentials(
              speed: creature.stats!.speedPotential,
              intelligence: creature.stats!.intelligencePotential,
              strength: creature.stats!.strengthPotential,
              beauty: creature.stats!.beautyPotential,
            )
          : rolledStats.potentials,
      parentage: null,
      lineage: LineageData(
        generationDepth: 0,
        nativeFaction: nativeFaction,
        variantFaction: null,
        factionLineage: {nativeFaction: 1},
        elementLineage: {
          if (primaryElement != null && primaryElement.isNotEmpty)
            primaryElement: 1,
        },
        familyLineage: {if (family != null && family.isNotEmpty) family: 1},
        isPure: true,
      ),
    );
  }

  /// Create payload from a breeding result
  EggPayload fromBreedingResult(
    Creature offspring, {
    String? likelihoodAnalysisJson,
  }) {
    return EggPayload(
      baseId: offspring.id,
      rarity: offspring.rarity,
      source: 'standard_fusion',
      natureId: offspring.nature?.id,
      isPrismaticSkin: offspring.isPrismaticSkin,
      genetics: offspring.genetics?.variants ?? {},
      stats: CreatureStats(
        speed: offspring.stats?.speed ?? 0.0,
        intelligence: offspring.stats?.intelligence ?? 0.0,
        strength: offspring.stats?.strength ?? 0.0,
        beauty: offspring.stats?.beauty ?? 0.0,
      ),
      potentials: CreatureStatPotentials(
        speed: offspring.stats?.speedPotential ?? 3.0,
        intelligence: offspring.stats?.intelligencePotential ?? 3.0,
        strength: offspring.stats?.strengthPotential ?? 3.0,
        beauty: offspring.stats?.beautyPotential ?? 3.0,
      ),
      lineage: _extractLineageData(offspring),
      parentage: offspring.parentage != null
          ? ParentageData(
              parentA: offspring.parentage!.parentA,
              parentB: offspring.parentage!.parentB,
            )
          : null,
      likelihoodAnalysisJson: likelihoodAnalysisJson,
    );
  }

  /// Create payload for starter creature
  EggPayload createStarterPayload(
    String baseId,
    FactionId faction, {
    int? seed,
  }) {
    final actualSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    final rng = Random(actualSeed);

    final factionType = _factionKey(faction);
    final starter = repository.getCreatureById(baseId);
    final elementType = starter?.types.isNotEmpty == true
        ? starter!.types.first
        : switch (factionType) {
            'volcanic' => 'Fire',
            'oceanic' => 'Water',
            'earthen' => 'Earth',
            'verdant' => 'Air',
            _ => 'Neutral',
          };
    final nativeFaction = starter != null
        ? elementalGroupNameOf(starter)
        : factionType;
    final family = starter?.mutationFamily;
    return EggPayload(
      baseId: baseId,
      rarity: starter?.rarity ?? 'Common',
      source: 'starter',
      natureId: NatureCatalogWeighted.weightedRandom(rng).id,
      isPrismaticSkin: false,
      genetics: {
        'seed': (actualSeed & 0x7fffffff).toString(),
        'mutations': '[]',
        'dominanceBias': 'none',
      },
      stats: CreatureStats(
        speed: _lowRoll(rng, min: 0, max: 1),
        intelligence: _lowRoll(rng, min: 0, max: 1),
        strength: _lowRoll(rng, min: 0, max: 1),
        beauty: _lowRoll(rng, min: 0, max: 1),
      ),
      potentials: CreatureStatPotentials(
        speed: _lowRoll(rng, min: 1, max: 2),
        intelligence: _lowRoll(rng, min: 1, max: 2),
        strength: _lowRoll(rng, min: 1, max: 2),
        beauty: _lowRoll(rng, min: 1, max: 2),
      ),
      parentage: null,
      lineage: LineageData(
        generationDepth: 0,
        nativeFaction: nativeFaction,
        variantFaction: null,
        factionLineage: {nativeFaction: 1},
        elementLineage: {if (elementType.isNotEmpty) elementType: 1},
        familyLineage: {if (family != null && family.isNotEmpty) family: 1},
        isPure: true,
      ),
    );
  }

  /// Create payload for wild breeding
  /// Randomizes wild creature's stats/genetics for breeding consistency
  EggPayload fromWildBreeding(
    Creature offspring,
    CreatureInstance ownedParent,
    Creature wildParent, {
    String? likelihoodAnalysisJson,
    String? sourceOverride,
  }) {
    // Wild creatures get randomized attributes

    final parentageData = ParentageData(
      parentA: ParentSnapshot.fromDbInstance(ownedParent, repository),
      parentB: ParentSnapshot.fromCreature(wildParent),
    );

    return EggPayload(
      baseId: offspring.id,
      rarity: offspring.rarity,
      source: sourceOverride ?? 'wild_fusion',
      natureId: offspring.nature?.id,
      isPrismaticSkin: offspring.isPrismaticSkin,
      genetics: offspring.genetics?.variants ?? {},
      stats: CreatureStats(
        speed: offspring.stats?.speed ?? 0.0,
        intelligence: offspring.stats?.intelligence ?? 0.0,
        strength: offspring.stats?.strength ?? 0.0,
        beauty: offspring.stats?.beauty ?? 0.0,
      ),
      potentials: CreatureStatPotentials(
        speed: offspring.stats?.speedPotential ?? 3.0,
        intelligence: offspring.stats?.intelligencePotential ?? 3.0,
        strength: offspring.stats?.strengthPotential ?? 3.0,
        beauty: offspring.stats?.beautyPotential ?? 3.0,
      ),
      lineage: _extractLineageData(offspring),
      parentage: parentageData,
      likelihoodAnalysisJson: likelihoodAnalysisJson,
    );
  }

  EggPayload createVialPayload(Creature creature, {String? vialName}) {
    final rng = _random;
    final primaryElement = creature.types.isNotEmpty
        ? creature.types.first
        : null;
    final nativeFaction = elementalGroupNameOf(creature);
    final family = creature.mutationFamily;

    // Vials get random nature
    final nature = NatureCatalogWeighted.weightedRandom(rng);

    // Stats based on rarity
    final statRange = _getVialStatRangeForRarity(creature.rarity);
    final rolledStats = _rollStatBlock(rng, statRange);

    return EggPayload(
      baseId: creature.id,
      rarity: creature.rarity,
      source: 'vial', // Track that this came from a vial
      vialName: vialName,
      natureId: nature.id,
      isPrismaticSkin: false,
      genetics: creature.genetics?.variants ?? {},
      stats: rolledStats.stats,
      parentage: null,
      potentials: rolledStats.potentials,
      lineage: LineageData(
        generationDepth: 0, // Vials are Gen 0
        nativeFaction: nativeFaction,
        variantFaction: null,
        factionLineage: {nativeFaction: 1},
        elementLineage: {
          if (primaryElement != null && primaryElement.isNotEmpty)
            primaryElement: 1,
        },
        familyLineage: {if (family != null && family.isNotEmpty) family: 1},
        isPure: true, // Vials are pure
      ),
    );
  }

  // Helper for stat ranges by rarity
  ({double min, double max, double potMin, double potMax})
  _getVialStatRangeForRarity(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return (min: 0.0, max: 1.0, potMin: 1.0, potMax: 2.0);
      case 'uncommon':
        return (min: 0.5, max: 1.5, potMin: 1.5, potMax: 2.5);
      case 'rare':
        return (min: 1.0, max: 1.5, potMin: 1.5, potMax: 3.0);
      case 'legendary':
        return (min: 1.5, max: 3.5, potMin: 1.5, potMax: 3.5);
      default:
        return (min: 0.0, max: 1.0, potMin: 1.0, potMax: 2.0);
    }
  }

  ({CreatureStats stats, CreatureStatPotentials potentials}) _rollStatBlock(
    Random rng,
    WildernessStatRange range,
  ) {
    final speed = _rollStatPair(rng, range);
    final intelligence = _rollStatPair(rng, range);
    final strength = _rollStatPair(rng, range);
    final beauty = _rollStatPair(rng, range);

    return (
      stats: CreatureStats(
        speed: speed.stat,
        intelligence: intelligence.stat,
        strength: strength.stat,
        beauty: beauty.stat,
      ),
      potentials: CreatureStatPotentials(
        speed: speed.potential,
        intelligence: intelligence.potential,
        strength: strength.potential,
        beauty: beauty.potential,
      ),
    );
  }

  ({double stat, double potential}) _rollStatPair(
    Random rng,
    WildernessStatRange range,
  ) {
    final potential = _rollInRange(rng, range.potMin, range.potMax);
    final statMax = min(range.max, potential);
    return (stat: _rollInRange(rng, range.min, statMax), potential: potential);
  }

  double _rollInRange(Random rng, double min, double max) {
    return min + (rng.nextDouble() * (max - min));
  }

  // Helper methods

  LineageData _extractLineageData(Creature creature) {
    final lineage = creature.lineageData;
    return LineageData(
      generationDepth: lineage?.generationDepth ?? 0,
      nativeFaction: lineage?.nativeFaction,
      variantFaction: lineage?.variantFaction,
      factionLineage: lineage?.factionLineage ?? {},
      elementLineage: lineage?.elementLineage ?? {},
      familyLineage: lineage?.familyLineage ?? {},
      isPure: creature.isPure,
    );
  }

  double _lowRoll(Random rng, {required double min, required double max}) {
    final r = rng.nextDouble();
    final skewed = pow(r, 1.5).toDouble();
    return min + skewed * (max - min);
  }

  String _factionKey(FactionId faction) {
    switch (faction) {
      case FactionId.volcanic:
        return 'volcanic';
      case FactionId.oceanic:
        return 'oceanic';
      case FactionId.earthen:
        return 'earthen';
      case FactionId.verdant:
        return 'verdant';
    }
  }
}
