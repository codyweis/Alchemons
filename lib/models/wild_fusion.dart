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
//     inherited. The mutation meter (a constellation node) makes each
//     fusion that doesn't mutate raise the chance of the next.

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

/// Notches in the mutation meter: a full meter makes the next wilderness
/// fusion mutate.
const int kMutationMeterNotches = 100;

/// The chance that a wilderness fusion mutates, with [notches] in the
/// mutation meter: 0.5% empty, about 2% half full, 10% one short of full,
/// certain when full. Without the meter (its constellation node not yet
/// unlocked) every fusion rolls at the empty rate.
double mutationChance(int notches) {
  if (notches >= kMutationMeterNotches) return 1.0;
  final n = notches.clamp(0, kMutationMeterNotches - 1);
  return 0.005 + 0.095 * math.pow(n / (kMutationMeterNotches - 1), 2.7);
}

/// A rare change to one individual, from a fusion in the wilderness.
enum AlchemonMutation {
  /// Made of grains, permanently: the summoning's particles, never settling
  /// back into a sprite.
  alchemized('alchemized', 'Alchemized'),

  /// Turned to gold.
  transmuted('transmuted', 'Transmuted'),

  /// A rainbow running down the body. Also what a rift's Alchemon carries.
  prismatic('prismatic', 'Prismatic'),

  /// Liquid silver.
  silverlite('silverlite', 'Silverlite'),

  /// A night sky inside the body.
  starlit('starlit', 'Starlit'),

  /// Black glass, its element's light in its lines.
  obsidian('obsidian', 'Obsidian');

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

  /// What it does that no other Alchemon does, in one line.
  String get perk => switch (this) {
    alchemized => 'Collects 60 essence a minute at any level.',
    transmuted => 'Sells for 50 gold.',
    prismatic => '+1% to all four stats.',
    silverlite => 'Sells for 10,000 silver.',
    starlit => 'Levels up three times as fast.',
    obsidian => 'Eggs it fuses extract in half the time.',
  };

  /// Rolls the mutation for a child of a wilderness fusion, or none, with
  /// [notches] in the mutation meter. Which one is an even pick.
  static AlchemonMutation? roll(math.Random rng, {int notches = 0}) {
    if (rng.nextDouble() >= mutationChance(notches)) return null;
    return values[rng.nextInt(values.length)];
  }
}

/// Whether a creature with the old prismatic flag [flag] and [mutation] is a
/// Prismatic: the mutation says so, or the flag does and nothing else holds
/// the mutation slot.
bool prismaticMutation(bool flag, String? mutation) =>
    mutation == AlchemonMutation.prismatic.id ||
    (flag && (mutation == null || mutation.isEmpty));

/// What a Prismatic adds to each of its four stats.
const double kPrismaticStatBonus = 0.01;

/// How much faster a Starlit gains XP.
const double kStarlitXpMultiplier = 3.0;

/// What an Obsidian parent does to its egg's extraction time.
const double kObsidianCultivationMultiplier = 0.5;
