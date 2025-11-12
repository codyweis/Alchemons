// services/wilderness_service.dart
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/services/stamina_service.dart';

double breedChanceForRarity(EncounterRarity rarity) {
  switch (rarity) {
    case EncounterRarity.common:
      return 0.90;
    case EncounterRarity.uncommon:
      return 0.65;
    case EncounterRarity.rare:
      return 0.40;
    case EncounterRarity.legendary:
      return 0.25;
  }
}

class WildernessService {
  final AlchemonsDatabase db;
  final StaminaService stamina;
  final Random _rng;

  WildernessService(this.db, this.stamina, {Random? rng})
    : _rng = rng ?? Random();

  // Breed success calc: base * (1 + partyLuck) * matchup multiplier, clamped

  double computeBreedChance({
    required double base,
    required double partyLuck,
    required double matchupMult, // e.g., type synergy 0.8..1.3
    bool hasEartherPerk = false,
  }) {
    double c = base * (1.0 + partyLuck) * matchupMult;

    if (hasEartherPerk) {
      c *= 1.25; // Earther: +25% success
    }

    return c.clamp(0.01, 0.95);
  }

  // Spend 1 bar on the chosen instance if possible, return updated row or null if not enough
  Future<CreatureInstance?> trySpendForAttempt(String instanceId) async {
    final ok = await stamina.canBreed(instanceId);
    if (!ok) return null;
    return stamina.spendForBreeding(instanceId);
  }

  // The actual roll
  bool rollSuccess(double p) => _rng.nextDouble() < p;
}
