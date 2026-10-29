/// Mane's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Phase 3 of docs/survival_species_mastery_design.md — the vertical slice.
/// Mane is the flexible skirmisher whose chassis is two close-angle slashes
/// and a slow piercing catapult, and each path changes one of them:
///
/// * **War Rhythm** (resonance) is about the slashes. A clean pair banks
///   Rhythm and crosses through to the next body with the element
///   (Crosscut), every fourth attack throws a ring, and a special cast on a
///   full reserve spends it on an Encore.
/// * **Limitless** carries one idea four times: the catapult shot does not
///   stop. It flies further, bends after the bodies ahead of it, stops
///   expiring, and finally the first shot of a cast peels off to circle the
///   arena.
///
/// The family had a third path, Twin Fang, until 2026-10-29. Three of its
/// four nodes were damage on hits that already killed (the 2026-10-21 sweep
/// measured the whole path at a point of party share), and every family went
/// to two paths. Its one node that changed what an attack does, Crosscut,
/// moved to War Rhythm, where a clean pair already earned something. War
/// Rhythm's Crescendo went at the same time: it spent the reserve on +12%
/// for a few attacks, so the special now spends Rhythm only for an Encore.
/// Limitless's Overdraw, a flat 15%, became Hunter's Arc.
///
/// Before that the family had a Tempest Claw path instead of Limitless. Its
/// one good node, Tempest Ring, moved to War Rhythm, where a cadence counter
/// belongs.
///
/// The state below lives per companion slot for the length of a run. Nothing
/// here reaches into combat: the game owns the one place that reads this state
/// and turns it into slashes, and the shared runtime owns cast accounting,
/// payload rate limits and the object budget.
library;

import 'dart:math';
import 'dart:ui' show Offset;

/// Node ids, so the game never spells one out as a string literal. A typo in
/// a literal is a node that silently never fires.
class ManeNodes {
  const ManeNodes._();

  static const resonancePath = 'mane.resonance';
  static const limitlessPath = 'mane.limitless';

  static const measuredCuts = 'mane.resonance.measured_cuts';
  static const crosscut = 'mane.resonance.crosscut';
  static const tempestRing = 'mane.resonance.tempest_ring';
  static const encore = 'mane.resonance.encore';

  static const farThrow = 'mane.limitless.far_throw';
  static const huntersArc = 'mane.limitless.hunters_arc';
  static const noHorizon = 'mane.limitless.no_horizon';
  static const endlessCircuit = 'mane.limitless.endless_circuit';
}

/// Cast tags, set when a cast launches and read when it lands.
class ManeCastTags {
  const ManeCastTags._();

  /// This is a Tempest Ring, not a scheduled attack.
  static const tempestRing = 'mane.tempestRing';

  /// This is a pair that crossed through a body (Crosscut), not a scheduled
  /// attack. It crosses no further.
  static const crosscut = 'mane.crosscut';
}

/// Initial balance targets. Every one of these is a prototype and expected to
/// move once the slice is simulated.
class ManeTuning {
  const ManeTuning._();

  // ── War Rhythm ──
  /// Measured Cuts: a dual hit banks Rhythm; a cast that misses with both
  /// blades spends one.
  static const int maxRhythm = 5;
  static const double rhythmHastePerStack = 0.02;

  /// Crosscut: a pair that both landed on one body crosses through it and
  /// flies on to the next body ahead — the nearest inside [crosscutCone]
  /// either side of where it was going, within [crosscutReach] — or straight
  /// on when there is none. The crossed pair is the attack's own two
  /// slashes, at their own damage, for [crosscutLife] seconds; its first hit
  /// carries one payload of the element, and both of it landing on one body
  /// crosses that too, up to [crosscutCrossings] bodies an attack.
  ///
  /// Until 2026-10-29 Crosscut was +40% physical on the body both blades
  /// had already struck (20% before the 2026-10-21 sweep): damage on a body
  /// that mostly died to the pair anyway, which moved neither the share nor
  /// the hold rate. Reaching a second body is what a horde notices.
  static const double crosscutReach = 240.0;

