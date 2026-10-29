/// Pip's two mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Pip's chassis is three fast spread darts at 30% physical each — the rapid,
/// precision-volume family. The two paths are two answers to the same
/// question, which is where those darts go:
///
/// * **Scattershot** puts each one in a different body, and adds more of them.
/// * **Salvo** leaves the volley alone and loads extra darts into the special,
///   then changes how they are thrown: a beat later as a second volley, and
///   fanned wide across the crowd.
///
/// A third path, Needlepoint (all three darts into one body, banking Pins),
/// was cut on 2026-10-29: its nodes were percentages on hits that already
/// killed, and it moved a horde wave by a point.
///
/// Every node here is careful not to take a mechanic an element already owns.
/// Pip's seventeen specials between them claim push (Air), slow fields (Dust,
/// Mud), damage over time (Fire, Lava), persistent lines (Poison), healing
/// (Blood, Light), cooldown shaving (Earth), attack-speed windows (Steam,
/// Spirit), taunts (Crystal), ricochets (Lightning), freezing (Ice), meter
/// gain (Plant), kill-splash (Water) and black holes (Dark). A path built on
/// any of those would erase the one element it belonged to — which is why the
/// ricochet path and the attack-speed path this family was first designed with
/// were dropped. Dart counts, target spread and when the darts fly were what
/// remained unclaimed.
library;

/// Node ids, so the game never spells one out as a string literal.
class PipNodes {
  const PipNodes._();

  static const scattershotPath = 'pip.control';
  static const salvoPath = 'pip.salvo';

  static const wideSpray = 'pip.control.wide_spray';
  static const threeFronts = 'pip.control.three_fronts';
  static const fourthBarrel = 'pip.control.fourth_barrel';
  static const scatterStorm = 'pip.control.scatter_storm';

  static const spareNeedle = 'pip.salvo.spare_needle';
  static const secondVolley = 'pip.salvo.second_volley';
  static const wideLoad = 'pip.salvo.wide_load';
  static const perfectSalvo = 'pip.salvo.perfect_salvo';
}

/// Cast tags, set when a volley launches and read when it lands.
class PipCastTags {
  const PipCastTags._();

  /// This is a Scatter Storm, not a scheduled attack.
  static const scatterStorm = 'pip.scatterStorm';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class PipTuning {
  const PipTuning._();

  /// The chassis: three darts, 0.12 radians apart (at 30% physical each,
  /// which the basic-attack factory sets and no node changes).
  static const double baseSpread = 0.12;
  static const int baseDartCount = 3;

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
  /// Each node loads one more dart into the special: one, two, three, four.
  static const int salvoDartsPerNode = 1;

  /// Those extra darts are lighter than the ones the ability authored...
  static const double salvoExtraFraction = 0.60;

  /// ...until the capstone, which adds a fourth and brings them all to this.
  ///
  /// Full strength until the 2026-10-21 mastery sweep (and the extras 70%
  /// before it): four extras as hard as the authored darts, on a special of
  /// about three, carried a Salvo Pip to 40-41% of its party's damage at
  /// Potential 80 and 100 (30-31% without it).
  static const double salvoPerfectFraction = 0.75;

  /// The extras fan out from the authored volley this far apart, so more
  /// darts reads as a wider salvo rather than a stack.
  static const double salvoSpread = baseSpread * 1.15;

  /// Second Volley: the extras are held back and thrown this long after the
  /// special, at what it was thrown at (or the nearest body, if that died).
  static const double secondVolleyDelay = 0.25;

  /// How far from the Pip a second volley looks for a new body when the one
  /// the special was thrown at has died.
  static const double secondVolleyReach = 420;

  /// Volleys one Pip may have waiting at once. A special comes back in
  /// seconds and a volley waits a quarter of one, so one is the norm.
  static const int secondVolleyQueueCap = 4;

  /// Wide Load: the extras leave the volley's flanks instead of its edge,
  /// alternating sides — the first pair this far either side of the aim,
  /// each pair after that [wideLoadStep] further out. Four extras cover
  /// about 82 degrees, against 15 to 25 for most elements' authored volley.
  static const double wideLoadStart = 0.42;
  static const double wideLoadStep = 0.30;

  /// Wide Load: a fanned dart flies straight this long before it starts
  /// seeking, so the fan opens before each dart turns to the body nearest
  /// it, rather than every one curling straight back to the special's
  /// target.
  static const double wideLoadHold = 0.2;

  /// Wide Load for a Dark Pip, whose hole already spits its darts all the
  /// way round and has no arc to widen: the hole spits each dart at a
  /// different body within this reach of it, nearest first, instead of
  /// every dart chasing whichever body is nearest.
  static const double darkFanReach = 320;

  /// Pip Dark throws no special: its ability is the black hole an auto kill
  /// opens. Salvo loads that hole instead, which spits its extra darts at the
  /// bodies round it, at most once per special interval so it pays what
  /// Salvo pays any other Pip. A dart there is the special dart Pip Dark would
  /// have thrown: the authored ordinary multiplier (1.8) after the scaler's
  /// 0.86, of the special's damage.
  static const double darkSalvoDartScale = 1.8 * 0.86;
  static const double darkSalvoDartLife = 1.4;
}

/// One Pip companion's mastery state for the length of a run.
class PipMasteryState {
  // ── Scattershot ──
  /// Scheduled attacks since the last storm.
  int castsSinceStorm = 0;

