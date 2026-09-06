import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/parent_snapshot.dart'; // CreatureInstance

int computeHarvestRatePerMinute(
  CreatureInstance inst, {
  bool hasMatchingElement = true,
}) {
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
