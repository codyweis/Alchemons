/// Horn's three mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Horn is the Bulky Defense Tank, and it is the one family whose cast pattern
/// changes with its element — a heavy charge, a wind-up dash, an always-on
/// passive, or a stationary channel. Two elements (Air, Mud) never cast at all
/// and one (Light) never moves. That is the constraint every node here is
/// written against: a path keyed to "your next charge" is dead content for
/// three of seventeen Horns, which is exactly what the draft tree did.
///
/// So all three paths key off things every Horn has — a body with hit points,
/// an auto-attack, and an element:
///
/// * **Bulwark** turns maximum HP into damage. Nothing else in the game scales
///   a companion's damage off its own bulk.
/// * **Bastion** takes hits meant for the orb and the team. Nothing else in the
///   game redirects damage onto a companion.
/// * **Juggernaut** runs the special a second time. Horn is the only family
///   whose ability occupies *time* — its cooldown does not even tick while the
///   ability is executing — so a second run is a Horn-shaped reward.
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
  static const juggernautPath = 'horn.juggernaut';

  static const ironhead = 'horn.bulwark.ironhead';
  static const weightBehindIt = 'horn.bulwark.weight_behind_it';
  static const braced = 'horn.bulwark.braced';
  static const anvil = 'horn.bulwark.anvil';

  static const guardedShot = 'horn.bastion.guarded_shot';
  static const bodyguard = 'horn.bastion.bodyguard';
  static const shieldWall = 'horn.bastion.shield_wall';
  static const lastStand = 'horn.bastion.last_stand';

  static const secondEffort = 'horn.juggernaut.second_effort';
  static const fullWeight = 'horn.juggernaut.full_weight';
  static const relentless = 'horn.juggernaut.relentless';
  static const secondFront = 'horn.juggernaut.second_front';
}

/// Cast tags, set when a Horn ability starts and read while it resolves.
class HornCastTags {
  const HornCastTags._();

  /// This cast is Juggernaut's second run, not a scheduled one. It may not
  /// schedule another — the one place this whole path could recurse.
  static const secondRun = 'horn.secondRun';

  /// This hit carried Bulwark's weight, so Anvil may rupture on the kill.
  static const weighted = 'horn.weighted';
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

  // ── Juggernaut ──
  /// Second Effort, then Relentless: what the second run is worth.
  static const double secondRunPower = 0.45;
  static const double relentlessRunPower = 0.75;

  /// A passive Horn cannot re-cast, so it pulses instead — this often,
  /// halved once Relentless is held.
  static const double passivePulseInterval = 6.0;
  static const double passivePulseRadius = 150.0;

  /// Second Front: the second run covers this much more ground.
  static const double secondFrontCoverage = 1.40;

  /// The second run follows the first by this long, so the two read as two
  /// separate events rather than one doubled hit.
  static const double secondRunDelay = 0.45;
}

/// One Horn companion's mastery state for the length of a run.
class HornMasteryState {
  // ── Juggernaut ──
  /// Counts down to the second run. Zero means nothing is pending.
  double secondRunTimer = 0;

  /// True while the pending run is the second one, so it cannot schedule a
  /// third. Juggernaut is the only path here that could recurse.
  bool secondRunArmed = false;

  /// A passive Horn never casts, so it pulses on this timer instead.
  double passivePulseTimer = 0;

  // ── Bastion ──
  /// Shield the Horn is carrying, in hit points, and the run's ceiling.
  double guardShield = 0;

  /// Set the frame the shield is broken through, so Last Stand can rupture
  /// once rather than on every subsequent hit.
  double lastStandCooldownTimer = 0;

  /// Arms the second run. Ignored if one is already pending or if the cast
  /// that just finished *was* the second run.
  bool armSecondRun() {
    if (secondRunArmed || secondRunTimer > 0) return false;
    secondRunTimer = HornTuning.secondRunDelay;
    secondRunArmed = true;
    return true;
  }

  /// Ticks the pending second run. Returns true on the frame it should fire.
  bool takeSecondRun(double dt) {
    if (secondRunTimer <= 0) return false;
    secondRunTimer -= dt;
    if (secondRunTimer > 0) return false;
    secondRunTimer = 0;
    return true;
  }

  /// Ticks a passive Horn's pulse. Returns true on the frame it should fire.
  bool takePassivePulse(double dt, {required bool relentless}) {
    passivePulseTimer -= dt;
    if (passivePulseTimer > 0) return false;
    passivePulseTimer =
        HornTuning.passivePulseInterval / (relentless ? 2.0 : 1.0);
    return true;
  }

  @override
  String toString() =>
      'HornMasteryState(shield: ${guardShield.toStringAsFixed(1)}, '
      'secondRun: ${secondRunTimer.toStringAsFixed(2)}'
      '${secondRunArmed ? " armed" : ""})';
}

/// How much extra damage Bulwark's weight adds to one hit.
///
/// [isSpecial] covers the charge, the channel and a passive's own damage —
/// everything that is not an auto-attack.
double hornBulwarkBonus({
  required bool Function(String nodeId) hasNode,
  required double maxHp,
  required double currentHp,
  required bool isSpecial,
}) {
  if (!hasNode(HornNodes.ironhead)) return 0;
  if (isSpecial && !hasNode(HornNodes.weightBehindIt)) return 0;

  var bonus = maxHp * HornTuning.ironheadMaxHpFraction;
  if (isSpecial) bonus *= HornTuning.specialWeightScale;

  if (hasNode(HornNodes.braced)) {
    final health = maxHp <= 0 ? 0.0 : (currentHp / maxHp).clamp(0.0, 1.0);
    bonus *=
        HornTuning.bracedAtNoHp +
        (HornTuning.bracedAtFullHp - HornTuning.bracedAtNoHp) * health;
  }
  return bonus;
}

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

/// What Juggernaut's second run is worth, and how much more ground it covers.
///
/// A [power] of zero means the path is not held and no second run happens.
({double power, double coverage}) hornSecondRun({
  required bool Function(String nodeId) hasNode,
}) {
  if (!hasNode(HornNodes.secondEffort)) return (power: 0, coverage: 1.0);
  return (
    power: hasNode(HornNodes.relentless)
        ? HornTuning.relentlessRunPower
        : HornTuning.secondRunPower,
    coverage: hasNode(HornNodes.secondFront)
        ? HornTuning.secondFrontCoverage
        : 1.0,
  );
}

/// The share of a hit's damage that mastery is responsible for, given the
/// bonus it added on top of the base. A path that adds nothing is owed nothing.
double hornUpliftFraction(double base, double bonus) {
  final total = base + bonus;
  if (total <= 0 || bonus <= 0) return 0;
  return bonus / total;
}