  /// Three Fronts: the volley whose bodies are being counted, and the first
  /// two it reached with what each took, held until a third is reached.
  /// Fixed fields rather than a list, so the hit path allocates nothing.
  int frontsCastId = 0;
  int heldFronts = 0;
  Object? _front0;
  Object? _front1;
  double _frontDamage0 = 0;
  double _frontDamage1 = 0;

  void startFronts(int castId) {
    frontsCastId = castId;
    clearFronts();
  }

  void holdFront(Object? body, double damage) {
    if (body == null || heldFronts >= 2) return;
    if (heldFronts == 0) {
      _front0 = body;
      _frontDamage0 = damage;
    } else {
      _front1 = body;
      _frontDamage1 = damage;
    }
    heldFronts++;
  }

  Object? frontBody(int i) => i == 0 ? _front0 : _front1;
  double frontDamage(int i) => i == 0 ? _frontDamage0 : _frontDamage1;

  void clearFronts() {
    heldFronts = 0;
    _front0 = null;
    _front1 = null;
  }

  /// Counts a scheduled attack and reports whether it earns a storm.
  bool takeStormTurn() {
    castsSinceStorm++;
    if (castsSinceStorm < PipTuning.scatterStormCadence) return false;
    castsSinceStorm = 0;
    return true;
  }

  @override
  String toString() => 'PipMasteryState(casts: $castsSinceStorm)';
}

/// How the equipped path reshapes one volley.
class PipVolleyShape {
  const PipVolleyShape({
    required this.dartCount,
    required this.spread,
    required this.homingStrength,
  });

  final int dartCount;

  /// Radians between neighbouring darts.
  final double spread;

  /// Above zero, each dart curves toward its own target.
  final double homingStrength;

  bool get homes => homingStrength > 0;

  static const base = PipVolleyShape(
    dartCount: PipTuning.baseDartCount,
    spread: PipTuning.baseSpread,
    homingStrength: 0,
  );
}

/// Resolves the shape of the next Pip volley.
PipVolleyShape resolvePipVolleyShape({
  required bool Function(String nodeId) hasNode,
}) {
  var count = PipTuning.baseDartCount;
  var spread = PipTuning.baseSpread;
  var homing = 0.0;

  if (hasNode(PipNodes.wideSpray)) {
    spread *= PipTuning.wideSpreadScale;
    homing = PipTuning.wideHoming;
  }

  if (hasNode(PipNodes.fourthBarrel)) {
    count += PipTuning.fourthBarrelDarts;
  }

  return PipVolleyShape(
    dartCount: count,
    spread: spread,
    homingStrength: homing,
  );
}

/// What Salvo does to the special: how many extra darts it loads, what each
/// is worth relative to a dart the ability authored itself, and how they are
/// thrown — held back as a second volley, and fanned wide.
({int extraDarts, double fraction, bool secondVolley, bool wide})
resolvePipSalvo({required bool Function(String nodeId) hasNode}) {
  var extra = 0;
  final second = hasNode(PipNodes.secondVolley);
  final wide = hasNode(PipNodes.wideLoad);
  final perfect = hasNode(PipNodes.perfectSalvo);
  if (hasNode(PipNodes.spareNeedle)) extra += PipTuning.salvoDartsPerNode;
  if (second) extra += PipTuning.salvoDartsPerNode;
  if (wide) extra += PipTuning.salvoDartsPerNode;
  if (perfect) extra += PipTuning.salvoDartsPerNode;
  return (
    extraDarts: extra,
    fraction: perfect
        ? PipTuning.salvoPerfectFraction
        : PipTuning.salvoExtraFraction,
    secondVolley: second,
    wide: wide,
  );
}

/// Where the [index]th of [extras] Salvo darts leaves, in radians from the
/// special's aim, on a special that authored [authored] darts of its own.
///
/// Without Wide Load the extras continue the authored fan past its edge at
/// [PipTuning.salvoSpread]. With it they alternate flanks, starting
/// [PipTuning.wideLoadStart] out and stepping [PipTuning.wideLoadStep].
double pipSalvoOffset({
  required int index,
  required int extras,
  required int authored,
  required bool wide,
}) {
  if (wide) {
    final side = index.isEven ? 1.0 : -1.0;
    final step = index ~/ 2;
    return side * (PipTuning.wideLoadStart + step * PipTuning.wideLoadStep);
  }
  final centre = (authored + extras - 1) / 2.0;
  return (authored + index - centre) * PipTuning.salvoSpread;
}
