/// Mystic's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Mystic gets two paths where every other family gets three, and that is the
/// design rather than an omission. Only one Mystic may be fielded at a time,
/// its cast is spent for the whole deployment, and its seventeen worlds are
/// each a bespoke rule or placement with almost no shared surface between
/// them. Two paths that both work for all seventeen beat three where one is
/// filler for eleven of them.
///
/// Reading the runtime is what settled which two. There is no shared "world
/// damage" or "world radius" field to hang a path on — Spirit's world is a
/// rule with no placement at all, Blood's likewise. Two things *are* universal:
///
/// * **`_mysticClock`**, the interval on which a world acts. **Quickening**
///   drives it: more often, sooner, harder.
/// * **The element, and the fact that a world is a place.** **Firmament**
///   drives that: the world shelters whoever stands in it and lends them its
///   element.
///
/// So one path is what the world does to the enemy and the other is what it
/// does to your team, which is the whole of what an environment can be.
///
/// The obvious third path was uptime — a world holds until its caster dies, so
/// "survive longer" is literally "world duration". Every version of it
/// collided with something already built: a world that lingers past your death
/// is Kin's Unbroken, and surviving a lethal hit so the world holds is
/// Kin/Fire's phoenix.
///
/// What is deliberately absent. The draft tree banked Insight to five on a
/// clean volley and spent it on the world, which is Mane's War Rhythm for the
/// fifth family running. It also fired on an every-Nth-attack cadence three
/// separate times, marked a body (Pip's Pins, Let's Sighted), paid a bonus for
/// landing every bolt on one enemy (Mane's Crosscut and Wing's Double Tap),
/// and planted Seeds that pulse damage where they sit, which is Mask.
library;

/// Node ids, so the game never spells one out as a string literal.
class MysticNodes {
  const MysticNodes._();

  static const quickeningPath = 'mystic.quickening';
  static const firmamentPath = 'mystic.firmament';

  static const quickening = 'mystic.quickening.quickening';
  static const firstLight = 'mystic.quickening.first_light';
  static const weightOfHeaven = 'mystic.quickening.weight_of_heaven';
  static const relentlessSky = 'mystic.quickening.relentless_sky';

  static const nativeAir = 'mystic.firmament.native_air';
  static const homeGround = 'mystic.firmament.home_ground';
  static const tended = 'mystic.firmament.tended';
  static const sanctum = 'mystic.firmament.sanctum';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class MysticTuning {
  const MysticTuning._();

  // ── Quickening ──
  /// Quickening, then Relentless Sky: how much more often a world acts. These
  /// are the rate, so the interval is divided by them.
  static const double quickeningRate = 1.25;
  static const double relentlessRate = 2.00;

  /// Weight of Heaven: how much harder each act lands.
  static const double weightOfHeaven = 1.30;

  /// No world may be driven below this interval however the nodes stack. A
  /// world that acts every frame is not a world, it is a crash.
  static const double minimumInterval = 0.35;

  // ── Firmament ──
  /// Native Air, Home Ground: what an ally standing inside the world gets.
  static const double nativeAirMitigation = 0.15;
  static const double homeGroundPower = 0.15;

  /// Tended: healing per second for an ally inside, as a share of their
  /// maximum health, and how often it is paid.
  static const double tendedHealPerSecond = 0.012;
  static const double tendedInterval = 1.0;

  /// How close to the caster counts as inside, before the world's own
  /// footprint is taken into account.
  static const double insideRadius = 260.0;
}

/// One Mystic companion's mastery state for the length of a run.
class MysticMasteryState {
  /// Counts down to the next Tended payment.
  double tendedTimer = 0;

  /// Healing this world has handed out, for telemetry and the HUD.
  double healedInside = 0;

  /// Ticks the mend, reporting the frames it should pay on.
  bool takeTendedTick(double dt) {
    tendedTimer -= dt;
    if (tendedTimer > 0) return false;
    tendedTimer = MysticTuning.tendedInterval;
    return true;
  }

  @override
  String toString() =>
      'MysticMasteryState(healed: ${healedInside.round()})';
}

/// How often a world should act, given the interval it was authored with.
///
/// Clamped at the bottom, because a world driven to act every frame is not a
/// faster world, it is a frame-time bug with a nice name.
double mysticWorldInterval({
  required bool Function(String nodeId) hasNode,
  required double authoredInterval,
}) {
  if (authoredInterval <= 0) return authoredInterval;
  var rate = 1.0;
  if (hasNode(MysticNodes.quickening)) rate *= MysticTuning.quickeningRate;
  if (hasNode(MysticNodes.relentlessSky)) {
    // Relentless Sky is stated against where the world started, not against
    // Quickening, so the capstone replaces the opener's rate rather than
    // multiplying with it.
    rate = MysticTuning.relentlessRate;
  }
  if (rate <= 1.0) return authoredInterval;
  // A world already authored faster than the floor is left exactly as it is.
  // Clamping it would put the lower limit above the upper one and throw, and
  // there is nothing to speed up anyway.
  if (authoredInterval <= MysticTuning.minimumInterval) return authoredInterval;
  return (authoredInterval / rate).clamp(
    MysticTuning.minimumInterval,
    authoredInterval,
  );
}

/// Whether the world's first act comes immediately rather than after a turn.
bool mysticActsOnIgnition({required bool Function(String nodeId) hasNode}) =>
    hasNode(MysticNodes.firstLight);

/// How much harder everything the world does lands.
double mysticWorldPower({required bool Function(String nodeId) hasNode}) =>
    hasNode(MysticNodes.weightOfHeaven) ? MysticTuning.weightOfHeaven : 1.0;

/// What an ally standing inside the world receives.
({double mitigation, double power, bool mends, bool lendsElement})
mysticFirmament({required bool Function(String nodeId) hasNode}) {
  if (!hasNode(MysticNodes.nativeAir)) {
    return (mitigation: 1.0, power: 1.0, mends: false, lendsElement: false);
  }
  return (
    mitigation: 1 - MysticTuning.nativeAirMitigation,
    power: hasNode(MysticNodes.homeGround)
        ? 1 + MysticTuning.homeGroundPower
        : 1.0,
    mends: hasNode(MysticNodes.tended),
    lendsElement: hasNode(MysticNodes.sanctum),
  );
}

/// The share of a hit's damage that mastery is responsible for.
double mysticUpliftFraction(double multiplier) =>
    multiplier <= 1.0 ? 0.0 : (multiplier - 1.0) / multiplier;