  /// How many bodies one attack's pair may cross through in all: a crossed
  /// pair that lands both blades on its next body crosses that one too. One
  /// crossing (a second body) measured no lift in waves held at P50 wave 36
  /// (2026-10-29), where the pair reaching only one more body was a few
  /// percent of a Mane's damage.
  static const int crosscutCrossings = 3;
  static const double crosscutCone = pi / 3;
  static const double crosscutLife = 0.9;
  static const double crosscutPayloadStrength = 1.0;

  /// Tempest Ring: every fourth cast throws a ring of radial slashes.
  static const int tempestRingCadence = 4;
  static const int tempestRingSlashes = 8;
  static const double tempestRingSlashFraction = 0.20;
  static const int tempestRingMaxHitsPerTarget = 3;
  static const double tempestRingSpeed = 0.85;
  static const double tempestRingLife = 0.55;

  /// Encore: a special cast on a full reserve spends it and opens a window
  /// that kills extend.
  static const double encoreDuration = 6.0;
  static const double encoreHaste = 0.25;
  static const double encoreWidthScale = 1.20;
  static const double encoreKillExtension = 0.4;
  static const double encoreMaxExtension = 2.0;

  /// How long a cast is given to land before a silent one counts as a miss.
  /// A slash lives two seconds; the slack keeps a slow last hit from costing
  /// the player a Rhythm they actually earned.
  static const double missGrace = 2.3;

  // ── Limitless ──
  /// Far Throw: the special's projectiles carry 45% further before fading.
  static const double farThrowLifeScale = 1.45;

  /// Hunter's Arc: a shot that has struck something looks this far ahead
  /// for the next body...
  static const double arcSearchRadius = 260.0;

  /// ...inside this half-angle either side of where it is heading (about
  /// ±60°). A body behind it or off to the side is not "ahead".
  static const double arcConeHalfAngle = pi / 3;

  /// It turns no tighter than a circle this wide, so a slow catapult bends
  /// gently (about 1 rad/s at the family's crawl) and reads as an arc...
  static const double arcTurnRadius = 160.0;

  /// ...and no faster than this however fast it flies (Air's gale, Fire's
  /// fireballs, Mud's shards, Lightning's orbs), so a quick shot does not
  /// snap onto a body either.
  static const double arcMaxTurnRate = 2.6;

  /// The most it turns in all, so a shot that keeps finding bodies ahead
  /// still leaves: with No Horizon only the arena edge ends a shot, and a
  /// shot that could turn forever could circle a horde for the rest of the
  /// wave. A quarter of a lap: at a third (2026-10-29, first measure)
  /// Limitless carried a Mane to 44% of party damage at Potential 50 where
  /// Overdraw had it at 42%; a quarter and a sixth both measured 42% (39% at
  /// Potential 80), so the arc pays for its first bends, and a quarter
  /// leaves room to bend from one body to the next.
  static const double arcTurnBudget = pi / 2;

  /// How often it picks its body again, as homing does: often enough to
  /// follow a walking body, rarely enough that a cast of a dozen shots is a
  /// handful of grid queries a frame.
  static const double arcRescanInterval = 0.15;

  /// Light's ward does not fly; its rings turn round the Mane. A ring that
  /// has struck something leans out of (or into) its orbit toward the
  /// nearest body ahead of it on its round, up to this far...
  static const double arcRingMaxReach = 80.0;

  /// ...at this many units a second, and eases back when nothing is ahead.
  static const double arcRingReachSpeed = 150.0;

  /// A ring never leans closer to the Mane than this.
  static const double arcRingMinRadius = 24.0;

  /// Endless Circuit: the first projectile of each cast sweeps out to this
  /// fraction of the arena radius and circles it.
  static const double circuitRadiusFraction = 0.72;

  /// ...striking at this share of the shot it was, once a lap per body
  /// ([circuitHitsPerLap]). It struck at full, twice a lap, until the
  /// 2026-10-21 mastery sweep, and that one blade was the whole of the
  /// path's outlier: Far Throw, Overdraw and No Horizon together moved a
  /// Mane's party share by a point, the circuit on top of them took it from
  /// 35% to 51% at Potential 50 (31% to 44% at 80). A horde crosses the rim
  /// on its way in, so the blade meets most of a wave; it cuts what crosses
  /// rather than throwing a second special at it. At a quarter of the shot
  /// it still carried a Mane to 46%.
  static const double circuitDamageScale = 0.15;

