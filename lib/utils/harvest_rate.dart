import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/parent_snapshot.dart'; // CreatureInstance
import 'package:alchemons/models/wild_fusion.dart';

/// What an Alchemized Alchemon extracts a minute, whatever its level, size or
/// nature: ten times a level-10 Alchemon of normal size (6/min).
const int kAlchemizedHarvestRate = 60;

int computeHarvestRatePerMinute(
  CreatureInstance inst, {
  bool hasMatchingElement = true,
}) {
  if (inst.mutation == AlchemonMutation.alchemized.id) {
    return kAlchemizedHarvestRate;
  }

  // base
  double rate = 1 + (inst.level - 1);

  // element bonus
  if (hasMatchingElement) {
    rate *= 1.25;
  }

  // nature bonus
  for (final id in [inst.natureId, inst.natureId2]) {
    if (id == null || id.isEmpty) continue;
    rate *=
        NatureCatalog.byId(
          id,
        )?.effect.getDouble('harvest_rate_mult', fallback: 1) ??
        1;
  }

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
