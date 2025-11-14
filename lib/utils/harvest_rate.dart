import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/genetics_util.dart';
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
  final nature = (inst.natureId ?? '').toLowerCase();
  final natureBonusPct = switch (nature) {
    'metabolic' => 20,
    'sluggish' => -20,
    _ => 0,
  };
  rate *= (1 + natureBonusPct / 100);

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

  // final rounding
  return (rate * 0.5).round().clamp(0, 5000);
}
