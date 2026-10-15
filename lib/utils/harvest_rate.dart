import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/parent_snapshot.dart'; // CreatureInstance
import 'package:alchemons/models/wild_fusion.dart';

/// What an Alchemized Alchemon extracts a minute, whatever its level or
/// size: ten times a level-10 Alchemon of normal size (6/min). Its natures
/// still count, on top.
const int kAlchemizedHarvestRate = 60;

/// How much faster [inst]'s natures make it harvest (Metabolic, Anabolic,
/// Hypermetabolic; both of its natures count).
double harvestNatureMultiplier(CreatureInstance inst) {
  var mult = 1.0;
  for (final id in [inst.natureId, inst.natureId2]) {
    if (id == null || id.isEmpty) continue;
    mult *=
        NatureCatalog.byId(
          id,
        )?.effect.getDouble('harvest_rate_mult', fallback: 1) ??
        1;
  }
  return mult;
}

int computeHarvestRatePerMinute(
  CreatureInstance inst, {
  bool hasMatchingElement = true,
}) {
  final natures = harvestNatureMultiplier(inst);
  if (inst.mutation == AlchemonMutation.alchemized.id) {
    return (kAlchemizedHarvestRate * natures).round();
  }

  // base
  double rate = 1 + (inst.level - 1);

  // element bonus
  if (hasMatchingElement) {
    rate *= 1.25;
  }

  rate *= natures;

  // size multiplier
  final genetics = decodeGenetics(inst.geneticsJson);
  final sizeKey = (genetics?.get('size') ?? '').toLowerCase();
  final sizeMult = switch (sizeKey) {
    'tiny' => 0.4,
    'small' => 0.7,
    'normal' => .9,
    'large' => 1.1,
    'giant' => 1.3,
    _ => 1.0,
  };
  rate *= sizeMult;

  // final rounding: biome extraction should never yield 0 per minute
  return (rate * 0.5).round().clamp(1, 5000);
}
