/// Horn's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Horn is the Bulky Defense Tank, and it is the one family whose cast pattern
/// changes with its element — a heavy charge, a wind-up dash, an always-on
/// passive, or a stationary channel. Two elements (Air, Mud) never cast at all
/// and one (Light) never moves. That is the constraint every node here is
/// written against: a path keyed to "your next charge" is dead content for
/// three of seventeen Horns, which is exactly what the draft tree did.
///
/// So both paths key off things every Horn has — a body with hit points,
/// an auto-attack, and an element:
///
/// * **Bulwark** turns maximum HP into damage. Nothing else in the game scales
///   a companion's damage off its own bulk.
/// * **Bastion** takes hits meant for the orb and the team. Nothing else in the
///   game redirects damage onto a companion.
///
/// A third path, Juggernaut (the special runs a second time), was cut on
/// 2026-10-29 in the move to two paths a family.
///
/// What is deliberately absent, and why. The draft tree spent six of its twelve
/// nodes on mechanics its own elements already own: knockback (Air's entire
/// passive identity, and Steam's payload), blocking enemy shots (Crystal's
/// shards, Ice's wall, Light's barrier — three separate elements), armor
/// cracking (Dark's `vulnerable`), and stagger (Earth's). Its third path was
/// Mane's War Rhythm down to the numbers: five stacks, +2% each, spent on the
/// special. None of that survived.
library;

/// Node ids, so the game never spells one out as a string literal.
class HornNodes {
  const HornNodes._();

  static const bulwarkPath = 'horn.bulwark';
  static const bastionPath = 'horn.bastion';

  static const ironhead = 'horn.bulwark.ironhead';
  static const weightBehindIt = 'horn.bulwark.weight_behind_it';
  static const braced = 'horn.bulwark.braced';
  static const anvil = 'horn.bulwark.anvil';

  static const guardedShot = 'horn.bastion.guarded_shot';
  static const bodyguard = 'horn.bastion.bodyguard';
  static const shieldWall = 'horn.bastion.shield_wall';
  static const lastStand = 'horn.bastion.last_stand';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class HornTuning {
  const HornTuning._();

  // ── Bulwark ──
  /// Ironhead: an auto-attack carries this share of the Horn's maximum HP.
  static const double ironheadMaxHpFraction = 0.025;

  /// Weight Behind It: the special carries the same weight, at this share.
  static const double specialWeightScale = 0.60;

  /// Braced: the weight rides current health between these two multipliers.
  static const double bracedAtFullHp = 1.5;
  static const double bracedAtNoHp = 0.5;

  /// Anvil: a body killed by that weight ruptures for this share of max HP.
  static const double anvilMaxHpFraction = 0.12;
  static const double anvilRadius = 120.0;

  /// Anvil cannot chain off its own rupture, and one kill pays once.
  static const double anvilProcCooldown = 0.35;

  // ── Bastion ──
  /// Guarded Shot: per attack, and the ceiling, both as shares of max HP.
  static const double guardPerShot = 0.015;
  static const double guardCap = 0.06;

  /// Bodyguard: this share of the orb's incoming damage is taken by the Horn
  /// instead, and the Horn takes this much less of it than the orb would have.
  static const double bodyguardShare = 0.25;
  static const double bodyguardMitigation = 0.40;

  /// Only while the Horn is actually standing between: this close to the orb.
  static const double bodyguardRange = 260.0;

  // ── Shield Wall ──
  /// Allies this close take this much less while the Horn's shield holds.
  static const double shieldWallRadius = 150.0;
  static const double shieldWallMitigation = 0.20;

  // ── Last Stand ──
  /// A broken shield ruptures for this multiple of the shield it had.
  static const double lastStandDamageScale = 2.2;
  static const double lastStandRadius = 160.0;

  /// ...and gives back this share of the special's cooldown.
  static const double lastStandCooldownRefund = 0.20;

  /// One rupture per this many seconds, however the shield breaks.
  static const double lastStandCooldown = 4.0;
}

/// One Horn companion's mastery state for the length of a run.
class HornMasteryState {
  // ── Bastion ──
  /// Shield the Horn is carrying, in hit points, and the run's ceiling.
  double guardShield = 0;

