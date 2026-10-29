/// Kin's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Kin is Rare Support, and its chassis is unlike anything else in the game:
/// its *basic attack* charges for 1.5 seconds with movement locked to zero,
/// then fires a line that hits every body near the segment at four times a
/// normal hit. No other family roots itself to throw a basic, and no other
/// family's basic is a line through space rather than a thing aimed at a
/// target.
///
/// One path takes that line and one feeds the seventeen bespoke supports the
/// family actually exists for:
///
/// * **Conduction** is what the line carries. It already hits every enemy it
///   crosses; this makes it help every ally it crosses too, which is where
///   the support identity lives.
/// * **Benediction** is the special itself: it reaches the ally beside the
///   Kin (Kindred), comes back sooner while someone is in trouble (Vigil),
///   outlasts the Kin (Unbroken), and finally reaches the whole team.
///
/// Longline, the line's reach, was cut on 2026-10-29: its nodes were a
/// longer line and a bigger number at its end, and it turned the support
/// family into a damage dealer (7% of its party's damage to 19% after the
/// 2026-10-21 trims). Devotion and Deep Reserves, Benediction's first two
/// nodes, were +40% duration and +25% strength; Kindred and Vigil replaced
/// them the same day.
///
/// What is deliberately absent. The draft tree's first path turned the Rare
/// Support family into a damage dealer, which is the one thing the design
/// board for Kin explicitly did not want; its `Burn Through` node shared a
/// name with a Wing path, and its `Critical Mass` (holding one target through
/// a charge) *was* that Wing path. Its second path marked enemies, which Pip
/// and Let already do, applied `vulnerable`, which is Dark's, left a damaging
/// lane, which is Mask's and Wing/Lava's, and chained shocks between enemies,
/// which is Kin/Lightning's own signature. Its third path was War Rhythm for
/// the fourth family running — five stacks banked on hits and spent on the
/// special — with a shield-per-attack opener that is Horn's Guarded Shot and
/// an ally attack-speed buff that is Kin/Steam's own boiler.
library;

import 'dart:math';

/// Node ids, so the game never spells one out as a string literal.
class KinNodes {
  const KinNodes._();

  static const conductionPath = 'kin.conduction';
  static const benedictionPath = 'kin.benediction';

  static const liveCurrent = 'kin.conduction.live_current';
  static const lifeline = 'kin.conduction.lifeline';
  static const grounding = 'kin.conduction.grounding';
  static const transfusion = 'kin.conduction.transfusion';

  static const kindred = 'kin.benediction.kindred';
  static const vigil = 'kin.benediction.vigil';
  static const unbroken = 'kin.benediction.unbroken';
  static const communion = 'kin.benediction.communion';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class KinTuning {
  const KinTuning._();

  // ── Conduction ──
  /// Live Current: an ally on the line is shielded for this share of what the
  /// laser dealt, and no single shot may shield more than this.
  ///
  /// 20% and 12% until the 2026-10-21 mastery sweep, when the whole path
  /// moved neither its party's hold rate nor anything else measurable: the
  /// line crosses an ally now and then, and a shield worth a few hits was
  /// all it left.
  static const double conductionShieldShare = 0.30;
  static const double conductionShieldCapFraction = 0.18;

  /// Lifeline: below this much health an ally is healed instead, for this
  /// much more than the shield would have been.
  static const double lifelineThreshold = 0.5;
  static const double lifelineScale = 1.5;

  /// Grounding: the element's payload on every body down the line, at this
  /// strength. Once per body per shot, so a shot is worth what a Mane's
  /// payload hit is worth on each body it crosses.
  static const double groundingStrength = 1.0;

  /// Transfusion: worth this much more, and reaching this far off the line.
  static const double transfusionScale = 1.5;
  static const double transfusionRadius = 120.0;

  // ── Benediction ──
  /// Vigil: below this much health an ally is in trouble, and while any is,
  /// the Kin's special recharges this many times as fast.
  static const double vigilThreshold = 0.5;
  static const double vigilRate = 2.0;

  /// Communion: an ally this far away is still reached. Large enough to mean
  /// "anywhere", without being infinite in a way that breaks a distance sort.
  static const double communionRange = 100000.0;

  /// ...and what reaches it, as a share of the Kin's own blessing. Full until
  /// the 2026-10-21 mastery sweep: a Kin's blessing is a fortieth of its own
  /// large health a second, near-constant under the old Devotion, and copied
  /// whole to every ally it kept the whole party alive. Parties with a
  /// Communion Kin held 91% of Potential 50 waves against 51% without the
  /// path; with the shared copies no longer echoing into the orb, still 85%,
  /// and 76% with them at half. Kindred's ally keeps the whole of it.
  static const double communionShare = 0.5;
}

/// One Kin companion's mastery state for the length of a run.
class KinMasteryState {
  /// Total shielding this Kin has handed out, for telemetry and for the HUD.
  double shieldGranted = 0;