  /// How many times a lap the circuit may strike one body: once, where it
  /// was the family's two until 2026-10-21 ([circuitDamageScale]).
  static const int circuitHitsPerLap = 1;

  /// Radians per second around the rim — one lap in about eleven seconds.
  /// Halved from 1.15 (2026-09-17): at roughly 940 units a second the head
  /// read as a strobe rather than an object, and coverage never came from its
  /// speed anyway. It comes from the arc it leaves behind.
  static const double circuitAngularSpeed = 0.575;

  /// Half the length a slash is drawn at, per point of visual scale — the
  /// number the renderer uses. The circuit collides as the blade it draws
  /// rather than as the small circle every Mane shot normally uses.
  static const double circuitBladeHalfLength = 8.0;
}

/// One Mane companion's mastery state for the length of a run.
class ManeMasteryState {
  /// Scheduled attacks since the last ring.
  int castsSinceRing = 0;

  int rhythm = 0;

  double encoreTimer = 0;

  /// Seconds of Encore already bought with kills, against
  /// [ManeTuning.encoreMaxExtension].
  double encoreExtensionUsed = 0;

  /// Crosscut: each crossed pair in flight (by its cast), and how many
  /// bodies its attack has crossed through so far.
  final Map<int, int> crossings = {};

  /// Crosscut: casts whose pair has already crossed through a body. A pair
  /// crosses once; the pair it sends on may cross again.
  final Set<int> crossed = {};

  /// Claims [castId]'s one crossing. False when it has crossed already.
  bool claimCrossing(int castId) {
    if (!crossed.add(castId)) return false;
    // Casts are answerable for four seconds; a few dozen ids is plenty.
    if (crossed.length > 64) crossed.remove(crossed.first);
    return true;
  }

  /// Records a crossed pair's cast and how many bodies it has crossed.
  void noteCrossedPair(int castId, int depth) {
    crossings[castId] = depth;
    if (crossings.length > 64) crossings.remove(crossings.keys.first);
  }

  /// Basic casts launched and not yet judged hit-or-miss, oldest first.
  /// Bounded: a Mane cannot outrun [ManeTuning.missGrace] by more than a
  /// handful of casts even at full Encore haste.
  final List<int> pendingCasts = [];

  bool get encoreActive => encoreTimer > 0;

  /// Banks a Rhythm from a clean pair. Returns true if one was actually
  /// gained, so the caller can react to reaching the cap.
  bool gainRhythm() {
    if (rhythm >= ManeTuning.maxRhythm) return false;
    rhythm++;
    return true;
  }

  /// Spends a Rhythm for a cast that landed nothing.
  void loseRhythm() {
    if (rhythm > 0) rhythm--;
  }

  /// A special cast, for Encore: on a full reserve with no Encore running it
  /// spends all five and opens one, and reports that it did. Below five, or
  /// while an Encore runs, the reserve is left alone — the special is the
  /// only thing that spends Rhythm, and it spends it only here.
  bool trySpendForEncore() {
    if (rhythm < ManeTuning.maxRhythm || encoreActive) return false;
    rhythm = 0;
    return tryOpenEncore();
  }

  /// Opens an Encore, but only if one is not already running: the capstone
  /// says kills extend the current window and that it cannot otherwise
  /// refresh itself.
  bool tryOpenEncore() {
    if (encoreTimer > 0) return false;
    encoreTimer = ManeTuning.encoreDuration;
    encoreExtensionUsed = 0;
    return true;
  }

  /// A kill buys more Encore, up to the capstone's ceiling.
  void extendEncore() {
    if (encoreTimer <= 0) return;
    final room = ManeTuning.encoreMaxExtension - encoreExtensionUsed;
    if (room <= 0) return;
    final granted = room < ManeTuning.encoreKillExtension
        ? room
        : ManeTuning.encoreKillExtension;
    encoreTimer += granted;
    encoreExtensionUsed += granted;
  }

  void tick(double dt) {
    if (encoreTimer > 0) {
      encoreTimer -= dt;
      if (encoreTimer <= 0) {
        encoreTimer = 0;
        encoreExtensionUsed = 0;
      }
    }
  }