  /// Set the frame the shield is broken through, so Last Stand can rupture
  /// once rather than on every subsequent hit.
  double lastStandCooldownTimer = 0;

  /// Bodyguard's share of the orb's hits below one hit point, carried to the
  /// next hit so chaff chipping the orb is not rounded away.
  double bodyguardCarry = 0;

  @override
  String toString() =>
      'HornMasteryState(shield: ${guardShield.toStringAsFixed(1)})';
}

/// How much extra damage Bulwark's weight adds to one hit.
///
/// [isSpecial] covers the charge, the channel and a passive's own damage —
/// everything that is not an auto-attack.
///
/// [specialStrikes] is false for a Horn whose special lands no blow of its
/// own — Air's wind, Mud's sludge, Light's barrier. Weight Behind It puts its
/// share into that Horn's auto-attacks instead, so the node is not bought for
/// nothing by three of seventeen (2026-10-21 mastery sweep).
double hornBulwarkBonus({
  required bool Function(String nodeId) hasNode,
  required double maxHp,
  required double currentHp,
  required bool isSpecial,
  bool specialStrikes = true,
}) {
  if (!hasNode(HornNodes.ironhead)) return 0;
  if (isSpecial && !hasNode(HornNodes.weightBehindIt)) return 0;

  var bonus = maxHp * HornTuning.ironheadMaxHpFraction;
  if (isSpecial) bonus *= HornTuning.specialWeightScale;
  if (!isSpecial && !specialStrikes && hasNode(HornNodes.weightBehindIt)) {
    bonus *= 1 + HornTuning.specialWeightScale;
  }

  if (hasNode(HornNodes.braced)) {
    final health = maxHp <= 0 ? 0.0 : (currentHp / maxHp).clamp(0.0, 1.0);
    bonus *=
        HornTuning.bracedAtNoHp +
        (HornTuning.bracedAtFullHp - HornTuning.bracedAtNoHp) * health;
  }
  return bonus;
}

/// Whether a Horn of [element]'s special strikes anything itself. Air's wind
/// pushes, Mud's sludge slows and Light's barrier shelters; none of the three
/// deals a blow for Bulwark's weight to ride.
bool hornSpecialStrikes(String element) =>
    element != 'Air' && element != 'Mud' && element != 'Light';

/// What one Bastion attack banks, and the ceiling it banks toward.
({double perShot, double cap}) hornGuardShield({
  required bool Function(String nodeId) hasNode,
  required double maxHp,
}) {
  if (!hasNode(HornNodes.guardedShot)) return (perShot: 0, cap: 0);
  return (
    perShot: maxHp * HornTuning.guardPerShot,
    cap: maxHp * HornTuning.guardCap,
  );
}

/// How the orb's incoming damage is split with a Bastion standing near it.
///
/// Returns what the orb still takes and what the Horn takes in its place. The
/// Horn's share is mitigated by its bulk, so the team comes out ahead — that is
/// the whole point of a tank, and the reason this is worth a path.
({double toOrb, double toHorn}) hornBodyguardSplit({
  required bool Function(String nodeId) hasNode,
  required double incoming,
  required double distanceToOrb,
}) {
  if (incoming <= 0 || !hasNode(HornNodes.bodyguard)) {
    return (toOrb: incoming, toHorn: 0);
  }
  if (distanceToOrb > HornTuning.bodyguardRange) {
    return (toOrb: incoming, toHorn: 0);
  }
  final taken = incoming * HornTuning.bodyguardShare;
  return (
    toOrb: incoming - taken,
    toHorn: taken * (1 - HornTuning.bodyguardMitigation),
  );
}

/// The share of a hit's damage that mastery is responsible for, given the
/// bonus it added on top of the base. A path that adds nothing is owed nothing.
double hornUpliftFraction(double base, double bonus) {
  final total = base + bonus;
  if (total <= 0 || bonus <= 0) return 0;
  return bonus / total;
}
