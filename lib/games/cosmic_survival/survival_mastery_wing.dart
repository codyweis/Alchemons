/// Wing's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Wing is the Beams family, and a beam is the only thing in this game that is
/// *held*: it has a duration, a tick interval, and a target it stays on. Every
/// other family throws something and lets go.
///
/// The hard part of designing for Wing is that its own seventeen elements have
/// already claimed nearly every beam behaviour there is — sweeping is Fire's,
/// charging is Lightning's, refracting is Light's, scarring the ground is
/// Lava's, executing is Blood's, lifesteal is Crystal's, freezing is Ice's.
/// So the test a path has to pass is not "is this unclaimed" but **does it
/// take an element's signature, or a neutral property of a beam?**
///
/// * **Longshot** is distance. Nothing in the game reads range, and a sniper
///   that gets worse as enemies close is a real tactical identity: it aims
///   ahead of what is far off (Long Lens) and takes a shot at whatever walks
///   into its far reach or takes aim at twice its range (Overwatch).
/// * **Tracer** is the auto-attack. Wing fires two shots and its beam ignored
///   them completely, so this path is what makes the two halves of the kit
///   talk to each other, both ways: the shots feed the beam, and a firing beam
///   doubles the shots (Hot Barrel).
///
/// Burn Through, a damage ramp on a held target, was cut on 2026-10-29: it
/// was a number that climbed, and it moved a horde wave by a point.
///
/// What is deliberately absent. The draft tree was Mane's, almost verbatim:
/// "when both shots hit the same enemy, deal +25% and apply your element" next
/// to Mane's "when both slashes hit the same enemy, deal +20% and apply your
/// element", and a Focus counter that banked to five on a clean pair and was
/// spent on the special, which is War Rhythm down to the per-stack value. It
/// also added two more every-Nth-attack nodes to the four the game already
/// has, built a path on piercing (Mane's identity), left a damaging lane on
/// the ground (Wing/Lava's own scar) and ended with a repeat of the special
/// after it finishes, which is Horn's Juggernaut.
library;

import 'dart:math' as math;

/// Node ids, so the game never spells one out as a string literal.
class WingNodes {
  const WingNodes._();

  static const longshotPath = 'wing.longshot';
  static const tracerPath = 'wing.tracer';

  static const rangefinder = 'wing.longshot.rangefinder';
  static const longLens = 'wing.longshot.long_lens';
  static const standoff = 'wing.longshot.standoff';
  static const overwatch = 'wing.longshot.overwatch';

  static const tracerRounds = 'wing.tracer.tracer_rounds';

