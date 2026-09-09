// services/wilderness_service.dart
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/inventory.dart';

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
  final Random _rng;

  WildernessService(this.db, {Random? rng}) : _rng = rng ?? Random();

  // Breed success calc: base * (1 + partyLuck) * matchup multiplier, clamped

  double computeBreedChance({
    required double base,
    required double partyLuck,
    required double matchupMult, // e.g., type synergy 0.8..1.3
    bool hasEartherPerk = false,
    double wildernessBonus = 0.0,
  }) {
    double c = base * (1.0 + partyLuck) * matchupMult;

    if (hasEartherPerk) {
      c *= 1.25; // Earther: +25% success
    }
    c += wildernessBonus;

    return c.clamp(0.01, 0.95);
  }

  Future<int> wildFusionQuantity() =>
      db.inventoryDao.getItemQty(InvKeys.wildFusion);

  /// A Wild Fusion is an encounter charge, not creature stamina. It is spent
  /// when the stability attempt begins, whether that attempt succeeds or not.
  Future<bool> consumeWildFusion() =>
      db.inventoryDao.consumeItem(InvKeys.wildFusion);

  // The actual roll
  bool rollSuccess(double p) => _rng.nextDouble() < p;
}