  /// Basic attack cooldown multiplier from Rhythm and Encore. Below 1 is
  /// faster.
  double hasteMultiplier({
    required bool hasMeasuredCuts,
    required bool hasEncore,
  }) {
    var haste = 0.0;
    if (hasMeasuredCuts) haste += rhythm * ManeTuning.rhythmHastePerStack;
    if (hasEncore && encoreActive) haste += ManeTuning.encoreHaste;
    if (haste <= 0) return 1.0;
    // A multiplier rather than a subtraction so stacked haste approaches a
    // floor instead of reaching zero cooldown.
    return 1.0 / (1.0 + haste);
  }

  /// How much wider the pair is drawn and collides: Encore's wider slashes.
  double slashWidthScale({required bool hasEncore}) =>
      hasEncore && encoreActive ? ManeTuning.encoreWidthScale : 1.0;

  @override
  String toString() =>
      'ManeMasteryState(rhythm: $rhythm, '
      'encore: ${encoreTimer.toStringAsFixed(1)}, ring: $castsSinceRing)';
}

/// [angle] brought into -π..π.
double _wrapAngle(double angle) {
  var a = angle;
  while (a > pi) {
    a -= 2 * pi;
  }
  while (a < -pi) {
    a += 2 * pi;
  }
  return a;
}

/// Hunter's Arc: the signed angle, in -π..π, between a shot's [heading]
/// and the direction [toBody].
double maneArcBearing(double heading, Offset toBody) =>
    _wrapAngle(atan2(toBody.dy, toBody.dx) - heading);

/// Hunter's Arc: whether a body at [toBody] from a shot heading [heading]
/// is ahead of it — inside [ManeTuning.arcConeHalfAngle] either side.
bool maneArcAhead(double heading, Offset toBody) {
  if (toBody.dx == 0 && toBody.dy == 0) return false;
  return maneArcBearing(heading, toBody).abs() <= ManeTuning.arcConeHalfAngle;
}

/// Crosscut: whether a body at [toBody] from where a crossed pair leaves a
/// body, heading [heading], is ahead of it — inside
/// [ManeTuning.crosscutCone] either side.
bool maneCrosscutAhead(double heading, Offset toBody) {
  if (toBody.dx == 0 && toBody.dy == 0) return false;
  return maneArcBearing(heading, toBody).abs() <= ManeTuning.crosscutCone;
}

/// Hunter's Arc: the signed turn, in radians, a shot heading [heading] at
/// [speed] units a second makes toward [toTarget] over [dt].
///
/// Held to the tighter of [ManeTuning.arcTurnRadius] and
/// [ManeTuning.arcMaxTurnRate], so it bends rather than snaps, and to
/// [budgetLeft], what remains of [ManeTuning.arcTurnBudget].
double maneArcTurn({
  required double heading,
  required Offset toTarget,
  required double speed,
  required double dt,
  required double budgetLeft,
}) {
  if (budgetLeft <= 0 || dt <= 0 || speed <= 0) return 0;
  final rate = min(
    speed / ManeTuning.arcTurnRadius,
    ManeTuning.arcMaxTurnRate,
  );
  final cap = min(rate * dt, budgetLeft);
  return maneArcBearing(heading, toTarget).clamp(-cap, cap).toDouble();
}

/// Hunter's Arc for a Light ward ring: the reach, past its own orbit, it
/// leans to over [dt] — toward [wantReach] (0 to ease home), at
/// [ManeTuning.arcRingReachSpeed], never past [ManeTuning.arcRingMaxReach]
/// and never closer to the Mane than [ManeTuning.arcRingMinRadius].
double maneArcRingReach({
  required double reach,
  required double wantReach,
  required double orbitRadius,
  required double dt,
}) {
  final floor = min(0.0, ManeTuning.arcRingMinRadius - orbitRadius);
  final goal = wantReach
      .clamp(
        max(-ManeTuning.arcRingMaxReach, floor),
        ManeTuning.arcRingMaxReach,
      )
      .toDouble();
  final step = ManeTuning.arcRingReachSpeed * dt;
  final delta = (goal - reach).clamp(-step, step).toDouble();
  return reach + delta;
}
