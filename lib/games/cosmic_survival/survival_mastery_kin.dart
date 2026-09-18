/// Kin's three mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Kin is Rare Support, and its chassis is unlike anything else in the game:
/// its *basic attack* charges for 1.5 seconds with movement locked to zero,
/// then fires a line that hits every body near the segment at four times a
/// normal hit. No other family roots itself to throw a basic, and no other
/// family's basic is a line through space rather than a thing aimed at a
/// target.
///
/// Two paths take that line apart and one feeds the seventeen bespoke
/// supports the family actually exists for:
///
/// * **Longline** is reach — how far down the field the line runs.
/// * **Conduction** is what the line carries. It already hits every enemy it
///   crosses; this makes it help every ally it crosses too, which is where
///   the support identity lives.
/// * **Benediction** is the special itself: longer, stronger, harder to
///   interrupt, and finally reaching the whole team.
///
/// Longline is not Wing's Longshot. Wing's path reads the *gap between the
/// Wing and its target* and pays more for keeping it; Kin's reads the *length
/// of the line itself*, which is how many bodies one shot crosses. Different
/// quantity, different decision.
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

  static const longlinePath = 'kin.longline';
  static const conductionPath = 'kin.conduction';
  static const benedictionPath = 'kin.benediction';

  static const extendedCoil = 'kin.longline.extended_coil';
  static const fullSpan = 'kin.longline.full_span';
  static const deepLine = 'kin.longline.deep_line';
  static const crossfire = 'kin.longline.crossfire';

  static const liveCurrent = 'kin.conduction.live_current';
  static const lifeline = 'kin.conduction.lifeline';
  static const grounding = 'kin.conduction.grounding';
  static const transfusion = 'kin.conduction.transfusion';

  static const devotion = 'kin.benediction.devotion';
  static const deepReserves = 'kin.benediction.deep_reserves';
  static const unbroken = 'kin.benediction.unbroken';
  static const communion = 'kin.benediction.communion';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class KinTuning {
  const KinTuning._();

  // ── Longline ──
  /// Extended Coil: how much longer the line runs, and the new ceiling on a
  /// length the chassis otherwise clamps to 720.
  static const double extendedCoilScale = 1.35;
  static const double extendedCoilCap = 1100.0;

  /// Full Span: the line stops being cut to "just past the target".
  static const double fullSpanMinimum = 0.92;

  /// Deep Line: a body at the far end takes this much more than one at the
  /// muzzle, scaled by how far along the line it stands.
  static const double deepLineBonus = 0.40;

  /// Crossfire: the backward line, as a share of the forward one.
  static const double crossfireStrength = 1.0;

  // ── Conduction ──
  /// Live Current: an ally on the line is shielded for this share of what the
  /// laser dealt, and no single shot may shield more than this.
  static const double conductionShieldShare = 0.20;
  static const double conductionShieldCapFraction = 0.12;

  /// Lifeline: below this much health an ally is healed instead, for this
  /// much more than the shield would have been.
  static const double lifelineThreshold = 0.5;
  static const double lifelineScale = 1.5;

  /// Transfusion: worth this much more, and reaching this far off the line.
  static const double transfusionScale = 1.5;
  static const double transfusionRadius = 70.0;

  // ── Benediction ──
  /// Devotion: how much longer a support runs.
  static const double devotionDuration = 1.40;

  /// Deep Reserves: how much more it heals, shields and buffs.
  static const double deepReservesPower = 1.25;

  /// Communion: an ally this far away is still reached. Large enough to mean
  /// "anywhere", without being infinite in a way that breaks a distance sort.
  static const double communionRange = 100000.0;
}

/// One Kin companion's mastery state for the length of a run.
class KinMasteryState {
  /// Supports that must keep running although the Kin is down, for Unbroken.
  /// Keyed by the effect's own timer name, holding what is left of it.
  final Map<String, double> orphanedSupports = {};

  /// Total shielding this Kin has handed out, for telemetry and for the HUD.
  double shieldGranted = 0;

  @override
  String toString() =>
      'KinMasteryState(shielded: ${shieldGranted.round()}, '
      'orphaned: ${orphanedSupports.length})';
}

/// How long the laser's line should run, given the distance to the target.
///
/// The chassis fires `distance + 60`, clamped between 120 and 720. Longline
/// raises the ceiling and, at Full Span, stops the line being cut down to
/// "just past whatever you were aiming at".
double kinLaserLength({
  required bool Function(String nodeId) hasNode,
  required double distanceToTarget,
  double baseMinimum = 120.0,
  double baseMaximum = 720.0,
}) {
  final natural = distanceToTarget + 60.0;
  if (!hasNode(KinNodes.extendedCoil)) {
    return natural.clamp(baseMinimum, baseMaximum).toDouble();
  }
  final ceiling = KinTuning.extendedCoilCap;
  final extended = natural * KinTuning.extendedCoilScale;
  if (!hasNode(KinNodes.fullSpan)) {
    return extended.clamp(baseMinimum, ceiling).toDouble();
  }
  // Full Span: never much shorter than the reach the path paid for.
  return extended
      .clamp(ceiling * KinTuning.fullSpanMinimum, ceiling)
      .toDouble();
}

/// Deep Line's multiplier for a body standing [along] of the way down a line
/// of [length].
double kinDeepLineMultiplier({
  required bool Function(String nodeId) hasNode,
  required double along,
  required double length,
}) {
  if (!hasNode(KinNodes.deepLine) || length <= 0) return 1.0;
  final t = (along / length).clamp(0.0, 1.0);
  return 1.0 + KinTuning.deepLineBonus * t;
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

/// What Benediction does to the support ability itself.
({double duration, double power, bool survivesDeath, double allyRange})
kinBenediction({required bool Function(String nodeId) hasNode}) => (
  duration: hasNode(KinNodes.devotion) ? KinTuning.devotionDuration : 1.0,
  power: hasNode(KinNodes.deepReserves) ? KinTuning.deepReservesPower : 1.0,
  survivesDeath: hasNode(KinNodes.unbroken),
  allyRange: hasNode(KinNodes.communion) ? KinTuning.communionRange : 0.0,
);

/// The share of a hit's damage that mastery is responsible for.
double kinUpliftFraction(double multiplier) =>
    multiplier <= 1.0 ? 0.0 : (multiplier - 1.0) / multiplier;
