// lib/models/encounters/encounter_pool.dart
import 'dart:convert';

enum EncounterRarity { common, uncommon, rare, legendary }

extension EncounterRarityX on EncounterRarity {
  String get label => toString().split('.').last;

  static EncounterRarity parse(String v) =>
      EncounterRarity.values.firstWhere((e) => e.label == v);

  double get baseWeight {
    switch (this) {
      case EncounterRarity.common:
        return 60;
      case EncounterRarity.uncommon:
        return 25;
      case EncounterRarity.rare:
        return 10;
      case EncounterRarity.legendary:
        return 2;
    }
  }
}

/// One possible spawn option in a pool (RNG only).
class EncounterEntry {
  final String speciesId; // e.g. 'CR045'
  final EncounterRarity rarity; // for weighting & UI label
  final double weightMul; // per-species multiplier
  final bool Function(DateTime now)?
  condition; // optional gate (time/weather/etc.)

  const EncounterEntry({
    required this.speciesId,
    required this.rarity,
    this.weightMul = 1.0,
    this.condition,
  });

  double effectiveWeight(DateTime now) {
    if (condition != null && !condition!(now)) return 0;
    return rarity.baseWeight * weightMul;
  }

  Map<String, dynamic> toJson() => {
    'speciesId': speciesId,
    'rarity': rarity.label,
    'weightMul': weightMul,
  };

  factory EncounterEntry.fromJson(Map<String, dynamic> json) => EncounterEntry(
    speciesId: json['speciesId'] as String,
    rarity: EncounterRarityX.parse(json['rarity'] as String),
    weightMul: (json['weightMul'] as num?)?.toDouble() ?? 1.0,
  );
}

/// Cumulative thresholds for a roll in [0,1):
/// compare in order: legendary → rare → uncommon; else common.
class RarityWeights {
  final double legendary;
  final double rare;
  final double uncommon;

  const RarityWeights({
    required this.legendary,
    required this.rare,
    required this.uncommon,
  });
}

class EncounterPool {
  final List<EncounterEntry> entries;
  const EncounterPool({required this.entries});

  bool get isEmpty => entries.isEmpty;

  EncounterPool scaled(double factor) => EncounterPool(
    entries: entries
        .map(
          (e) => EncounterEntry(
            speciesId: e.speciesId,
            rarity: e.rarity,
            weightMul: e.weightMul * factor,
            condition: e.condition,
          ),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory EncounterPool.fromJson(Map<String, dynamic> json) => EncounterPool(
    entries: (json['entries'] as List)
        .map((e) => EncounterEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  static EncounterPool fromJsonString(String s) =>
      EncounterPool.fromJson(jsonDecode(s) as Map<String, dynamic>);
  String toJsonString() => jsonEncode(toJson());

  // ---- support for WildernessSpawnService ----

  /// Species grouped by rarity (filters out gated/zero-weight entries).
  Map<EncounterRarity, List<String>> get speciesByRarity {
    final map = {for (final r in EncounterRarity.values) r: <String>[]};
    final now = DateTime.now();
    for (final e in entries) {
      if (e.effectiveWeight(now) <= 0) continue;
      map[e.rarity]!.add(e.speciesId);
    }
    return map;
  }

  /// Cumulative thresholds in [0,1) for: legendary → rare → uncommon.
  RarityWeights get rarityWeights {
    final now = DateTime.now();

    double sumFor(EncounterRarity r) => entries
        .where((e) => e.rarity == r)
        .map((e) => e.effectiveWeight(now))
        .fold<double>(0, (a, b) => a + b);

    final wCommon = sumFor(EncounterRarity.common);
    final wUncommon = sumFor(EncounterRarity.uncommon);
    final wRare = sumFor(EncounterRarity.rare);
    final wLegendary = sumFor(EncounterRarity.legendary);

    final total = wCommon + wUncommon + wRare + wLegendary;

    if (total <= 0) {
      // fallback to base proportions
      final base = {
        EncounterRarity.legendary: EncounterRarity.legendary.baseWeight,
        EncounterRarity.rare: EncounterRarity.rare.baseWeight,
        EncounterRarity.uncommon: EncounterRarity.uncommon.baseWeight,
        EncounterRarity.common: EncounterRarity.common.baseWeight,
      };
      final baseTotal = base.values.fold<double>(0, (a, b) => a + b);
      double p(EncounterRarity r) => base[r]! / baseTotal;

      final tLegendary = p(EncounterRarity.legendary);
      final tRare = tLegendary + p(EncounterRarity.rare);
      final tUncommon = tRare + p(EncounterRarity.uncommon);

      return RarityWeights(
        legendary: tLegendary,
        rare: tRare,
        uncommon: tUncommon,
      );
    }

    double norm(double w) => w / total;

    final pLegendary = norm(wLegendary);
    final pRare = norm(wRare);
    final pUncommon = norm(wUncommon);

    final tLegendary = pLegendary;
    final tRare = tLegendary + pRare;
    final tUncommon = tRare + pUncommon;

    return RarityWeights(
      legendary: tLegendary,
      rare: tRare,
      uncommon: tUncommon,
    );
  }
}
