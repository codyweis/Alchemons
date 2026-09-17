/// Let's three mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Phase 4 of docs/survival_species_mastery_design.md. A Let throws two
/// different meteors, and every path says which one it changes:
///
/// * **Falling Star** (auto-attack meteor) makes one hit enormous: a denser
///   rock, a crack the next rock exploits, extra weight against the healthy,
///   and every fifth throw a giant comet.
/// * **Bombardment** (auto-attack meteor) stops the rock being thrown at all.
///   It falls, like the special, into a crater that grows, from further away,
///   and finally from anywhere in the arena.
/// * **Ground Zero** (special meteor) lets the big one tell the rest where to
///   land: whatever the special catches is Sighted, and the auto-attack
///   meteors punish it.
///
/// Every mechanic here is one no Let element's special owns. Shoving is Air's,
/// slowing Dust's and Crystal's, extra meteors Dark's, splash Water's — a path
/// that handed any of those to every Let would erase the element that owns
/// it. What is left is damage, marks, attack speed, range and targeting, and
/// that is all this file uses. None of it carries an element effect: the
/// special's on-collide and on-kill behaviours stay the special's.
library;

/// Node ids, so the game never spells one out as a string literal.
class LetNodes {
  const LetNodes._();

  static const fallingStarPath = 'let.assault';
  static const bombardmentPath = 'let.bombardment';
  static const groundZeroPath = 'let.ground_zero';

  static const denseCore = 'let.assault.dense_core';
  static const cratermaker = 'let.assault.cratermaker';
  static const deadWeight = 'let.assault.dead_weight';
  static const extinctionEvent = 'let.assault.extinction_event';

  static const deadfall = 'let.bombardment.deadfall';
  static const heavyOrdnance = 'let.bombardment.heavy_ordnance';
  static const rangingShots = 'let.bombardment.ranging_shots';
  static const skyreach = 'let.bombardment.skyreach';

  static const sighted = 'let.ground_zero.sighted';
  static const walkingFire = 'let.ground_zero.walking_fire';
  static const calledShot = 'let.ground_zero.called_shot';
  static const fireForEffect = 'let.ground_zero.fire_for_effect';
}

/// Cast tags, set when a cast launches and read when it lands.
class LetCastTags {
  const LetCastTags._();

  /// This auto-attack is an Extinction Event comet.
  static const comet = 'let.comet';
}

/// Initial balance targets, expected to move once the slice is simulated.
class LetTuning {
  const LetTuning._();

  /// The chassis coefficient: one meteor at 115% physical.
  static const double baseMeteorFraction = 1.15;

  // ── Falling Star ──
  /// Dense Core: 135% physical, 12% smaller, 10% slower.
  static const double denseCoreFraction = 1.35;
  static const double denseCoreSizeScale = 0.88;
  static const double denseCoreSpeedScale = 0.90;

  /// Cratermaker: a hit leaves a crack for this long, and the next
  /// auto-attack meteor to land on it deals this much more.
  static const double fractureDuration = 4.0;
  static const double fractureBonus = 0.18;

  /// Dead Weight: bonus against bodies above this share of their health.
  static const double deadWeightThreshold = 0.5;
  static const double deadWeightBonus = 0.25;

  /// Extinction Event: every Nth auto-attack is a comet at this coefficient,
  /// this much bigger, cratering at this radius. A bigger meteor, never more
  /// meteors — extra meteors are Dark's.
  static const int cometCadence = 5;
  static const double cometFraction = 2.10;
  static const double cometSizeScale = 2.0;
  static const double cometCraterRadius = 120.0;

  // ── Bombardment ──
  /// Deadfall: the auto-attack falls into a crater a third the size of the
  /// special's smallest.
  static const double deadfallCraterRadius = 48.0;

  /// The share of the hit the rest of a crater takes — the skyfall's own
  /// figure, kept here so Heavy Ordnance reads as a change to it.
  static const double craterSplashShare = 0.55;

  /// Heavy Ordnance: a wider crater that carries more of the hit.
  static const double heavyOrdnanceRadiusScale = 1.35;
  static const double heavyOrdnanceSplashShare = 0.75;

  /// Ranging Shots: more reach, and a streak on one body.
  static const double rangingShotsRangeScale = 1.25;
  static const double rangingStreakWindow = 3.0;
  static const double rangingStreakBonus = 0.10;
  static const int rangingStreakMax = 3;

