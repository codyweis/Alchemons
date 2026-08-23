// lib/games/shared/companion_stance.dart
//
// Where an Alchemon wants to stand while it fights.
//
// Every companion the player is NOT driving used to hold the same distance —
// 72% of its own attack range — whatever family it was. So a kin artillery
// piece and a horn bruiser jostled on the same ring, and a wing stood still
// like everything else. The families read as identical in a fight even though
// they play completely differently in the player's hands.
//
// A stance is expressed as a fraction of the companion's OWN attack range, not
// as an absolute distance: range already varies per Alchemon, and the point is
// "how far back does this family like to be", not "how many pixels".
//
// Pure — no Flutter, no game types. Exercised headlessly.

import 'dart:math';

import 'package:flutter/painting.dart' show Offset;

class CompanionStance {
  const CompanionStance({
    required this.engageFraction,
    required this.orbitWeight,
    this.tooCloseFraction = 0.65,
  });

  /// Preferred standoff, as a fraction of the companion's attack range.
  final double engageFraction;

  /// How much sideways drift to mix in. 0 holds a line; high values circle.
  final double orbitWeight;

  /// Below this fraction of the preferred distance it actively backs away.
  /// Relative to [engageFraction], so a brawler tolerates being close.
  final double tooCloseFraction;

  double get preferredAt => engageFraction;
}

/// Per-family stances. Families not named here hold the middle.
///
///  - horn closes, because its kit is contact and shields
///  - wing circles, because it is the mobile one
///  - mane, let and pip hold back — big single shots, meteors, ricochets
///  - kin stands as far off as its range allows: it is support and the most
///    fragile thing on the field
const Map<String, CompanionStance> kCompanionStances = {
  'horn': CompanionStance(
    engageFraction: 0.34,
    orbitWeight: 0.10,
    tooCloseFraction: 0.45,
  ),
  'wing': CompanionStance(engageFraction: 0.66, orbitWeight: 0.95),
  'mask': CompanionStance(engageFraction: 0.74, orbitWeight: 0.35),
  'mystic': CompanionStance(engageFraction: 0.80, orbitWeight: 0.25),
  'pip': CompanionStance(engageFraction: 0.86, orbitWeight: 0.20),
  'mane': CompanionStance(engageFraction: 0.88, orbitWeight: 0.12),
  'let': CompanionStance(engageFraction: 0.92, orbitWeight: 0.10),
  'kin': CompanionStance(engageFraction: 0.98, orbitWeight: 0.06),
};

const CompanionStance kDefaultCompanionStance = CompanionStance(
  engageFraction: 0.72,
  orbitWeight: 0.20,
);

CompanionStance stanceForFamily(String? family) =>
    kCompanionStances[(family ?? '').toLowerCase()] ??
    kDefaultCompanionStance;

/// How this companion wants to move, given where it is and what it is
/// fighting. Returns [Offset.zero] when it is already happy.
///
/// The MAGNITUDE carries intent and is capped at 1, so callers must scale by
/// it rather than normalising: a companion sitting exactly at its preferred
/// distance has no radial term at all, and normalising there would send even
/// a horn (orbit 0.10) sliding sideways at full speed.
///
/// [orbitSign] should be stable per companion (slot parity works) so two
/// wings do not oscillate against each other.
Offset stanceMove({
  required Offset self,
  required Offset target,
  required double attackRange,
  required CompanionStance stance,
  required int orbitSign,
}) {
  final to = target - self;
  final dist = to.distance;
  if (dist < 1 || attackRange <= 0) return Offset.zero;

  final unit = to / dist;
  final want = attackRange * stance.engageFraction;
  final tooClose = want * stance.tooCloseFraction;

  // Radial: close the gap, or back out of it.
  var move = Offset.zero;
  if (dist > want) {
    move += unit;
  } else if (dist < tooClose) {
    move -= unit;
  }

  // Tangential: what makes a wing circle rather than stand.
  if (stance.orbitWeight > 0) {
    final perp = Offset(-unit.dy, unit.dx) * orbitSign.sign.toDouble();
    // Only worth circling once roughly in position; charging in sideways
    // just makes the approach longer.
    final settled = (dist - want).abs() < want * 0.55;
    move += perp * (settled ? stance.orbitWeight : stance.orbitWeight * 0.35);
  }

  if (move.distanceSquared < 1e-6) return Offset.zero;
  final mag = move.distance;
  return mag > 1.0 ? move / mag : move;
}

/// Families ordered from the front line to the back, for tests and docs.
List<String> get familiesByStandoff {
  final keys = kCompanionStances.keys.toList()
    ..sort(
      (a, b) => kCompanionStances[a]!.engageFraction.compareTo(
        kCompanionStances[b]!.engageFraction,
      ),
    );
  return keys;
}

/// Clamped to keep a stance from ever asking for a position outside range.
double clampedEngageDistance(double attackRange, CompanionStance s) =>
    attackRange * min(s.engageFraction, 0.98);
