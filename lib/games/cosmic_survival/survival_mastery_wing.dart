/// Wing's three mastery paths: the numbers, the per-companion state, and the
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
/// * **Burn Through** is dwell. `frostBuildup` already proves Wing accumulates
///   on a held target, but only Ice uses it and only to freeze; a damage ramp
///   generalises the idea without touching Ice's signature.
/// * **Longshot** is distance. Nothing in the game reads range, and a sniper
///   that gets worse as enemies close is a real tactical identity.
/// * **Tracer** is the auto-attack. Wing fires two shots and both beam paths
///   ignore them completely, so this path is what makes the two halves of the
///   kit talk to each other.
///
/// What is deliberately absent. The draft tree was Mane's, almost verbatim:
/// "when both shots hit the same enemy, deal +25% and apply your element" next
/// to Mane's "when both slashes hit the same enemy, deal +20% and apply your
/// element", and a Focus counter that banked to five on a clean pair and was
/// spent on the special, which is War Rhythm down to the per-stack value. It
/// also added two more every-Nth-attack nodes to the four the game already
/// has, built a path on piercing (Mane's identity), left a damaging lane on
/// the ground (Wing/Lava's own scar) and ended with an echo of the special
/// after it finishes, which is Horn's Juggernaut.
library;

/// Node ids, so the game never spells one out as a string literal.
class WingNodes {
  const WingNodes._();

  static const burnThroughPath = 'wing.burn_through';
  static const longshotPath = 'wing.longshot';
  static const tracerPath = 'wing.tracer';

  static const bore = 'wing.burn_through.bore';
  static const deeper = 'wing.burn_through.deeper';
  static const noReprieve = 'wing.burn_through.no_reprieve';
  static const carryThrough = 'wing.burn_through.carry_through';

  static const rangefinder = 'wing.longshot.rangefinder';
  static const longLens = 'wing.longshot.long_lens';
  static const standoff = 'wing.longshot.standoff';
  static const horizon = 'wing.longshot.horizon';

  static const tracerRounds = 'wing.tracer.tracer_rounds';
  static const rangingShots = 'wing.tracer.ranging_shots';
  static const hotBarrel = 'wing.tracer.hot_barrel';
  static const liveFeed = 'wing.tracer.live_feed';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class WingTuning {
  const WingTuning._();

  // ── Burn Through ──
  /// Bore, then Deeper: how far the ramp climbs and how fast it gets there.
  static const double boreMax = 0.45;
  static const double deeperMax = 0.80;
  static const double boreRampSeconds = 3.0;
  static const double deeperRampSeconds = 1.5;

  /// No Reprieve: how long the ramp takes to fade once the beam moves off,
  /// instead of dropping the instant it does.
  static const double reprieveFade = 2.0;

  /// Carry Through: a body that dies at this much of a full ramp hands it on.
  static const double carryThreshold = 0.95;

  // ── Longshot ──
  /// Rangefinder: past this share of the Wing's range, a hit pays more.
  static const double farThreshold = 0.60;
  static const double rangefinderBonus = 0.15;

  /// Long Lens: the bonus climbs with distance to this, and range grows.
  static const double longLensBonus = 0.35;
  static const double longLensRange = 1.20;

  /// Standoff: while nothing is inside this share of range, the full bonus
  /// applies at any distance — the path pays for actually keeping away.
  static const double standoffThreshold = 0.30;

  /// Horizon: range again, and everything past the old edge is at full bonus.
  static const double horizonRange = 1.35;

  // ── Tracer ──
  /// Tracer Rounds, then Hot Barrel: what a landed attack shaves.
  static const double tracerShave = 0.25;
  static const double hotBarrelShave = 0.40;

  /// Ranging Shots, then Hot Barrel: what it banks onto the next beam, and
  /// the ceiling on how much can be banked for one beam.
  static const double rangingExtend = 0.10;
  static const double rangingCap = 1.50;
  static const double hotBarrelExtend = 0.18;
  static const double hotBarrelCap = 3.00;
}

/// One Wing companion's mastery state for the length of a run.
class WingMasteryState {
  /// Seconds banked onto the next beam by Ranging Shots.
  double bankedBeamTime = 0;

  /// A full ramp inherited from a body that died under the beam, waiting for
  /// the next thing the beam touches.
  double carriedRamp = 0;

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

