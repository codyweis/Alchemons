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
    kCompanionStances[(family ?? '').toLowerCase()] ?? kDefaultCompanionStance;

/// Where a companion wants to STAND while it fights, as a point to move to.
///
/// It replaced a steer that said only "closer" or "further" from the
/// target's centre, which read as robotic in a fight: a horn with a short range sat inside
/// a big guardian's body, everyone queued on the party's side of it, and the
/// slow orbit terms crept rather than moved. A station fixes all three:
///
///  - it stands off the target's EDGE ([targetRadius] + [bodyRadius]), so a
///    horn presses against a guardian instead of sinking into it, and never
///    further out than the companion's own attack range;
///  - it holds the party's side of the target ([homeBearing]) and sways
///    along its arc at its own pace ([slot] sets the phase and the rate, so
///    no two move in step), by as much as the family likes to move
///    ([CompanionStance.orbitWeight]): a kin barely, a mane more, and a wing
///    loops round the target and swoops in and out. Spreading a squad all
///    round a guardian was tried and measured: the far side is where its
///    dives land, and a mid squad lost more to it at every raid tier.
///
/// [closeIn] is for when the target is open to a strike: everyone steps a
/// fifth closer. Driven by [time] alone, so it is deterministic and the same
/// at any frame rate.
Offset companionStation({
  required Offset target,
  required double targetRadius,
  required double bodyRadius,
  required double attackRange,
  required CompanionStance stance,
  required double homeBearing,
  required int slot,
  required double time,
  bool closeIn = false,
}) {
  final contact = targetRadius + bodyRadius + 6;
  final reach = max(contact, attackRange * min(stance.engageFraction, 0.98));
  var standoff = reach;
  if (closeIn) standoff = max(contact, standoff * 0.8);

  var bearing = homeBearing;

  // Its own sway: a rate and a phase per slot, so the squad never moves in
  // step. Scaled by how much the family likes to move.
  final rate = 0.45 + 0.17 * slot;
  bearing += stance.orbitWeight * 0.55 * sin(time * rate + slot * 2.4);

  if (stance.orbitWeight >= 0.9) {
    // The mobile one: it loops round the target, swooping in and out.
    bearing += time * 0.5 * (slot.isEven ? 1 : -1);
    standoff *= 1 + 0.22 * sin(time * 1.3 + slot * 2.1);
    standoff = max(contact, standoff);
  }
  return target + Offset(cos(bearing), sin(bearing)) * standoff;
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
