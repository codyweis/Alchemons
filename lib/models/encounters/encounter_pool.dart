// lib/models/encounters/encounter_pool.dart
import 'dart:convert';

enum EncounterRarity { common, uncommon, rare, epic, legendary }

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
      case EncounterRarity.epic:
        return 4;
      case EncounterRarity.legendary:
        return 1;
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

  // JSON helpers (condition is code, so it’s not serialized)
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
}
