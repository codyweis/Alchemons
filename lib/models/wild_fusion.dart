// lib/models/wild_fusion.dart
//
// What fusing with a wild Alchemon gives that the Fusion Chamber cannot.
//
// Harvesting a wild specimen keeps it as a parent for ever, so a wild fusion
// that only ran the chamber's recipe was always the worse trade. Two things
// make it worth the catalyst:
//
//   • The wild parent's highest Potential always reaches the child.
//   • A fusion in the wilderness can, rarely, mutate the child into something
//     no chamber produces. Mutations belong to the individual: they are never
//     inherited.

import 'dart:math' as math;

import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/potential_genetics.dart';

/// The wild parent's single highest Potential: the one a wild fusion always
/// passes on. Ties go to the stat read first (SPD, INT, STR, BEA), which is
/// the order the scanner shows them in — what the player sees marked is what
/// the child gets.
({StatKind stat, double value})? wildTopPotential(CreatureStats? stats) {
  if (stats == null) return null;
  final readings = <(StatKind, double)>[
    (StatKind.speed, stats.speedPotential),
    (StatKind.intelligence, stats.intelligencePotential),
    (StatKind.strength, stats.strengthPotential),
    (StatKind.beauty, stats.beautyPotential),
  ];
  var best = readings.first;
  for (final r in readings.skip(1)) {
    if (r.$2 > best.$2) best = r;
  }
  return (stat: best.$1, value: best.$2);
}

/// A rare change to one individual, from a fusion in the wilderness.
enum AlchemonMutation {
  /// Made of grains, permanently: the summoning's particles, never settling
  /// back into a sprite.
  alchemized('alchemized', 'Alchemized'),

  /// Turned to gold.
  transmuted('transmuted', 'Transmuted');

  const AlchemonMutation(this.id, this.label);

  /// Storage form, on the instance and in a cultivation's payload.
  final String id;
  final String label;

  static AlchemonMutation? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final m in values) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The chance of each, per wilderness fusion.
  static const double chance = 0.01;

  /// Rolls the mutation for a child of a wilderness fusion, or none.
  ///
  /// At most one: a single roll is split between them. A prismatic child can
  /// be Alchemized (its grains go rainbow) but never Transmuted — gold would
  /// cover the prismatic, and a prismatic is never thrown away.
  static AlchemonMutation? roll(math.Random rng, {required bool prismatic}) {
    final r = rng.nextDouble();
    if (r < chance) return alchemized;
    if (r < chance * 2 && !prismatic) return transmuted;
    return null;
  }
}