  /// Takes a carried ramp, if one is waiting.
  double takeCarriedRamp() {
    final carried = carriedRamp;
    carriedRamp = 0;
    return carried;
  }

  @override
  String toString() =>
      'WingMasteryState(banked: ${bankedBeamTime.toStringAsFixed(2)}s, '
      'carried: ${carriedRamp.toStringAsFixed(2)})';
}

/// How far Burn Through's ramp can climb, and how fast.
({double max, double rampSeconds, double fade}) wingBoreCurve({
  required bool Function(String nodeId) hasNode,
}) {
  if (!hasNode(WingNodes.bore)) {
    return (max: 0, rampSeconds: WingTuning.boreRampSeconds, fade: 0);
  }
  final deeper = hasNode(WingNodes.deeper);
  return (
    max: deeper ? WingTuning.deeperMax : WingTuning.boreMax,
    rampSeconds: deeper
        ? WingTuning.deeperRampSeconds
        : WingTuning.boreRampSeconds,
    // Without No Reprieve the ramp is gone the moment the beam moves off.
    fade: hasNode(WingNodes.noReprieve) ? WingTuning.reprieveFade : 0,
  );
}

/// The damage multiplier Burn Through has earned on a body the beam has been
/// held on for [dwell] seconds.
double wingBoreMultiplier({
  required bool Function(String nodeId) hasNode,
  required double dwell,
}) {
  final curve = wingBoreCurve(hasNode: hasNode);
  if (curve.max <= 0 || dwell <= 0) return 1.0;
  final t = (dwell / curve.rampSeconds).clamp(0.0, 1.0);
  return 1.0 + curve.max * t;
}

/// How much extra a Longshot deals at [distance], given its [range].
///
/// [nearestEnemyDistance] is what Standoff reads: while nothing has closed
/// inside the threshold, the full bonus applies however near the target is.
double wingLongshotBonus({
  required bool Function(String nodeId) hasNode,
  required double distance,
  required double range,
  required double nearestEnemyDistance,
}) {
  if (!hasNode(WingNodes.rangefinder) || range <= 0) return 0;

  final far = distance / range;
  final standoff =
      hasNode(WingNodes.standoff) &&
      nearestEnemyDistance >= range * WingTuning.standoffThreshold;
  // Horizon pays the full bonus to everything past where the range used to
  // end, which is what the extra range pushed out from under the threshold.
  final horizonFull =
      hasNode(WingNodes.horizon) && far >= WingTuning.farThreshold;

  if (!standoff && far < WingTuning.farThreshold) return 0;

  if (!hasNode(WingNodes.longLens)) return WingTuning.rangefinderBonus;
  if (standoff || horizonFull) return WingTuning.longLensBonus;

  // Between the threshold and the edge the bonus climbs with distance.
  final t = ((far - WingTuning.farThreshold) / (1 - WingTuning.farThreshold))
      .clamp(0.0, 1.0);
  return WingTuning.rangefinderBonus +
      (WingTuning.longLensBonus - WingTuning.rangefinderBonus) * t;
}

/// How much further a Longshot can reach.
double wingRangeMultiplier({required bool Function(String nodeId) hasNode}) {
  var multiplier = 1.0;
  if (hasNode(WingNodes.longLens)) multiplier *= WingTuning.longLensRange;
  if (hasNode(WingNodes.horizon)) multiplier *= WingTuning.horizonRange;
  return multiplier;
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
  final hot = hasNode(WingNodes.hotBarrel);
  final extends_ = hasNode(WingNodes.rangingShots);
  return (
    shave: hot ? WingTuning.hotBarrelShave : WingTuning.tracerShave,
    extend: !extends_
        ? 0.0
        : hot
        ? WingTuning.hotBarrelExtend
        : WingTuning.rangingExtend,
    cap: hot ? WingTuning.hotBarrelCap : WingTuning.rangingCap,
    intoRunningBeam:
        extends_ && beamRunning && hasNode(WingNodes.liveFeed),
  );
}

/// The share of a hit's damage that mastery is responsible for.
double wingUpliftFraction(double multiplier) =>
    multiplier <= 1.0 ? 0.0 : (multiplier - 1.0) / multiplier;
