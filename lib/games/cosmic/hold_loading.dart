// lib/games/cosmic/hold_loading.dart
//
// Taking elements out of home storage and into the ship's hold. Gates take
// only what the ship carries, so a gate's pattern can be packed at home
// from what is stored instead of gathered grain by grain in flight.

import 'cosmic_data.dart';

/// What to load to offer [recipe] at its gate: [capacity] units in all
/// (an offering wants a full hold), split as the recipe asks. The recipe's
/// free share is packed with the most plentiful element it does not name;
/// when there is none, the planet's own element takes it.
///
/// [available] is everything that could go in: home storage plus whatever
/// the hold already carries, since loading for a pattern empties the hold
/// back into storage first. Null when [available] cannot cover the plan.
Map<String, int>? planGateLoad(
  PlanetRecipe recipe,
  Map<String, double> available, {
  int capacity = ElementMeter.maxCapacityUnits,
}) {
  final plan = <String, int>{};
  var placed = 0;
  // Recipe shares are whole percents; scale them to the hold and give the
  // rounding to the largest share so the plan always fills it exactly.
  final shares = recipe.components.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in shares) {
    final units = (e.value / 100 * capacity).round();
    if (units <= 0) continue;
    plan[e.key] = units;
    placed += units;
  }
  final free = capacity - placed;
  if (free > 0) {
    String? filler;
    var most = 0.0;
    for (final e in available.entries) {
      if (recipe.components.containsKey(e.key)) continue;
      if (!kElementColors.containsKey(e.key)) continue;
      if (e.value >= free && e.value > most) {
        most = e.value;
        filler = e.key;
      }
    }
    final into = filler ?? recipe.planetElement;
    plan[into] = (plan[into] ?? 0) + free;
  } else if (free < 0 && shares.isNotEmpty) {
    final top = shares.first.key;
    plan[top] = plan[top]! + free;
  }
  for (final e in plan.entries) {
    if ((available[e.key] ?? 0) + 1e-6 < e.value) return null;
  }
  return plan;
}

/// [a] and [b] added together, element by element.
Map<String, double> addElementMaps(
  Map<String, double> a,
  Map<String, double> b,
) {
  final out = Map<String, double>.from(a);
  for (final e in b.entries) {
    out[e.key] = (out[e.key] ?? 0) + e.value;
  }
  return out;
}
