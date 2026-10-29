/// Mystic's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Only one Mystic may be fielded at a time, its cast is spent for the whole
/// deployment, and its seventeen worlds are each a bespoke rule or placement
/// with almost no shared surface between them. Two paths that both work for
/// all seventeen beat three where one is filler for eleven of them.
///
/// Reading the runtime is what settled which two. There is no shared "world
/// damage" or "world radius" field to hang a path on — Spirit's world is a
/// rule with no placement at all, Blood's likewise. Two things *are* shared:
///
/// * **Every world acts.** A bolt falls, the ground quakes, a vent blows, a
///   vine lashes, an ember catches, a pool bites, the dawn breaks, the tithe
///   is drawn. Each world's act is its own, so the game marks each one where
///   it happens and hands it a way to happen again ([mysticWorldReplays]).
///   **Quickening** drives the acts: a death after an act brings it again at
///   once, the first comes at once, each comes again as an aftershock, and
///   at the top each comes twice in a row. Ice's blizzard holds every body
///   every frame and had no act, so the path gives it one: a moment's hard
///   freeze of everything in it, on a beat ([mysticIceActs]).
/// * **The element, and the fact that a world is a place.** **Firmament**
///   drives that: the world shelters whoever stands in it and lends them its
///   element.
///
/// So one path is what the world does to the enemy and the other is what it
/// does to your team, which is the whole of what an environment can be.
///
/// Until 2026-10-29 Quickening was three number bumps (acts 25% more often,
/// lands 30% harder, acts twice as often), read through the world surge.
/// Its first rewrite hurried the next act 0.2 s for every body the world
/// killed, which reached nine worlds of seventeen: six never kill, and two
/// keep no clock to hurry. A death after an act reaches all of them.
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
  static const aftershock = 'mystic.quickening.aftershock';
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
  /// Quickening: how hard the act a death calls for lands.
  ///
  /// One repeat per act of the world's own, never one per death: a world's
  /// acts run from an ember catching several times a second to a quake every
  /// half minute, and a dawn that mends everything, so "every death acts
  /// again" at a flat rate was a quake a second and a mend that never let
  /// the orb fall. Tied to its own acts, every world gains the same half.
  static const double quickenStrength = 0.5;

  /// Ice's act, which only this path gives it: every [iceActInterval]
  /// seconds (quickened by the world surge and the caster's SPECIAL, as the
  /// other clocked worlds are) the blizzard freezes everything in it to
  /// [iceFreezeSpeed] for [iceActHoldShare] of that beat. A share of the
  /// beat rather than a flat hold, so a world that beats faster does not
  /// freeze for longer in all: with every node bought, about a third of the
  /// time. A repeat adds its strength's share to the freeze still running.
  static const double iceActInterval = 6.0;
  static const double iceActHoldShare = 0.12;
  static const double iceFreezeSpeed = 0.05;

  /// Aftershock: how long after an act it comes again, and how hard.
  static const double aftershockDelay = 0.5;
  static const double aftershockStrength = 0.4;

  /// Relentless Sky: the act comes again this soon after, whole — soon
  /// enough to read as twice in a row, late enough to be seen as two.
  static const double relentlessDelay = 0.25;
  static const double relentlessStrength = 1.0;

  /// The most repeats one world may have waiting. An ember field acts dozens
  /// of times a second in a crowd; past this the newest go unrepeated.
  static const int maxPendingReplays = 240;

  // ── Firmament ──
  /// Native Air, Home Ground: what an ally standing inside the world gets.
  static const double nativeAirMitigation = 0.15;
  static const double homeGroundPower = 0.15;

  /// Tended: healing per second for an ally inside, as a share of their
  /// maximum health, and how often it is paid.
  static const double tendedHealPerSecond = 0.012;
  static const double tendedInterval = 1.0;

  /// Sanctum: an ally's attack from inside the world lands the world's
  /// element (the Mystic's own payload, at this strength) at most once per
  /// body in this many seconds, however many allies are firing at it.
  static const double sanctumStrength = 0.5;
  static const double sanctumCooldown = 0.5;

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

  /// Deaths that made the world act again (Quickening), and acts repeated by
  /// Aftershock and Relentless Sky, for the tests and telemetry.
  int quickenings = 0;
  int replays = 0;

  /// Quickening: the world's latest act of its own, how to do it again at a
  /// strength ([noteAct]).
  void Function(double strength)? latestAct;

  /// Whether the world has acted since a death last made it act again, and
  /// whether a body has died since then.
  bool quickenReady = false;
  bool quickenDue = false;

  /// Mud's act is the weight on a hit, hundreds a second, so its latest is
  /// kept as the body and the weight's part of the hit, read by one act
  /// made once ([mireAct]) rather than a new one for every hit.
  Object? mireBody;
  double mireExtra = 0;
  void Function(double strength)? mireAct;

  /// An act of the world's own: the next death may call for it again.
  void noteAct(void Function(double strength) act) {
    latestAct = act;
    quickenReady = true;
  }

  /// A body died while the world stood.
  void noteDeath() {
    if (quickenReady) quickenDue = true;
  }

  /// The act a death has called for, once, or null when none is: one
  /// repeat per act of the world's own, however many die after it.
  void Function(double strength)? takeQuickening() {
    if (!quickenDue) return null;
    quickenDue = false;
    final act = latestAct;
    if (!quickenReady || act == null) return null;
    quickenReady = false;
    quickenings++;
    return act;
  }

  /// Ticks the mend, reporting the frames it should pay on.
  bool takeTendedTick(double dt) {
    tendedTimer -= dt;
    if (tendedTimer > 0) return false;
    tendedTimer = MysticTuning.tendedInterval;
    return true;
  }

  @override
  String toString() =>
      'MysticMasteryState(healed: ${healedInside.round()}, '
      'quickened: $quickenings, replays: $replays)';
}

/// Whether a death after an act makes the world act again (Quickening).
bool mysticQuickens({required bool Function(String nodeId) hasNode}) =>
    hasNode(MysticNodes.quickening);

/// Whether an Ice world has an act: its freeze, on a beat. Only Quickening
/// gives it one; without it the blizzard is a steady slow and nothing else.
bool mysticIceActs({required bool Function(String nodeId) hasNode}) =>
    hasNode(MysticNodes.quickening);

/// Each act's repeats: Relentless Sky's straight after at full strength, and
/// Aftershock's half a second later at 40%. A repeat is not itself repeated.
List<({double delay, double strength})> mysticWorldReplays({
  required bool Function(String nodeId) hasNode,
}) => [
  if (hasNode(MysticNodes.relentlessSky))
    (
      delay: MysticTuning.relentlessDelay,
      strength: MysticTuning.relentlessStrength,
    ),
  if (hasNode(MysticNodes.aftershock))
    (
      delay: MysticTuning.aftershockDelay,
      strength: MysticTuning.aftershockStrength,
    ),
];

/// Whether the world's first act comes immediately rather than after a turn.
bool mysticActsOnIgnition({required bool Function(String nodeId) hasNode}) =>
    hasNode(MysticNodes.firstLight);

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
