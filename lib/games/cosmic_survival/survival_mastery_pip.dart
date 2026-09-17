/// Pip's three mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Pip's chassis is three fast spread darts at 30% physical each — the rapid,
/// precision-volume family. The three paths are three answers to the same
/// question, which is where those darts go:
///
/// * **Needlepoint** puts all three in one body, banking Pins and cashing them.
/// * **Scattershot** puts each one in a different body, and adds more of them.
/// * **Salvo** leaves the volley alone and loads extra darts into the special.
///
/// Every node here is careful not to take a mechanic an element already owns.
/// Pip's seventeen specials between them claim push (Air), slow fields (Dust,
/// Mud), damage over time (Fire, Lava), persistent lines (Poison), healing
/// (Blood, Light), cooldown shaving (Earth), attack-speed windows (Steam,
/// Spirit), taunts (Crystal), ricochets (Lightning), freezing (Ice), meter
/// gain (Plant), kill-splash (Water) and black holes (Dark). A path built on
/// any of those would erase the one element it belonged to — which is why the
/// ricochet path and the attack-speed path this family was first designed with
/// were dropped. Marks, dart counts and target spread were what remained
/// unclaimed.
library;

/// Node ids, so the game never spells one out as a string literal.
class PipNodes {
  const PipNodes._();

  static const needlepointPath = 'pip.assault';
  static const scattershotPath = 'pip.control';
  static const salvoPath = 'pip.salvo';

  static const tightGrouping = 'pip.assault.tight_grouping';
  static const pinCushion = 'pip.assault.pin_cushion';
  static const pluckThePins = 'pip.assault.pluck_the_pins';
  static const thousandCuts = 'pip.assault.thousand_cuts';

  static const wideSpray = 'pip.control.wide_spray';
  static const threeFronts = 'pip.control.three_fronts';
  static const fourthBarrel = 'pip.control.fourth_barrel';
  static const scatterStorm = 'pip.control.scatter_storm';

  static const spareNeedle = 'pip.salvo.spare_needle';
  static const doubleLoad = 'pip.salvo.double_load';
  static const fullQuiver = 'pip.salvo.full_quiver';
  static const perfectSalvo = 'pip.salvo.perfect_salvo';
}

/// Cast tags, set when a volley launches and read when it lands.
class PipCastTags {
  const PipCastTags._();

  /// This volley is the bonus one Thousand Cuts threw; it may not bank Pins.
  static const bonusVolley = 'pip.bonusVolley';

  /// This is a Scatter Storm, not a scheduled attack.
  static const scatterStorm = 'pip.scatterStorm';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class PipTuning {
  const PipTuning._();

  /// The chassis: three darts at 30% physical, 0.12 radians apart.
  static const double baseDartFraction = 0.30;
  static const double baseSpread = 0.12;
  static const int baseDartCount = 3;

  // ── Needlepoint ──
  /// Tight Grouping: 45% closer together, 32% physical each.
  static const double tightSpreadScale = 0.55;
  static const double tightDartFraction = 0.32;

  /// Pin Cushion: a full volley on one body banks a Pin.
  static const int maxPins = 5;
  static const double pinDamagePerStack = 0.03;

  /// How long a body keeps its Pins without being hit again.
  static const double pinLifetime = 6.0;

  /// Pluck the Pins: a full-Pin body loses them for a burst.
  static const double pluckFraction = 0.55;

  /// A boss keeps this many, so the pattern can restart against one.
  static const int pluckBossResidue = 2;

  /// Thousand Cuts: every fourth full volley throws a bonus one.
  static const int thousandCutsCadence = 4;
  static const int thousandCutsDarts = 5;
  static const double thousandCutsFraction = 0.16;
  static const double thousandCutsDelay = 0.2;

  // ── Scattershot ──
  /// Wide Spray: 40% further apart, and each dart seeks its own body.
  static const double wideSpreadScale = 1.40;
  static const double wideHoming = 2.4;

  /// Three Fronts: three darts on three bodies pays every one of them.
  static const double threeFrontsBonus = 0.20;

  /// Fourth Barrel: one more dart on the ordinary volley.
  static const int fourthBarrelDarts = 1;

  /// Scatter Storm: every fifth volley throws a fan.
  static const int scatterStormCadence = 5;
  static const int scatterStormDarts = 8;
  static const double scatterStormFraction = 0.22;

  // ── Salvo ──
  /// Each of the first three nodes loads one more dart into the special.
  static const int salvoDartsPerNode = 1;

  /// Those extra darts are lighter than the ones the ability authored...
  static const double salvoExtraFraction = 0.70;

  /// ...until the capstone, which brings them up to full and adds a fourth.
  static const double salvoPerfectFraction = 1.0;
}

/// One Pip companion's mastery state for the length of a run.
class PipMasteryState {
  // ── Needlepoint ──
  /// Pins per body, keyed by [identityHashCode], with the time each was last
  /// topped up so a body the Pip has left alone loses them.
  final Map<int, int> pins = {};
  final Map<int, double> pinTouched = {};

  /// Full volleys since the last bonus one.
  int volleysSinceBonus = 0;