  /// Loaded Beam. Sold as Ranging Shots, so it keeps that id.
  static const loadedBeam = 'wing.tracer.ranging_shots';
  static const hotBarrel = 'wing.tracer.hot_barrel';
  static const liveFeed = 'wing.tracer.live_feed';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class WingTuning {
  const WingTuning._();

  // ── Longshot ──
  /// Rangefinder: past this share of the Wing's range, a hit pays more. The
  /// same band is Long Lens's "far" and Overwatch's far reach.
  static const double farThreshold = 0.60;
  static const double rangefinderBonus = 0.15;

  /// Long Lens: how much further the Wing reaches.
  static const double longLensRange = 1.20;

  /// Long Lens: the most a far shot leads its target by, in seconds of the
  /// target's travel, so a body that turns does not drag the aim off the map.
  static const double leadCap = 0.8;

  /// Standoff: while nothing is inside this share of range, the bonus
  /// applies at any distance — the path pays for actually keeping away.
  static const double standoffThreshold = 0.30;

  /// Overwatch: how often a Wing looks for bodies newly in its far reach,
  /// and how many free shots it may take a second, banked up to
  /// [overwatchBurst]. A wave pouring in at once is shot as fast as the
  /// bank refills, not hundreds in one frame. Six a second at first; at six
  /// the path dealt 29% of a Wing's damage at P50 wave 36 and moved the hold
  /// rate a point, at twelve 40% and two (the 2026-10-29 probe).
  static const double overwatchScanInterval = 0.1;
  static const double overwatchShotsPerSecond = 12.0;
  static const double overwatchBurst = 6.0;

  /// Overwatch: a body taking aim (a brute charging its siege beam, a
  /// sentinel gathering its volley) within this many times the Wing's range
  /// takes a free shot from the same bank, each time it takes aim.
  ///
  /// Traced at P50 wave 36 (2026-10-29, second pass): brutes' siege beams
  /// were 55-70% of what the orb took; three in four were fired by a brute
  /// at three quarters of its health or more, and four in five by one
  /// further than 160% of the Wing's range from it, while the Wing worked
  /// the outer edge of the field — so the far-band shots fell on bodies
  /// that were not the ones breaking the orb. Turning the Wing itself onto
  /// those brutes instead (it stopped shooting the far band) held fewer
  /// waves than the far-band shots alone: 61% against 64%.
  static const double overwatchReach = 2.0;

  // ── Tracer ──
  /// Tracer Rounds: what a landed attack shaves off the special.
  static const double tracerShave = 0.25;

  /// Loaded Beam: what it banks onto the next beam, and the ceiling on how
  /// much can be banked for one beam.
  static const double rangingExtend = 0.10;
  static const double rangingCap = 1.50;

  /// Hot Barrel: the auto-attack's cooldown while the Wing's beam is firing
  /// (twice as fast).
  static const double hotBarrelCooldown = 0.5;
}

/// One Wing companion's mastery state for the length of a run.
class WingMasteryState {
  /// Seconds banked onto the next beam by Loaded Beam.
  double bankedBeamTime = 0;

  /// Overwatch: the bodies this Wing has already taken its free shot at.
  /// One shot each, ever; a body leaves the set when it dies.
  final Set<Object> overwatched = {};

  /// Overwatch: countdown to the next look for bodies in the far reach.
  double overwatchScan = 0;

  /// Overwatch: free shots in the bank ([WingTuning.overwatchBurst]).
  double overwatchShots = WingTuning.overwatchBurst;

  /// Free shots fired this run, for the tests and telemetry, and how many
  /// of them went at a body taking aim.
  int overwatchFired = 0;
  int overwatchAimShots = 0;

  /// Banks time toward the next beam, respecting the ceiling.
  void bankBeamTime(double seconds, double cap) {
    if (seconds <= 0) return;
    bankedBeamTime = (bankedBeamTime + seconds).clamp(0.0, cap);
  }

  /// Spends everything banked, which is what opening a beam does.
  double takeBankedBeamTime() {
    final banked = bankedBeamTime;
    bankedBeamTime = 0;
    return banked;
  }

  /// Refills the free-shot bank and reports whether this frame is a look.
  bool tickOverwatch(double dt) {
    overwatchShots = math.min(
      WingTuning.overwatchBurst,
      overwatchShots + dt * WingTuning.overwatchShotsPerSecond,
    );
    overwatchScan -= dt;
    if (overwatchScan > 0) return false;
    overwatchScan = WingTuning.overwatchScanInterval;
    return true;
  }

  /// Spends one free shot on [body], once. False when it has had its shot
  /// or the bank is dry — a dry bank leaves it for a later look.
  bool takeOverwatchShot(Object body) {
    if (overwatched.contains(body) || overwatchShots < 1) return false;
    overwatchShots -= 1;
    overwatched.add(body);
    overwatchFired++;
    return true;
  }

  /// Spends one free shot on a body taking aim. Every time it takes aim,
  /// not once; false only when the bank is dry.
  bool takeOverwatchAimShot() {
    if (overwatchShots < 1) return false;
    overwatchShots -= 1;
    overwatchFired++;
    overwatchAimShots++;
    return true;
  }