  // ── Ground Zero ──
  /// Sighted: what the special catches is marked for this long, and the
  /// Let's auto-attack meteors deal this much more to it.
  static const double sightDuration = 6.0;
  static const double sightedBonus = 0.20;

  /// Walking Fire: targeting leans hard on Sighted bodies, and each hit on
  /// one extends its Sight up to a ceiling.
  static const double walkingFireTargetBonus = 320.0;
  static const double walkingFireExtension = 1.0;
  static const double sightMaxRemaining = 10.0;

  /// Called Shot: every companion's bonus against a Sighted body.
  static const double calledShotBonus = 0.10;

  /// Fire for Effect: attack speed while anything is Sighted.
  static const double fireForEffectHaste = 0.30;
}

/// One Let companion's mastery state for the length of a run.
class LetMasteryState {
  /// Auto-attacks since the last comet (Extinction Event).
  int castsSinceComet = 0;

  /// Ranging Shots: the body the last drop landed on, when, and how many
  /// consecutive drops it has taken.
  int lastDropTargetId = 0;
  double lastDropTime = double.negativeInfinity;
  int dropStreak = 0;

  /// Handoff between shaping a cast and opening it, as in Mane: the share of
  /// the pending cast's damage owed to mastery, and whether it is a comet.
  double pendingMasteryDamageFraction = 0;
  bool pendingComet = false;

  /// Advances the comet counter and reports whether this cast is the comet.
  bool takeCometTurn() {
    castsSinceComet++;
    if (castsSinceComet < LetTuning.cometCadence) return false;
    castsSinceComet = 0;
    return true;
  }

  /// Records a drop landing on [targetId] at [now] and returns the Ranging
  /// Shots bonus it earns. The first drop on a body earns nothing; each
  /// consecutive one inside the window earns one more step, to the cap.
  double landDrop(int targetId, double now) {
    final consecutive =
        targetId == lastDropTargetId &&
        now - lastDropTime <= LetTuning.rangingStreakWindow;
    dropStreak = consecutive
        ? (dropStreak + 1).clamp(0, LetTuning.rangingStreakMax)
        : 0;
    lastDropTargetId = targetId;
    lastDropTime = now;
    return dropStreak * LetTuning.rangingStreakBonus;
  }

  @override
  String toString() =>
      'LetMasteryState(comet: $castsSinceComet, streak: $dropStreak)';
}

/// How a Let auto-attack hit is amplified by the equipped path, resolved
/// without the game: the caller supplies what it knows about the body and
/// gets back the additive bonus. Only one path is ever equipped, so the three
/// paths' bonuses never meet.
///
/// Mutates the body's crack through [consumeFracture] / [applyFracture] and
/// its Sight through [extendSight], so the whole rule lives here rather than
/// half in the combat loop.
double resolveLetAutoAttackBonus({
  required bool Function(String nodeId) hasNode,
  required double targetHpFraction,
  required double fractureRemaining,
  required double sightRemaining,
  required void Function() consumeFracture,
  required void Function() applyFracture,
  required void Function() extendSight,
  required double Function() rangingStreakBonus,
}) {
  var bonus = 0.0;

  // ── Falling Star ──
  if (hasNode(LetNodes.deadWeight) &&
      targetHpFraction > LetTuning.deadWeightThreshold) {
    bonus += LetTuning.deadWeightBonus;
  }
  if (hasNode(LetNodes.cratermaker)) {
    if (fractureRemaining > 0) {
      bonus += LetTuning.fractureBonus;
      consumeFracture();
    }
    // Every landing cracks the body again, so a steady stream of rocks keeps
    // paying — each one exploits the crack the one before it left.
    applyFracture();
  }

  // ── Bombardment ──
  if (hasNode(LetNodes.rangingShots)) bonus += rangingStreakBonus();

  // ── Ground Zero ──
  if (sightRemaining > 0) {
    if (hasNode(LetNodes.sighted)) bonus += LetTuning.sightedBonus;
    if (hasNode(LetNodes.walkingFire)) extendSight();
  }

  return bonus;
}

/// The share of a hit an additive [bonus] is responsible for, for telemetry.
double letUpliftFraction(double bonus) =>
    bonus <= 0 ? 0 : bonus / (1.0 + bonus);