  // ── Scattershot ──
  /// Scheduled attacks since the last storm.
  int castsSinceStorm = 0;

  /// Handoff between the two halves of launching a volley: the shape pass
  /// decides what this cast is before the cast exists to be tagged.
  bool pendingBonusVolley = false;
  double pendingMasteryDamageFraction = 0;

  int pinsOn(int targetId) => pins[targetId] ?? 0;

  /// Banks a Pin on [targetId], up to the cap. Returns the new total.
  int addPin(int targetId, double now) {
    final next = (pinsOn(targetId) + 1).clamp(0, PipTuning.maxPins);
    pins[targetId] = next;
    pinTouched[targetId] = now;
    return next;
  }

  /// Spends a body's Pins. A boss keeps a residue so the loop can restart
  /// against something that will not die to one detonation.
  int spendPins(int targetId, {required bool isBoss}) {
    final held = pinsOn(targetId);
    if (held <= 0) return 0;
    final keep = isBoss ? PipTuning.pluckBossResidue : 0;
    pins[targetId] = keep;
    return held - keep;
  }

  /// Drops Pins on bodies the Pip has stopped shooting, and keeps the map
  /// from growing for the length of a run.
  void expirePins(double now) {
    if (pinTouched.isEmpty) return;
    pinTouched.removeWhere((id, at) {
      if (now - at < PipTuning.pinLifetime) return false;
      pins.remove(id);
      return true;
    });
  }

  /// Counts a landed volley and reports whether it earns a bonus one.
  bool takeBonusVolleyTurn() {
    volleysSinceBonus++;
    if (volleysSinceBonus < PipTuning.thousandCutsCadence) return false;
    volleysSinceBonus = 0;
    return true;
  }

  /// Counts a scheduled attack and reports whether it earns a storm.
  bool takeStormTurn() {
    castsSinceStorm++;
    if (castsSinceStorm < PipTuning.scatterStormCadence) return false;
    castsSinceStorm = 0;
    return true;
  }

  @override
  String toString() =>
      'PipMasteryState(pinned: ${pins.length}, volleys: $volleysSinceBonus, '
      'casts: $castsSinceStorm)';
}

/// How the equipped path reshapes one volley.
class PipVolleyShape {
  const PipVolleyShape({
    required this.dartCount,
    required this.dartFraction,
    required this.spread,
    required this.homingStrength,
  });

  final int dartCount;

  /// Physical-attack fraction per dart.
  final double dartFraction;

  /// Radians between neighbouring darts.
  final double spread;

  /// Above zero, each dart curves toward its own target.
  final double homingStrength;

  bool get homes => homingStrength > 0;

  static const base = PipVolleyShape(
    dartCount: PipTuning.baseDartCount,
    dartFraction: PipTuning.baseDartFraction,
    spread: PipTuning.baseSpread,
    homingStrength: 0,
  );
}

/// Resolves the shape of the next Pip volley.
PipVolleyShape resolvePipVolleyShape({
  required bool Function(String nodeId) hasNode,
}) {
  var count = PipTuning.baseDartCount;
  var fraction = PipTuning.baseDartFraction;
  var spread = PipTuning.baseSpread;
  var homing = 0.0;

  // The two tier-one nodes are on different paths and cannot both be held.
  if (hasNode(PipNodes.tightGrouping)) {
    fraction = PipTuning.tightDartFraction;
    spread *= PipTuning.tightSpreadScale;
  } else if (hasNode(PipNodes.wideSpray)) {
    spread *= PipTuning.wideSpreadScale;
    homing = PipTuning.wideHoming;
  }

  if (hasNode(PipNodes.fourthBarrel)) {
    count += PipTuning.fourthBarrelDarts;
  }

  return PipVolleyShape(
    dartCount: count,
    dartFraction: fraction,
    spread: spread,
    homingStrength: homing,
  );
}

/// How many extra darts Salvo loads into the special, and what each is worth
/// relative to a dart the ability authored itself.
({int extraDarts, double fraction}) resolvePipSalvo({
  required bool Function(String nodeId) hasNode,
}) {
  var extra = 0;
  if (hasNode(PipNodes.spareNeedle)) extra += PipTuning.salvoDartsPerNode;
  if (hasNode(PipNodes.doubleLoad)) extra += PipTuning.salvoDartsPerNode;
  if (hasNode(PipNodes.fullQuiver)) extra += PipTuning.salvoDartsPerNode;
  final perfect = hasNode(PipNodes.perfectSalvo);
  if (perfect) extra += PipTuning.salvoDartsPerNode;
  return (
    extraDarts: extra,
    fraction: perfect
        ? PipTuning.salvoPerfectFraction
        : PipTuning.salvoExtraFraction,
  );
}

/// The share of a volley's damage that mastery is responsible for, given the
/// multiplier its nodes applied. A path that trades damage away is owed
/// nothing here; its payoff is counted elsewhere.
double pipUpliftFraction(double multiplier) =>
    multiplier <= 1.0 ? 0.0 : (multiplier - 1.0) / multiplier;