  /// What Kindred has handed the ally beside the Kin: heal, blessing and
  /// shield, for telemetry and the tests.
  double kindredGiven = 0;

  /// Seconds of special cooldown Vigil has taken off, for the tests.
  double vigilSeconds = 0;

  @override
  String toString() =>
      'KinMasteryState(shielded: ${shieldGranted.round()}, '
      'kindred: ${kindredGiven.round()}, '
      'vigil: ${vigilSeconds.toStringAsFixed(1)}s)';
}

/// What Conduction gives one ally the line crossed.
///
/// Returns zero for both when the path is not held. [allyHealthFraction]
/// decides whether it arrives as a shield or, for someone in trouble, as a
/// heal — a support path should notice which of those an ally needs.
({double shield, double heal, double radius}) kinConduction({
  required bool Function(String nodeId) hasNode,
  required double laserDamage,
  required double allyMaxHp,
  required double allyHealthFraction,
}) {
  if (!hasNode(KinNodes.liveCurrent) || laserDamage <= 0) {
    return (shield: 0, heal: 0, radius: 0);
  }
  final transfusion = hasNode(KinNodes.transfusion);
  var amount = laserDamage * KinTuning.conductionShieldShare;
  // One enormous shot must not hand out a full health bar in one tick.
  amount = min(amount, allyMaxHp * KinTuning.conductionShieldCapFraction);
  if (transfusion) amount *= KinTuning.transfusionScale;

  final radius = transfusion ? KinTuning.transfusionRadius : 0.0;
  final hurt =
      hasNode(KinNodes.lifeline) &&
      allyHealthFraction < KinTuning.lifelineThreshold;
  if (hurt) {
    return (shield: 0, heal: amount * KinTuning.lifelineScale, radius: radius);
  }
  return (shield: amount, heal: 0, radius: radius);
}

/// The most shield Conduction keeps on one ally, however many shots cross it:
/// the most a single shot may give. The line tops a shield up to this and
/// gives back only what the ally has lost; it used to add every gift on top
/// of the last with no ceiling and no decay, so an ally the Kin kept crossing
/// banked a second health bar (2026-10-20 audit). A shield from anywhere else
/// that already stands higher is left as it is.
double kinConductionShieldCeiling({
  required bool Function(String nodeId) hasNode,
  required double allyMaxHp,
}) {
  final ceiling = allyMaxHp * KinTuning.conductionShieldCapFraction;
  return hasNode(KinNodes.transfusion)
      ? ceiling * KinTuning.transfusionScale
      : ceiling;
}

/// What Benediction does to the support ability itself.
///
/// [kindred]: the ally nearest the Kin gets what the Kin gets, whole.
/// [vigil]: the special recharges faster while an ally is hurt
/// ([kinVigilRate]). [survivesDeath]: Unbroken. [allyRange]: Communion.
({bool kindred, bool vigil, bool survivesDeath, double allyRange})
kinBenediction({required bool Function(String nodeId) hasNode}) => (
  kindred: hasNode(KinNodes.kindred),
  vigil: hasNode(KinNodes.vigil),
  survivesDeath: hasNode(KinNodes.unbroken),
  allyRange: hasNode(KinNodes.communion) ? KinTuning.communionRange : 0.0,
);

/// Vigil: how fast the Kin's special recharges, given the lowest health
/// fraction among its allies (not itself).
double kinVigilRate({
  required bool Function(String nodeId) hasNode,
  required double lowestAllyHealth,
}) => hasNode(KinNodes.vigil) && lowestAllyHealth < KinTuning.vigilThreshold
    ? KinTuning.vigilRate
    : 1.0;

/// The share of a hit's damage that mastery is responsible for.
double kinUpliftFraction(double multiplier) =>
    multiplier <= 1.0 ? 0.0 : (multiplier - 1.0) / multiplier;