  @override
  String toString() =>
      'WingMasteryState(banked: ${bankedBeamTime.toStringAsFixed(2)}s, '
      'overwatched: ${overwatched.length})';
}

/// How much extra a Longshot deals at [distance], given its [range].
///
/// [nearestEnemyDistance] is what Standoff reads: while nothing has closed
/// inside the threshold, the bonus applies however near the target is.
double wingLongshotBonus({
  required bool Function(String nodeId) hasNode,
  required double distance,
  required double range,
  required double nearestEnemyDistance,
}) {
  if (!hasNode(WingNodes.rangefinder) || range <= 0) return 0;
  final far = distance / range >= WingTuning.farThreshold;
  final standoff =
      hasNode(WingNodes.standoff) &&
      nearestEnemyDistance >= range * WingTuning.standoffThreshold;
  return far || standoff ? WingTuning.rangefinderBonus : 0;
}

/// Whether [distance] is in the far reach of a Wing whose range is [range]:
/// Rangefinder's band, Long Lens's lead and Overwatch's watch.
bool wingInFarReach({required double distance, required double range}) =>
    range > 0 &&
    distance <= range &&
    distance >= range * WingTuning.farThreshold;

/// How much further a Longshot can reach.
double wingRangeMultiplier({required bool Function(String nodeId) hasNode}) =>
    hasNode(WingNodes.longLens) ? WingTuning.longLensRange : 1.0;

/// Overwatch: how many times its range a Wing watches for a body taking
/// aim, or 0 without the node.
double wingOverwatchReach({required bool Function(String nodeId) hasNode}) =>
    hasNode(WingNodes.overwatch) ? WingTuning.overwatchReach : 0.0;

/// Long Lens: where to aim a shot from [from] at a body at [target] moving at
/// [velocity], for a shot travelling at [shotSpeed] — the point it will have
/// reached when the shot gets there. Solved by two refinements of the flight
/// time, which is plenty for bodies a tenth as fast as the shot, and capped
/// at [WingTuning.leadCap] seconds of travel.
({double dx, double dy}) wingLeadPoint({
  required double fromX,
  required double fromY,
  required double targetX,
  required double targetY,
  required double velocityX,
  required double velocityY,
  required double shotSpeed,
}) {
  if (shotSpeed <= 0) return (dx: targetX, dy: targetY);
  var aimX = targetX;
  var aimY = targetY;
  for (var i = 0; i < 2; i++) {
    final dx = aimX - fromX;
    final dy = aimY - fromY;
    final t = math.min(
      WingTuning.leadCap,
      math.sqrt(dx * dx + dy * dy) / shotSpeed,
    );
    aimX = targetX + velocityX * t;
    aimY = targetY + velocityY * t;
  }
  return (dx: aimX, dy: aimY);
}

/// What one landed attack is worth to Tracer.
///
/// [intoRunningBeam] is Live Feed: while a beam is already firing, the time
/// goes into that beam rather than being banked for the next one.
({double shave, double extend, double cap, bool intoRunningBeam}) wingTracer({
  required bool Function(String nodeId) hasNode,
  required bool beamRunning,
}) {
  if (!hasNode(WingNodes.tracerRounds)) {
    return (shave: 0, extend: 0, cap: 0, intoRunningBeam: false);
  }
  final loaded = hasNode(WingNodes.loadedBeam);
  return (
    shave: WingTuning.tracerShave,
    extend: loaded ? WingTuning.rangingExtend : 0.0,
    cap: WingTuning.rangingCap,
    intoRunningBeam: loaded && beamRunning && hasNode(WingNodes.liveFeed),
  );
}

/// Hot Barrel: the auto-attack cooldown multiplier, below 1 while the Wing's
/// beam is firing.
double wingBasicCooldownMultiplier({
  required bool Function(String nodeId) hasNode,
  required bool beamRunning,
}) => beamRunning && hasNode(WingNodes.hotBarrel)
    ? WingTuning.hotBarrelCooldown
    : 1.0;

/// The share of a hit's damage that mastery is responsible for.
double wingUpliftFraction(double multiplier) =>
    multiplier <= 1.0 ? 0.0 : (multiplier - 1.0) / multiplier;
