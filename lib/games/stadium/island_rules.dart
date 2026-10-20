// lib/games/stadium/island_rules.dart
//
// THE ISLAND (the Ruby Cup; the author, 2026-10-12: "for the ruby cup the
// island"): three Alchemons on a floating island of sand, its edge
// crumbling away into the dark, charging one another until one is left
// standing. The last on the island wins; the others place in the order
// they fell.
//
// Everything counts, judged as the race judges a leg (judgeEntrant, under
// the island's condition):
//   · Strength — how hard a charge lands, and how well one stands up to it;
//   · Speed — how fast a charge closes, and how fast it gets back to the
//     middle afterwards;
//   · Intelligence — whom it charges and when (the one nearest the edge,
//     lined up with it, beats the nearest), how often it thinks, and how
//     far from the edge it keeps;
//   · Beauty — the crowd's favour, which steadies it at the brink.
// Every charge runs as far, so Speed brings it there sooner, never further;
// and every blow taken leaves one easier to move, so the bout is won over
// all its blows rather than by whoever is caught last on a sliver of rock.
// Every one of the three fights on its own; the player's taps are charges
// of their own — harder ones — one for each stamina bar.
//
// The cup's first bout is the island plain; the others each turn it (the
// author, 2026-10-18: the bouts were "too repetitive"):
//   · the Molten Heart — the island melts from its middle outward, so the
//     fight is on a ring of sand round a pool of lava. Into the lava is out,
//     as over the edge is, but for those made for the heat (Fire, Lava),
//     who stand it a while, keep by it (as far from the edge as they can
//     be) and can cut across; it is hot rock, too, so they push the harder
//     on it, and the heat wears the rest down as blows do. The rest go
//     round, keeping a step back from the lava.
//   · the Stepping Stones — the island breaks into three stones that drift
//     apart and back together. Off every stone is a fall, but for a charge
//     still in flight; one that ends over a gap drops, unless it is made to
//     glide (Air, Spirit, Lightning, Light, the wing line), when it glides
//     on to the nearest stone in its reach. Where one stands when they part
//     matters: a clever one never leaps what it cannot cross.
//   · the Ice Island — sheet ice: a charge that finds no one slides on, a
//     blow carries one further, and stopping is hard. Those made for the
//     cold (Ice, Water, Crystal) keep their feet on it; the rest slide.
//   · the Black Hole (the author, 2026-10-20) — a black hole opens in the
//     island's middle and draws everyone in towards it, the harder the
//     longer the bout goes on. Into its heart is out, as over the edge is.
//     The stronger and the heavier stand against the pull best, and those
//     made for the dark (Dark, Spirit) can hold a while where it is more
//     than they can walk against. A blow towards the hole is the danger:
//     the fight is holding one's ground, and shoving the others in.
// Each judges its own kind by a condition of its own, as the race does a
// pond or a gap, and the twist's knack — how long one stands the lava, how
// far it glides, how well it keeps its feet on the ice, how long it holds
// against the hole — comes from that kind alone, never from a bigger stat.
//
// Deterministic and stepped at [kIslandTickRate], like the race: the same
// three with the same taps make the same bout — on every phone, too (a bout
// with friends runs on each of theirs): only + − × ÷ and square roots,
// which come out the same to the last bit everywhere; the turns a fighter
// wanders through are worked out here ([islandSin]) rather than by the
// platform's own sine, which need not.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

const int kIslandTickRate = 60;

/// sin([x]) from + − × ÷ alone, so every phone agrees on it to the last
/// bit (a platform's own sine need not): folded into −π/2..π/2, then its
/// series to x¹⁵ (off by less than 1e-9).
double islandSin(double x) {
  const twoPi = 2 * math.pi;
  var a = x - (x / twoPi).roundToDouble() * twoPi;
  if (a > math.pi / 2) a = math.pi - a;
  if (a < -math.pi / 2) a = -math.pi - a;
  final a2 = a * a;
  var term = a, sum = a;
  for (var k = 1; k <= 7; k++) {
    term = -term * a2 / ((2 * k) * (2 * k + 1));
    sum += term;
  }
  return sum;
}

/// cos([x]), as [islandSin].
double islandCos(double x) => islandSin(x + math.pi / 2);

/// The longest a bout runs before the one nearest the middle is given it.
const int kIslandMaxTicks = 90 * kIslandTickRate;

/// What an even, unboosted blow carries (a charge at a judged Speed of 5
/// into one as strong), and how much more each such blow taken leaves the
/// next carrying.
const double kIslandEvenBlow = (72 + 11 * 5) * 0.62, kIslandWearPerBlow = 0.12;

/// How far a charge runs, in island units.
const double kIslandDashReach = (72 + 11 * 5) * 22 / kIslandTickRate;

/// The island's radius as it starts, in island units, and the least it
/// crumbles to.
const double kIslandRadius = 100, kIslandMinRadius = 16;

/// The Molten Heart: when the lava opens (seconds in), how fast it widens
/// (units a second), and the widest it grows.
const double kMoltenOpens = 3, kMoltenRise = 4.0, kMoltenMax = 42;

/// How much the heat wears down one not made for it, a second, with the
/// lava at its widest (as [kIslandWearPerBlow] a blow).
const double kMoltenWear = 0.03;

/// The Stepping Stones: each stone's radius as the bout starts, how long
/// the stones take to part and come back together (seconds), and the
/// widest the gaps between them open.
const double kStoneRadius = 56, kStonesCycle = 12, kStonesGapMax = 34;

/// The Ice Island: how much a step keeps its speed on the ice, a tick (on
/// sand, [IslandBout.grip]), how much of its speed a charge that finds no
/// one keeps there, and how much of the slide a full knack for the cold
/// takes out of both.
const double kIceGrip = 0.986, kIcePullUp = 0.6, kIceFooting = 0.8;

/// The Black Hole: when it opens (seconds in), how fast the empty heart it
/// leaves in the island's middle widens (units a second), and the widest
/// it grows.
const double kHoleOpens = 3, kHoleRise = 2, kHoleMax = 14;

/// How hard the black hole pulls at its heart's edge: as it opens, and how
/// much harder each second after (units a second, a second); how far out
/// the pull carries — [kHoleReach] out from the heart the part of it that
/// falls away is a quarter as strong, twice that a ninth — and the share of
/// it that never falls away, so the whole island leans towards the hole.
const double kHolePull = 60, kHolePullRise = 14, kHoleReach = 40;
const double kHoleFloor = 0.15;

/// How much of what it can walk against the pull takes from one with its
/// grace left (the Black Hole's knack): while it lasts, it can always walk
/// out.
const double kHoleHold = 0.3;

/// What a bout is fought on.
enum IslandKind {
  /// Plain sand, its edge crumbling.
  sand,

  /// The Molten Heart: lava opens in the middle and widens, leaving a ring
  /// of sand to fight on.
  molten,

  /// The Stepping Stones: three stones drifting apart and back together.
  stones,

  /// The Ice Island: sheet ice, its edge crumbling; charges slide on, and
  /// stopping is hard.
  ice,

  /// The Black Hole: a hole opens in the middle and draws everyone in.
  blackHole;

  /// Whether it is one island with nothing in its middle: sand, or ice.
  bool get plain => this == sand || this == ice;
}

/// One bout: its island, and how hard it is judged (1..3).
class IslandBout {
  const IslandBout(this.kind, this.level);

  final IslandKind kind;
  final int level;

  /// How much the twist's own kind counts (its condition's ground): enough
  /// that the right Alchemon beats a bigger stat.
  double get twistGround => switch (kind) {
    IslandKind.sand => 1,
    IslandKind.molten => 2.0,
    IslandKind.stones => 2.5,
    IslandKind.ice => 2.0,
    IslandKind.blackHole => 2.0,
  };

  /// How each trait is judged on it.
  ContestCondition condition(CosmicContestTrait trait) => switch ((
    kind,
    trait,
  )) {
    (IslandKind.molten, CosmicContestTrait.strength) => _inTheHeat.deeper(
      twistGround,
    ),
    // No rain on hot rock: the lava is the bout's one twist.
    (IslandKind.molten, CosmicContestTrait.speed) => contestCondition(trait, 1),
    (IslandKind.stones, CosmicContestTrait.speed) => _overTheGaps.deeper(
      twistGround,
    ),
    // Bulk is no help on a stone: a plain shove.
    (IslandKind.stones, CosmicContestTrait.strength) => contestCondition(
      trait,
      1,
    ),
    // Standing firm on the ice is the twist; skating on it, as ever.
    (IslandKind.ice, CosmicContestTrait.strength) => _footingOnIce.deeper(
      twistGround,
    ),
    (IslandKind.ice, CosmicContestTrait.speed) => _onIce,
    (IslandKind.blackHole, CosmicContestTrait.strength) => _thePull.deeper(
      twistGround,
    ),
    // No wet lane by a black hole: the pull is the bout's one twist.
    (IslandKind.blackHole, CosmicContestTrait.speed) => contestCondition(
      trait,
      1,
    ),
    _ => contestCondition(trait, level),
  };

  /// The twist's knack — standing the lava, gliding a gap, keeping its
  /// feet on the ice, holding against the hole — and the trait it is
  /// judged under. Judged on the fighter's kind alone (its element, its
  /// line, its frame), never its stat; none on plain sand.
  (CosmicContestTrait, ContestCondition)? get knack => switch (kind) {
    IslandKind.sand => null,
    IslandKind.molten => (
      CosmicContestTrait.strength,
      _knackOf(_inTheHeat, sizeMul: 0, ground: twistGround),
    ),
    IslandKind.stones => (
      CosmicContestTrait.speed,
      _knackOf(
        _overTheGaps,
        sizeMul: _overTheGaps.sizeMul,
        ground: twistGround,
      ),
    ),
    IslandKind.ice => (
      CosmicContestTrait.strength,
      _knackOf(_footingOnIce, sizeMul: 0, ground: twistGround),
    ),
    IslandKind.blackHole => (
      CosmicContestTrait.strength,
      _knackOf(_thePull, sizeMul: 0, ground: twistGround),
    ),
  };

  /// Seconds of grace each point of knack gives: how long one stands in
  /// the lava, stays up over a gap, or holds where the hole's pull is more
  /// than it can walk against. None on the ice, where the knack is the
  /// footing itself ([IslandSim.footing]).
  double get gracePerKnack => switch (kind) {
    IslandKind.sand => 0,
    IslandKind.molten => 1.6,
    IslandKind.stones => 0.75,
    IslandKind.ice => 0,
    IslandKind.blackHole => 1.8,
  };

  /// How much a step or a blow keeps its speed, per tick (on the ice, for
  /// one with no knack for it).
  double get grip => kind == IslandKind.ice ? kIceGrip : 0.93;

  /// How much of its speed a charge that finds no one keeps (on the ice,
  /// it slides on).
  double get pullUp => kind == IslandKind.ice ? kIcePullUp : 0.2;

  /// How fast the edge crumbles, in units a second once it starts.
  double get crumble => switch (kind) {
    IslandKind.sand => 2.4,
    IslandKind.molten => 0.8,
    IslandKind.stones => 1.2,
    IslandKind.ice => 2.0,
    IslandKind.blackHole => 0.6,
  };

  /// The least the island — on the Molten Heart and the Black Hole its
  /// outer edge, on the Stepping Stones each stone — crumbles to.
  double get minRadius => switch (kind) {
    IslandKind.sand || IslandKind.ice => kIslandMinRadius,
    IslandKind.molten => 76,
    IslandKind.stones => 22,
    IslandKind.blackHole => 82,
  };
}

/// The Molten Heart's condition: hot rock, and lava in the middle.
const _inTheHeat = ContestCondition(
  title: 'HEAT',
  line: 'Lava in the middle.',
  elementAdd: {
    'Fire': 0.5,
    'Lava': 0.5,
    'Earth': 0.1,
    'Ice': -0.4,
    'Plant': -0.3,
    'Water': -0.2,
  },
  familyAdd: {'mane': 0.15},
  good: 'stands the heat',
  bad: 'wilts in the heat',
);

/// The Stepping Stones' condition: the race's gap (race_rules.dart), with
/// every one of the gliders the stones are for named.
const _overTheGaps = ContestCondition(
  title: 'GAP',
  line: 'Gaps to leap between the stones.',
  elementAdd: {
    'Air': 0.5,
    'Spirit': 0.4,
    'Lightning': 0.35,
    'Light': 0.35,
    'Earth': -0.2,
    'Mud': -0.2,
    'Lava': -0.15,
    'Crystal': -0.15,
  },
  familyAdd: {'wing': 0.55, 'let': 0.1, 'horn': -0.2},
  good: 'glides across',
  bad: 'falls short',
  strangers: -0.25,
  sizeMul: 1.2,
);

/// The Ice Island's pace: sheet ice, fast for those who skate it.
const _onIce = ContestCondition(
  title: 'ICE',
  line: 'Sheet ice: fast and hard to stop.',
  elementAdd: {
    'Ice': 0.5,
    'Water': 0.3,
    'Crystal': 0.1,
    'Air': 0.15,
    'Fire': -0.25,
    'Lava': -0.25,
  },
  familyAdd: {'let': 0.2, 'horn': -0.15},
  good: 'skates',
  bad: 'slips',
);

/// The Ice Island's twist: keeping one's feet on it — the knack, and the
/// shove (a charge from firm feet lands harder, and one standing firm is
/// harder to move).
const _footingOnIce = ContestCondition(
  title: 'FOOTING',
  line: 'Standing firm on ice.',
  elementAdd: {
    'Ice': 0.5,
    'Crystal': 0.4,
    'Water': 0.35,
    'Earth': 0.1,
    'Fire': -0.25,
    'Lava': -0.3,
  },
  familyAdd: {'horn': 0.15, 'wing': -0.2},
  good: 'stands firm',
  bad: 'skids',
  strangers: -0.2,
);

/// The Black Hole's condition: the pull, and those made for the dark who
/// hold against it.
const _thePull = ContestCondition(
  title: 'PULL',
  line: 'A black hole in the middle.',
  elementAdd: {
    'Dark': 0.5,
    'Spirit': 0.45,
    'Air': -0.3,
    'Light': -0.25,
    'Dust': -0.2,
  },
  good: 'holds against the pull',
  bad: 'is drawn in',
  strangers: -0.3,
);

/// [c]'s own extras alone (no trait weights, no purity), as deep as a
/// twist's ground: what a fighter brings to the twist by its kind.
ContestCondition _knackOf(
  ContestCondition c, {
  required double sizeMul,
  required double ground,
}) => ContestCondition(
  title: c.title,
  line: c.line,
  elementAdd: c.elementAdd,
  familyAdd: c.familyAdd,
  good: c.good,
  bad: c.bad,
  strangers: c.strangers,
  elementMul: 0,
  familyMul: 0,
  purityMul: 0,
  sizeMul: sizeMul,
  ground: ground,
);

enum FighterPhase { stand, windup, dash, reel, fall, out }

/// One of the three as the bout goes.
class IslandFighter {
  IslandFighter(this.x, this.y, this.charges);

  double x, y, vx = 0, vy = 0;
  FighterPhase phase = FighterPhase.stand;

  /// The tick the current phase began.
  int phaseFrom = 0;

  /// Whom it is charging, and the way it goes.
  int target = -1;
  double dx = 0, dy = 0;

  /// Whether this charge is one of its stamina's (harder).
  bool boosted = false;

  /// How knocked about it is: every blow it takes leaves it carried that
  /// much further by the next one.
  double worn = 0;

  /// Stamina charges left; when it next looks for someone to charge.
  int charges;
  int nextThink = 0;

  /// How many times it has thought: what its pauses are drawn from.
  int thinks = 0;

  /// Seconds of its grace used up — in the lava, over a gap, or caught in
  /// the hole's pull — and coming back as fast on firm ground.
  double burn = 0;

  /// Whom it is making its way round the ring to (the Molten Heart, the
  /// Black Hole), with no straight way to them that it can stand; -1 for
  /// none.
  int stalk = -1;

  /// Whether it went into the lava, or the black hole, rather than over
  /// the edge.
  bool sank = false;

  /// The tick it went over the edge, and was gone.
  int? fellAt, outAt;

  /// Ticks a charge of its began on, and those that landed on someone.
  final List<int> chargesAt = [];
  final List<int> hitsAt = [];

  bool get standing => outAt == null && fellAt == null;
}

/// A bout in progress. Step it at [kIslandTickRate]; tap charges in as
/// they come (a late one: [IslandSim.replay]).
class IslandSim {
  IslandSim(this.bout, this.fighters)
    : assert(fighters.length >= 2),
      push = [
        for (final f in fighters) _score(f, bout, CosmicContestTrait.strength),
      ],
      pace = [
        for (final f in fighters) _score(f, bout, CosmicContestTrait.speed),
      ],
      wits = [
        for (final f in fighters)
          _score(f, bout, CosmicContestTrait.intelligence),
      ],
      poise = [
        for (final f in fighters) _score(f, bout, CosmicContestTrait.beauty),
      ],
      knack = [for (final f in fighters) _knack(f, bout)],
      states = [] {
    final n = fighters.length;
    for (var i = 0; i < n; i++) {
      // The player at the front (the bottom of the screen), the rest
      // round the island from there.
      final a = math.pi / 2 + startTurn(bout.kind, i, n);
      states.add(
        IslandFighter(
          islandCos(a) * kIslandRadius * 0.55,
          islandSin(a) * kIslandRadius * 0.55,
          fighters[i].boosts,
        )..nextThink = 50 + i * 23,
      );
    }
    grace = [for (final k in knack) k * bout.gracePerKnack];
    _wilts = [for (final k in knack) 1 - k.clamp(0.0, 1.0)];
    footing = [
      for (final k in knack)
        bout.kind == IslandKind.ice ? k.clamp(0.0, 1.0).toDouble() : 0.0,
    ];
    _grip = [
      for (final f in footing) bout.grip + (0.93 - bout.grip) * kIceFooting * f,
    ];
    _pullUp = [
      for (final f in footing)
        bout.pullUp + (0.2 - bout.pullUp) * kIceFooting * f,
    ];
    _heft = [
      for (var i = 0; i < n; i++) math.sqrt(mass(i)) * (0.5 + 0.1 * push[i]),
    ];
    _arena(0);
  }

  factory IslandSim.replay(
    IslandBout bout,
    List<Racer> fighters,
    Map<int, List<int>> taps,
    int tick,
  ) {
    final sim = IslandSim(bout, fighters);
    for (final e in taps.entries) {
      for (final t in e.value) {
        sim.tap(e.key, t);
      }
    }
    while (sim.tick < tick && !sim.over) {
      sim.step();
    }
    return sim;
  }

  factory IslandSim.run(
    IslandBout bout,
    List<Racer> fighters, [
    Map<int, List<int>> taps = const {},
  ]) => IslandSim.replay(bout, fighters, taps, kIslandMaxTicks);

  /// Where fighter [i] of [n] starts, as a turn round the island from the
  /// front: evenly round it; on the Stepping Stones, each on a stone.
  static double startTurn(IslandKind kind, int i, int n) =>
      i * 2 * math.pi / (kind == IslandKind.stones ? 3 : n);

  final IslandBout bout;

  /// Who fights: the race's [Racer] (what the judges see, its ratings, its
  /// stamina); a computer one is `canny` if it has autoBoostLegs.
  final List<Racer> fighters;

  /// Each one's judged Strength, Speed, Intelligence and Beauty here.
  final List<double> push, pace, wits, poise;

  /// Each one's knack for the bout's twist (none on plain sand), and the
  /// seconds of grace it gives — in the lava, over a gap, or caught in the
  /// hole's pull — before it is gone.
  final List<double> knack;
  late final List<double> grace;

  /// How much the heat wears each one down (the Molten Heart): fully for
  /// one with no knack for it, not at all for one made for it.
  late final List<double> _wilts;

  /// How well each keeps its feet on the ice, 0..1 (the Ice Island; none
  /// elsewhere): one made for the cold takes that much of the slide out
  /// of its steps, the blows it takes and the charges it misses.
  late final List<double> footing;

  /// How much each one's speed keeps a tick ([IslandBout.grip], less its
  /// footing), and how much a charge of its that finds no one keeps.
  late final List<double> _grip, _pullUp;

  /// How well each stands against the black hole's pull: its frame, and
  /// its strength. The pull on it is divided by this.
  late final List<double> _heft;
  final List<IslandFighter> states;
  int tick = 0;

  /// Charges tapped, waiting for their tick, and every one given.
  final Map<int, List<int>> _pending = {};
  final Map<int, List<int>> taps = {};

  static double _score(Racer r, IslandBout bout, CosmicContestTrait t) =>
      judgeEntrant(
        t,
        bout.level,
        r.entrant.withRating(r.ratings[t] ?? 1),
        condition: bout.condition(t),
      ).score;

  static double _knack(Racer r, IslandBout bout) {
    final k = bout.knack;
    if (k == null) return 0;
    return judgeEntrant(
      k.$1,
      bout.level,
      r.entrant.withRating(0),
      condition: k.$2,
    ).score;
  }

  // ── the arena ──

  /// The island's radius now: whole for five seconds, then crumbling.
  double get radius => radiusAt(tick);

  /// The island's radius at tick [t] — on the Molten Heart its outer edge,
  /// on the Stepping Stones each stone's.
  double radiusAt(int t) {
    final since = (t - 5 * kIslandTickRate) / kIslandTickRate;
    final whole = bout.kind == IslandKind.stones ? kStoneRadius : kIslandRadius;
    if (since <= 0) return whole;
    return math.max(bout.minRadius, whole - since * bout.crumble);
  }

  /// The lava's radius at tick [t] (the Molten Heart; none elsewhere): none
  /// at first, then widening until the ring round it is narrow.
  double lavaAt(int t) {
    if (bout.kind != IslandKind.molten) return 0;
    final since = (t - kMoltenOpens * kIslandTickRate) / kIslandTickRate;
    if (since <= 0) return 0;
    return math.min(kMoltenRise * since, kMoltenMax);
  }

  /// The black hole's empty heart at tick [t] (the Black Hole; none
  /// elsewhere): none at first, then widening.
  double holeAt(int t) {
    if (bout.kind != IslandKind.blackHole) return 0;
    final since = (t - kHoleOpens * kIslandTickRate) / kIslandTickRate;
    if (since <= 0) return 0;
    return math.min(kHoleRise * since, kHoleMax);
  }

  /// How hard the black hole pulls at its heart's edge at tick [t] (units
  /// a second, a second; none elsewhere): coming on over its first two
  /// seconds, and harder every second after, so in the end nobody holds.
  double holePullAt(int t) {
    if (bout.kind != IslandKind.blackHole) return 0;
    final since = (t - kHoleOpens * kIslandTickRate) / kIslandTickRate;
    if (since <= 0) return 0;
    return kHolePull * math.min(1.0, since / 2) + kHolePullRise * since;
  }

  /// The way out to each stone's middle from the island's: the first at
  /// the front, the others round from it.
  static const List<double> stoneDirX = [
    0,
    -0.8660254037844386,
    0.8660254037844386,
  ];
  static const List<double> stoneDirY = [1, -0.5, -0.5];

  /// How far apart neighbouring stones' edges are at tick [t] (less than
  /// none while they overlap): together for five seconds, then drifting
  /// apart and back every [kStonesCycle] seconds, easing at either end.
  double stoneGapAt(int t) {
    final r = radiusAt(t);
    final lo = -0.42 * r;
    final since = (t - 5 * kIslandTickRate) / kIslandTickRate;
    if (since <= 0) return lo;
    final e = 0.5 - 0.5 * islandCos(since * 2 * math.pi / kStonesCycle);
    return lo + (kStonesGapMax - lo) * e;
  }

  /// How far each stone's middle is from the island's at tick [t].
  double stoneDistAt(int t) => (2 * radiusAt(t) + stoneGapAt(t)) / _sqrt3;
  static const double _sqrt3 = 1.7320508075688772;

  // The arena this tick, set as each step begins: the island's radius
  // (each stone's), the lava's, the black hole's heart and its pull, each
  // stone's middle, and how far each stone drifts by the next tick.
  double _r = kIslandRadius, _lava = 0, _hole = 0, _pull = 0;
  final List<double> _sx = [0, 0, 0], _sy = [0, 0, 0];
  final List<double> _mx = [0, 0, 0], _my = [0, 0, 0];

  void _arena(int t) {
    _r = radiusAt(t);
    switch (bout.kind) {
      case IslandKind.sand:
      case IslandKind.ice:
        break;
      case IslandKind.blackHole:
        _hole = holeAt(t);
        _pull = holePullAt(t);
      case IslandKind.molten:
        _lava = lavaAt(t);
      case IslandKind.stones:
        final d0 = stoneDistAt(t), d1 = stoneDistAt(t + 1);
        for (var k = 0; k < 3; k++) {
          _sx[k] = stoneDirX[k] * d0;
          _sy[k] = stoneDirY[k] * d0;
          _mx[k] = stoneDirX[k] * (d1 - d0);
          _my[k] = stoneDirY[k] * (d1 - d0);
        }
    }
  }

  /// Whether (x, y) is on a stone, [slack] past its edge allowed.
  bool _onStone(double x, double y, double slack) {
    final rr = (_r + slack) * (_r + slack);
    for (var k = 0; k < 3; k++) {
      final dx = x - _sx[k], dy = y - _sy[k];
      if (dx * dx + dy * dy <= rr) return true;
    }
    return false;
  }

  /// How far (x, y) is past the nearest stone's edge (less than none on
  /// one), and which stone that is.
  (double, int) _nearestStone(double x, double y) {
    var best = 1e9;
    var at = 0;
    for (var k = 0; k < 3; k++) {
      final dx = x - _sx[k], dy = y - _sy[k];
      final d = math.sqrt(dx * dx + dy * dy) - _r;
      if (d < best) {
        best = d;
        at = k;
      }
    }
    return (best, at);
  }

  /// The stone fighter [i] stands on (the one it is deepest in), or -1
  /// over a gap.
  int _stoneUnder(int i) {
    final s = states[i];
    final (past, k) = _nearestStone(s.x, s.y);
    return past <= size(i) * 0.3 ? k : -1;
  }

  /// Whether fighter [i] has firm ground under it: not in the lava, not
  /// over a gap, not caught in the hole's pull.
  bool _footed(int i) {
    final s = states[i];
    return switch (bout.kind) {
      IslandKind.sand || IslandKind.ice => true,
      IslandKind.molten =>
        math.sqrt(s.x * s.x + s.y * s.y) >= _lava - size(i) * 0.3,
      IslandKind.stones => _onStone(s.x, s.y, size(i) * 0.3),
      IslandKind.blackHole => !_caught(i),
    };
  }

  /// Whether fighter [i] is in the lava, over a gap, or caught in the
  /// hole's pull (as last stepped).
  bool adrift(int i) => states[i].standing && !_footed(i);

  /// How hard the black hole pulls fighter [i] where it stands (units a
  /// second, a second), as the arena was last set: hardest at its heart's
  /// edge and falling away from it, but never below [kHoleFloor] of that;
  /// the less, the heavier and the stronger it is.
  double pullOn(int i) {
    if (_pull <= 0) return 0;
    final s = states[i];
    final d = math.max(0.0, math.sqrt(s.x * s.x + s.y * s.y) - _hole);
    final q = 1 + d / kHoleReach;
    return _pull * (kHoleFloor + (1 - kHoleFloor) / (q * q)) / _heft[i];
  }

  /// How hard fighter [i]'s own steps can turn it, a second: what it can
  /// walk against.
  double _stride(int i) => 46 + 12 * pace[i];

  /// How much of what fighter [i] can walk against the black hole's pull
  /// takes where it stands (past 1, it is drawn in).
  double pullShare(int i) => _pull <= 0 ? 0 : pullOn(i) / _stride(i);

  /// Whether the black hole pulls fighter [i] harder than it can walk
  /// against.
  bool _caught(int i) => pullOn(i) > _stride(i);

  /// How far out from the middle the black hole's pull is more than
  /// fighter [i] can walk against (the heart's own edge, where it is not).
  double _caughtWithin(int i) => _pullReaches(i, 1);

  /// The black hole's heart as it will be two seconds on: what a fighter
  /// keeps clear of, before it has even opened.
  double get _heartSoon => holeAt(tick + 2 * kIslandTickRate);

  /// How far out from the middle the black hole pulls fighter [i] as hard
  /// as [share] of what it can walk against: the heart's edge, where it
  /// nowhere does; the island's, where it does everywhere.
  double _pullReaches(int i, double share) {
    if (_pull <= 0) return 0;
    final under = _heft[i] * _stride(i) * share / _pull;
    if (under >= 1) return _hole;
    if (under <= kHoleFloor) return _r;
    final q = math.sqrt((1 - kHoleFloor) / (under - kHoleFloor));
    return math.min(_r, _hole + kHoleReach * (q - 1));
  }

  /// How much of fighter [i]'s grace is spent, 0..1.
  double spent(int i) =>
      grace[i] <= 0 ? 0 : (states[i].burn / grace[i]).clamp(0.0, 1.0);

  /// From (px, py) inside the circle at (cx, cy) of radius [rho], how far
  /// along (ux, uy) its edge is; none from outside it.
  static double _exit(
    double px,
    double py,
    double ux,
    double uy,
    double cx,
    double cy,
    double rho,
  ) {
    final qx = px - cx, qy = py - cy;
    final b = qx * ux + qy * uy;
    final c = qx * qx + qy * qy - rho * rho;
    if (c >= 0) return 0;
    return -b + math.sqrt(b * b - c);
  }

  /// From (px, py), how far along (ux, uy) the circle at the middle of
  /// radius [rho] begins (none from inside it; far off if never).
  static double _entry(double px, double py, double ux, double uy, double rho) {
    if (rho <= 0) return 1e9;
    final b = px * ux + py * uy;
    final c = px * px + py * py - rho * rho;
    if (c <= 0) return 0;
    final disc = b * b - c;
    if (disc < 0 || b >= 0) return 1e9;
    return -b - math.sqrt(disc);
  }

  /// How much of the [len] from (px, py) along (ux, uy) lies inside the
  /// circle at the middle of radius [rho].
  static double _chord(
    double px,
    double py,
    double ux,
    double uy,
    double len,
    double rho,
  ) {
    if (rho <= 0) return 0;
    final b = px * ux + py * uy;
    final c = px * px + py * py - rho * rho;
    final disc = b * b - c;
    if (disc <= 0) return 0;
    final q = math.sqrt(disc);
    final a = math.max(0.0, -b - q), z = math.min(len, -b + q);
    return z > a ? z - a : 0;
  }

  /// From (x, y), how far along (ux, uy) it is until off every stone.
  double _offStones(double x, double y, double ux, double uy) {
    var s = 0.0;
    for (var pass = 0; pass < 3; pass++) {
      final px = x + ux * s, py = y + uy * s;
      var out = 0.0;
      for (var k = 0; k < 3; k++) {
        out = math.max(out, _exit(px, py, ux, uy, _sx[k], _sy[k], _r));
      }
      if (out <= 0) break;
      s += out + 1e-3;
    }
    return s;
  }

  /// How far a second of grace carries one back (to the sand, or a stone),
  /// and how fast one walks (its steps against the ground's grip).
  static const double _graceRoom = 40, _walk = 28;

  /// How near a blow along (ux, uy) would put fighter [j] out, 0..1: how
  /// far it is that way to ground it cannot stand on (the edge, the lava,
  /// the end of its stone, where the hole's pull is more than it can walk
  /// against), past what its grace would bring it back from.
  double _danger(int j, double ux, double uy) {
    final o = states[j];
    final room = switch (bout.kind) {
      IslandKind.sand || IslandKind.ice => _exit(o.x, o.y, ux, uy, 0, 0, _r),
      IslandKind.molten => math.min(
        _exit(o.x, o.y, ux, uy, 0, 0, _r),
        _entry(o.x, o.y, ux, uy, _lava) + grace[j] * _graceRoom,
      ),
      IslandKind.stones => _offStones(o.x, o.y, ux, uy) + grace[j] * _graceRoom,
      IslandKind.blackHole => math.min(
        _exit(o.x, o.y, ux, uy, 0, 0, _r),
        _entry(o.x, o.y, ux, uy, _caughtWithin(j)) + grace[j] * _holdRoom,
      ),
    };
    return 1 - (room / 70).clamp(0.0, 1.0);
  }

  /// How far a second of grace carries one back out of the hole's pull:
  /// slower than out of the lava, against what is left of the pull.
  static const double _holdRoom = 14;

  /// Whether fighter [i] can charge [j] and come down on ground it can
  /// stand: never through more lava than it stands, nor short over a gap,
  /// nor across the black hole's heart or into its pull past its grace.
  /// A dim one misjudges it a little, for the better.
  bool _reachable(int i, int j) {
    if (bout.kind.plain) return true;
    final me = states[i], o = states[j];
    final ox = o.x - me.x, oy = o.y - me.y;
    final d = math.sqrt(ox * ox + oy * oy);
    if (d < 1e-6) return true;
    final ux = ox / d, uy = oy / d;
    final touch = size(i) + size(j);
    final run = d <= kIslandDashReach + touch
        ? math.max(0.0, d - touch)
        : kIslandDashReach;
    final ex = me.x + ux * run, ey = me.y + uy * run;
    final care = 1 - ((wits[i] - 2) / 3).clamp(0.0, 1.0);
    switch (bout.kind) {
      case IslandKind.sand:
      case IslandKind.ice:
        return true;
      case IslandKind.blackHole:
        final er = math.sqrt(ex * ex + ey * ey);
        if (er > _r - size(i) * 0.5 + 6 * care) return false;
        // The nearest the charge comes to the heart, as it will be in a
        // moment (before it opens, too): a charge across it is a charge
        // into it.
        final heart = _heartSoon;
        final along = (-(me.x * ux + me.y * uy)).clamp(0.0, run);
        final nx = me.x + ux * along, ny = me.y + uy * along;
        if (heart > 0 &&
            math.sqrt(nx * nx + ny * ny) <
                heart + size(i) * 0.5 + 4 - 6 * care) {
          return false;
        }
        // Where it comes down, the pull no more than it can walk against
        // — or, for one made for the dark, no deeper than its grace
        // brings it back from.
        return er >=
            math.max(heart + size(i), _caughtWithin(i) + size(i) * 0.5) -
                (grace[i] - me.burn) * _holdRoom -
                6 * care;
      case IslandKind.molten:
        if (math.sqrt(ex * ex + ey * ey) > _r - size(i) * 0.5 + 6 * care) {
          return false;
        }
        // The way through the lava, and — if the charge stops in it — the
        // walk back out (one walks about [_walk] units a second).
        final er = math.sqrt(ex * ex + ey * ey);
        final hot =
            _chord(me.x, me.y, ux, uy, run, _lava) / (72 + 11 * pace[i]) +
            math.max(0.0, _lava + size(i) - er) / _walk;
        return hot <= grace[i] - me.burn + 0.15 * care;
      case IslandKind.stones:
        if (_onStone(ex, ey, size(i) * 0.3)) return true;
        return _nearestStone(ex, ey).$1 <=
            (grace[i] - me.burn) * _graceRoom + 12 * care;
    }
  }

  /// Its size on the island (a big frame is a big target, and hard to
  /// move).
  double size(int i) => 12 * fighters[i].entrant.scale.clamp(0.7, 1.5);
  double mass(int i) {
    final s = fighters[i].entrant.scale.clamp(0.7, 1.5);
    return s * s;
  }

  bool get over =>
      tick >= kIslandMaxTicks ||
      states.where((s) => s.outAt == null).length <= 1;

  /// Fighter [i] taps a charge at [atTick] (now if null).
  void tap(int i, [int? atTick]) {
    final at = atTick ?? tick;
    (taps[i] ??= []).add(at);
    if (at >= tick) (_pending[i] ??= []).add(at);
  }

  /// Whether fighter [i] has a charge tapped and waiting for its tick.
  bool hasPending(int i) => _pending[i]?.isNotEmpty ?? false;

  /// Whether fighter [i] could charge now.
  bool canCharge(int i) {
    final s = states[i];
    return s.charges > 0 &&
        s.standing &&
        (s.phase == FighterPhase.stand || s.phase == FighterPhase.reel) &&
        _alive(i).isNotEmpty;
  }

  List<int> _alive(int except) => [
    for (var j = 0; j < states.length; j++)
      if (j != except && states[j].standing) j,
  ];

  /// The one [i] would do best to charge: the one nearest going out and
  /// lined up with it, for a clever one; the nearest, for one that is not.
  /// On the twists, one it can reach before one it cannot.
  int _pick(int i) {
    if (bout.kind.plain) return _pickOnSand(i);
    final me = states[i];
    final clever = ((wits[i] - 2) / 3).clamp(0.0, 1.0);
    var best = -1;
    var bestScore = -1e9;
    for (final j in _alive(i)) {
      final o = states[j];
      final ox = o.x - me.x, oy = o.y - me.y;
      final d = math.sqrt(ox * ox + oy * oy);
      final near = 1 - (d / (2 * kIslandRadius)).clamp(0.0, 1.0);
      final danger = d < 1e-6 ? 0.0 : _danger(j, ox / d, oy / d);
      var score = clever * danger + (1 - clever) * near;
      if (!_reachable(i, j)) score -= 2;
      if (score > bestScore) {
        bestScore = score;
        best = j;
      }
    }
    return best;
  }

  /// On plain sand: the one nearest the edge and lined up with it.
  int _pickOnSand(int i) {
    final me = states[i];
    final clever = ((wits[i] - 2) / 3).clamp(0.0, 1.0);
    var best = -1;
    var bestScore = -1e9;
    for (final j in _alive(i)) {
      final o = states[j];
      final ox = o.x - me.x, oy = o.y - me.y;
      final d = math.sqrt(ox * ox + oy * oy);
      final r = math.sqrt(o.x * o.x + o.y * o.y);
      final edge = r / radius;
      // Charging along me → them pushes them outward when that way points
      // away from the middle.
      final align = d < 1e-6 || r < 1e-6
          ? 0.0
          : (ox * o.x + oy * o.y) / (d * r);
      final near = 1 - (d / (2 * kIslandRadius)).clamp(0.0, 1.0);
      final score = clever * (edge + 0.8 * align) + (1 - clever) * near;
      if (score > bestScore) {
        bestScore = score;
        best = j;
      }
    }
    return best;
  }

  void _charge(int i, {required bool boosted, int? target}) {
    final s = states[i];
    final t = target ?? _pick(i);
    if (t < 0) return;
    if (boosted) s.charges -= 1;
    s
      ..phase = FighterPhase.windup
      ..phaseFrom = tick
      ..target = t
      ..boosted = boosted
      ..stalk = -1;
    s.chargesAt.add(tick);
  }

  /// How long a charge winds up.
  static const int _windup = 18;
  static const int windupTicks = _windup;

  /// How long fighter [i]'s charge runs: as far for every one of them, so a
  /// quick one gets there sooner rather than further.
  int dashTicks(int i) =>
      (kIslandDashReach * kIslandTickRate / _dashSpeed(i)).round();

  void step() {
    if (over) return;
    _arena(tick);
    final r = radius;
    final n = states.length;
    for (var i = 0; i < n; i++) {
      _think(i);
    }
    for (var i = 0; i < n; i++) {
      _move(i, r);
    }
    _collide();
    for (var i = 0; i < n; i++) {
      _ground(i, r);
    }
    tick++;
  }

  /// 0..1 from two whole numbers, the same on every machine — the web's
  /// too, where whole numbers are doubles: nothing here passes 2⁵³.
  static double _hash(int a, int b) {
    var x = (a * 7919 + b * 104729 + 12345) % 2147483647;
    x = (x * 48271) % 2147483647;
    x = (x * 48271) % 2147483647;
    return (x % 65536) / 65535;
  }

  void _think(int i) {
    final s = states[i];
    if (!s.standing) return;
    // Taps due now.
    final due = _pending[i];
    if (due != null && due.isNotEmpty) {
      due.removeWhere((t) {
        if (t > tick) return false;
        if (t == tick && canCharge(i)) _charge(i, boosted: true);
        return true;
      });
    }
    if (s.phase != FighterPhase.stand || tick < s.nextThink) return;
    final r = fighters[i];
    if (bout.kind.plain) {
      // A computer one spends its stamina on a charge that can finish
      // someone (canny), or on its first ones (green).
      var boosted = false;
      if (!r.isPlayer && s.charges > 0) {
        final t = _pick(i);
        if (t >= 0) {
          final o = states[t];
          final edge = math.sqrt(o.x * o.x + o.y * o.y) / radius;
          boosted = r.autoBoostLegs.isNotEmpty ? edge > 0.62 : true;
        }
      }
      _charge(i, boosted: boosted);
    } else {
      // Its feet first: one in the lava or over a gap makes for firm
      // ground before it charges anyone.
      if (!_footed(i)) {
        s.nextThink = tick + 6;
        return;
      }
      final t = _pick(i);
      if (t < 0) return;
      if (!_reachable(i, t)) {
        // No way to anyone it can stand: round the ring towards them, or
        // (on a stone) wait for the stones to come together.
        s
          ..stalk =
              bout.kind == IslandKind.molten ||
                  bout.kind == IslandKind.blackHole
              ? t
              : -1
          ..nextThink = tick + 12;
        return;
      }
      var boosted = false;
      if (!r.isPlayer && s.charges > 0) {
        final o = states[t];
        final ox = o.x - s.x, oy = o.y - s.y;
        final d = math.sqrt(ox * ox + oy * oy);
        final danger = d < 1e-6 ? 0.0 : _danger(t, ox / d, oy / d);
        boosted = r.autoBoostLegs.isNotEmpty ? danger > 0.55 : true;
      }
      _charge(i, boosted: boosted, target: t);
    }
    // The clever think again sooner.
    s.nextThink =
        tick +
        (62 + (6 - wits[i]).clamp(0.0, 6.0) * 15 + _hash(s.thinks++, i) * 40)
            .round();
  }

  /// Where fighter [i] would rather stand: well inside the edge, and away
  /// from the others ((ax, ay), [al] long), so there is room to charge — a
  /// clever one keeps nearer the middle; one that is not wanders. On the
  /// Molten Heart, the middle of the ring; on the Black Hole, the middle of
  /// the ring between the edge and where the pull would have it; on the
  /// Stepping Stones, the middle of its stone.
  (double, double) _home(
    int i,
    double clever,
    double ax,
    double ay,
    double al,
    double r,
  ) {
    final s = states[i];
    final a = tick * 0.012 + i * 2.1;
    switch (bout.kind) {
      case IslandKind.sand:
      case IslandKind.ice:
        final keep = (0.22 + 0.18 * (1 - clever)) * r;
        final wander = (1 - clever) * 0.18 * r;
        return (
          (al < 1e-9 ? 0 : ax / al * keep) + islandCos(a) * wander,
          (al < 1e-9 ? 0 : ay / al * keep) + islandSin(a) * wander,
        );
      case IslandKind.molten:
      case IslandKind.blackHole:
        final molten = bout.kind == IslandKind.molten;
        final rr = math.sqrt(s.x * s.x + s.y * s.y);
        var hx = rr > 1e-6 ? s.x / rr : 0.0, hy = rr > 1e-6 ? s.y / rr : 1.0;
        // What it cannot stand inside: the lava, or the pull.
        final inner = molten ? _lava : math.max(_heartSoon, _caughtWithin(i));
        if (rr < inner) {
          // In the lava, or caught in the pull: out, the nearest way (but
          // never over the edge).
          final out = math.min(inner + size(i) + 4, r - size(i));
          return (hx * out, hy * out);
        }
        final stalk = s.stalk;
        if (stalk >= 0 && states[stalk].standing) {
          // Round the ring towards the one it wants.
          final o = states[stalk];
          final orr = math.sqrt(o.x * o.x + o.y * o.y);
          if (orr > 1e-6) {
            hx += (o.x / orr - hx) * 0.6;
            hy += (o.y / orr - hy) * 0.6;
          }
        } else if (al > 1e-9) {
          hx += ax / al * 0.5;
          hy += ay / al * 0.5;
        }
        final hl = math.sqrt(hx * hx + hy * hy);
        if (!molten) {
          // Out where the pull takes no more than half its steps, and on
          // from there: a clever one, which knows the pull will grow,
          // further (as near the middle as on sand while there is none);
          // a dim one nearer, and wandering.
          // Never out past the edge, though the pull be everywhere.
          final edge = r - size(i);
          final from = math.min(edge, inner + size(i) + 4);
          final room = math.max(0.0, edge - from);
          final at =
              from +
              (0.3 + 0.2 * clever) * room +
              islandSin(a) * (1 - clever) * 0.15 * room;
          return hl < 1e-9 ? (0.0, at) : (hx / hl * at, hy / hl * at);
        }
        // How far out on the ring: one made for the heat hugs the lava,
        // as far from the edge as it can be; one that is not keeps a
        // step back from the lava as well.
        final hot = knack[i].clamp(0.0, 1.0);
        final back = size(i) * 0.5 + (1 - hot) * (size(i) * 0.5 + 6);
        final room = math.max(0.0, r - _lava - back);
        final keep =
            (0.22 + 0.18 * (1 - clever)) * (1 - 0.7 * hot) * room +
            islandSin(a) * (1 - clever) * 0.18 * room;
        final at = _lava + back + keep;
        return hl < 1e-9 ? (0.0, at) : (hx / hl * at, hy / hl * at);
      case IslandKind.stones:
        final (past, k) = _nearestStone(s.x, s.y);
        if (past > size(i) * 0.3) {
          // Over a gap: for the nearest stone, well onto it.
          final qx = s.x - _sx[k], qy = s.y - _sy[k];
          final q = math.sqrt(qx * qx + qy * qy);
          final on = math.max(0.0, r - size(i) * 1.5);
          return (_sx[k] + qx / q * on, _sy[k] + qy / q * on);
        }
        final keep = (0.22 + 0.18 * (1 - clever)) * r;
        final wander = (1 - clever) * 0.18 * r;
        return (
          _sx[k] + (al < 1e-9 ? 0 : ax / al * keep) + islandCos(a) * wander,
          _sy[k] + (al < 1e-9 ? 0 : ay / al * keep) + islandSin(a) * wander,
        );
    }
  }

  void _move(int i, double r) {
    final s = states[i];
    if (s.outAt != null) return;
    final dt = 1 / kIslandTickRate;
    switch (s.phase) {
      case FighterPhase.windup:
        // Gathering itself, turning to its mark; a little give.
        s.vx *= 0.85;
        s.vy *= 0.85;
        if (tick - s.phaseFrom >= _windup) {
          final o = states[s.target];
          var ox = o.x - s.x, oy = o.y - s.y;
          final d = math.sqrt(ox * ox + oy * oy);
          if (d < 1e-6) {
            ox = -s.x;
            oy = -s.y;
          }
          final dd = math.sqrt(ox * ox + oy * oy);
          s
            ..dx = dd < 1e-6 ? 0 : ox / dd
            ..dy = dd < 1e-6 ? 0 : oy / dd
            ..phase = FighterPhase.dash
            ..phaseFrom = tick;
        }
      case FighterPhase.dash:
        final speed = _dashSpeed(i);
        s
          ..vx = s.dx * speed
          ..vy = s.dy * speed;
        if (tick - s.phaseFrom >= dashTicks(i)) {
          // A charge that finds no one pulls up (on the ice, it slides on).
          s
            ..vx *= _pullUp[i]
            ..vy *= _pullUp[i]
            ..phase = FighterPhase.stand
            ..phaseFrom = tick;
        }
      case FighterPhase.reel:
        if (tick - s.phaseFrom >= 24) {
          s
            ..phase = FighterPhase.stand
            ..phaseFrom = tick;
        }
      case FighterPhase.stand:
        // Back towards where it would rather stand.
        final clever = ((wits[i] - 2) / 3).clamp(0.0, 1.0);
        var ax = 0.0, ay = 0.0;
        for (final j in _alive(i)) {
          final o = states[j];
          final ox = s.x - o.x, oy = s.y - o.y;
          final d = math.sqrt(ox * ox + oy * oy) + 20;
          ax += ox / (d * d);
          ay += oy / (d * d);
        }
        final al = math.sqrt(ax * ax + ay * ay);
        final (hx, hy) = _home(i, clever, ax, ay, al, r);
        final ox = hx - s.x, oy = hy - s.y;
        final d = math.sqrt(ox * ox + oy * oy);
        final cap = 30 + 7 * pace[i];
        // Steps towards that spot, easing in as it nears it rather than
        // running past (on the ice especially): what it would be doing, and
        // as much of a turn towards that as its pace allows in a tick.
        final want = math.min(cap, d * 4);
        final wx = d > 1e-6 ? ox / d * want : 0.0;
        final wy = d > 1e-6 ? oy / d * want : 0.0;
        final ex = wx - s.vx, ey = wy - s.vy;
        final el = math.sqrt(ex * ex + ey * ey);
        final acc = _stride(i) * dt;
        if (el > acc) {
          s
            ..vx += ex / el * acc
            ..vy += ey / el * acc;
        } else {
          s
            ..vx = wx
            ..vy = wy;
        }
        final v = math.sqrt(s.vx * s.vx + s.vy * s.vy);
        if (v > cap && s.phase == FighterPhase.stand) {
          // Only its own steps are capped; a blow still carries it.
          s
            ..vx *= 0.96
            ..vy *= 0.96;
        }
      case FighterPhase.fall:
      case FighterPhase.out:
        break;
    }
    if (s.phase != FighterPhase.dash) {
      s
        ..vx *= _grip[i]
        ..vy *= _grip[i];
    }
    if (s.standing) {
      if (bout.kind.plain) {
        // The crumbling edge slopes away: near it, the sand slides
        // outward. The crowd steadies its favourite at the brink: what
        // carries it out is checked a little, the more so the more
        // beautiful it is.
        final rr = math.sqrt(s.x * s.x + s.y * s.y);
        if (rr > 0.72 * r && rr > 1e-6) {
          final k = (rr / r - 0.72) / 0.28;
          final slide = 30 * k * k * dt;
          s
            ..vx += s.x / rr * slide
            ..vy += s.y / rr * slide;
        }
        if (rr > 0.8 * r && rr > 1e-6) {
          final out = (s.vx * s.x + s.vy * s.y) / rr;
          if (out > 0) {
            final k = 0.006 * poise[i];
            s
              ..vx -= s.x / rr * out * k
              ..vy -= s.y / rr * out * k;
          }
        }
      } else {
        _brink(i, dt);
      }
      if (bout.kind == IslandKind.blackHole) _drawIn(i, dt);
    }
    s
      ..x += s.vx * dt
      ..y += s.vy * dt;
    // A stone carries what stands on it as it drifts.
    if (bout.kind == IslandKind.stones &&
        s.standing &&
        s.phase != FighterPhase.dash) {
      final k = _stoneUnder(i);
      if (k >= 0) {
        s
          ..x += _mx[k]
          ..y += _my[k];
      }
    }
  }

  /// The black hole draws fighter [i] in towards its heart, as hard as
  /// [pullOn] says — except that one with its grace left, where the pull
  /// is more than it can walk against, holds against the worst of it.
  void _drawIn(int i, double dt) {
    if (_pull <= 0) return;
    final s = states[i];
    final rr = math.sqrt(s.x * s.x + s.y * s.y);
    if (rr < 1e-6) return;
    var a = pullOn(i);
    final stride = _stride(i);
    if (a > stride && s.burn < grace[i]) a = kHoleHold * stride;
    s
      ..vx -= s.x / rr * a * dt
      ..vy -= s.y / rr * a * dt;
  }

  /// The twists' brinks, as the sand's edge: the ground slopes away to
  /// them, and the crowd steadies its favourite there. The ring has two —
  /// its edge, and the lava's; a stone has its own edge (but not where it
  /// lies against another). By the black hole there is only the edge: its
  /// pull is its own ([_drawIn]).
  void _brink(int i, double dt) {
    final s = states[i];
    switch (bout.kind) {
      case IslandKind.sand:
      case IslandKind.ice:
        break;
      case IslandKind.blackHole:
        final rr = math.sqrt(s.x * s.x + s.y * s.y);
        if (rr < 1e-6) return;
        final band = math.min(0.28 * _r, 0.3 * (_r - _hole));
        _slope(s, s.x / rr, s.y / rr, _r - rr, band, poise[i], dt);
      case IslandKind.molten:
        final rr = math.sqrt(s.x * s.x + s.y * s.y);
        if (rr < 1e-6) return;
        final band = math.min(0.28 * _r, 0.3 * (_r - _lava));
        _slope(s, s.x / rr, s.y / rr, _r - rr, band, poise[i], dt);
        if (_lava > 0 && rr > _lava) {
          _slope(s, -s.x / rr, -s.y / rr, rr - _lava, band, poise[i], dt);
        }
      case IslandKind.stones:
        final k = _stoneUnder(i);
        if (k < 0) return;
        final qx = s.x - _sx[k], qy = s.y - _sy[k];
        final rr = math.sqrt(qx * qx + qy * qy);
        if (rr < 1e-6) return;
        final nx = qx / rr, ny = qy / rr;
        // Where it would go off: onto another stone, there is no brink.
        if (_onStone(_sx[k] + nx * (_r + 2), _sy[k] + ny * (_r + 2), 0)) {
          return;
        }
        _slope(s, nx, ny, _r - rr, 0.28 * _r, poise[i], dt);
    }
  }

  /// A brink [room] away along (nx, ny): within [band] of it the ground
  /// slides that way; nearer still, what carries it there is checked by
  /// the crowd's favour ([poise]).
  static void _slope(
    IslandFighter s,
    double nx,
    double ny,
    double room,
    double band,
    double poise,
    double dt,
  ) {
    if (band <= 0) return;
    if (room < band) {
      final k = 1 - room / band;
      final slide = 30 * k * k * dt;
      s
        ..vx += nx * slide
        ..vy += ny * slide;
    }
    if (room < band * (0.2 / 0.28)) {
      final out = s.vx * nx + s.vy * ny;
      if (out > 0) {
        final k = 0.006 * poise;
        s
          ..vx -= nx * out * k
          ..vy -= ny * out * k;
      }
    }
  }

  void _collide() {
    final n = states.length;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final a = states[i], b = states[j];
        if (!a.standing || !b.standing) continue;
        final ox = b.x - a.x, oy = b.y - a.y;
        final d = math.sqrt(ox * ox + oy * oy);
        final reach = size(i) + size(j);
        if (d >= reach || d < 1e-6) continue;
        final nx = ox / d, ny = oy / d;
        // Apart, by their masses.
        final over = reach - d;
        final mi = mass(i), mj = mass(j);
        a
          ..x -= nx * over * mj / (mi + mj)
          ..y -= ny * over * mj / (mi + mj);
        b
          ..x += nx * over * mi / (mi + mj)
          ..y += ny * over * mi / (mi + mj);
        // A charge landing: the one charged is sent flying, the harder the
        // stronger the charger against how well it stands.
        _land(i, j, nx, ny);
        _land(j, i, -nx, -ny);
      }
    }
  }

  /// How fast fighter [i]'s charge runs.
  double _dashSpeed(int i) =>
      (72 + 11 * pace[i]) * (states[i].boosted ? 1.25 : 1);

  void _land(int i, int j, double nx, double ny) {
    final a = states[i], b = states[j];
    if (a.phase != FighterPhase.dash) return;
    // Strength against strength: even, a blow carries about a fifth of the
    // island; a much stronger one's, near half.
    final hit =
        _dashSpeed(i) *
        0.62 *
        (0.45 + 0.55 * push[i] / math.max(1.0, push[j])) *
        (a.boosted ? 1.4 : 1) *
        math.sqrt(mass(i) / mass(j));
    final carry = hit * (1 + b.worn);
    b.worn += kIslandWearPerBlow * hit / kIslandEvenBlow;
    b
      ..vx += nx * carry
      ..vy += ny * carry
      ..phase = FighterPhase.reel
      ..phaseFrom = tick;
    a
      ..vx *= 0.2
      ..vy *= 0.2
      ..phase = FighterPhase.stand
      ..phaseFrom = tick;
    a.hitsAt.add(tick);
  }

  /// Whether fighter [i] still has ground under it: over the edge is out;
  /// so is into the lava, or off every stone, once its grace is spent (at
  /// once, for one with none). A charge in flight over a gap is a leap,
  /// and not yet a fall. Into the black hole's heart is out at once; its
  /// grace is spent in the pull round it ([_drawIn]).
  void _ground(int i, double r) {
    final s = states[i];
    if (s.outAt != null) return;
    if (s.fellAt == null) {
      const dt = 1 / kIslandTickRate;
      var gone = false;
      switch (bout.kind) {
        case IslandKind.sand:
        case IslandKind.ice:
          gone = math.sqrt(s.x * s.x + s.y * s.y) > r + size(i) * 0.3;
        case IslandKind.blackHole:
          final rr = math.sqrt(s.x * s.x + s.y * s.y);
          if (rr > _r + size(i) * 0.3) {
            gone = true;
          } else if (_hole > 0 && rr < _hole) {
            // Its feet over the heart: taken.
            gone = true;
            s.sank = true;
          } else if (_caught(i)) {
            s.burn += dt;
          } else {
            s.burn = math.max(0.0, s.burn - dt);
          }
        case IslandKind.molten:
          final rr = math.sqrt(s.x * s.x + s.y * s.y);
          if (rr > _r + size(i) * 0.3) {
            gone = true;
          } else if (rr < _lava - size(i) * 0.3) {
            s.burn += dt;
            if (s.burn >= grace[i]) {
              gone = true;
              s.sank = true;
            }
          } else {
            s.burn = math.max(0.0, s.burn - dt);
          }
          // The heat wears down one not made for it, the more the wider
          // the lava.
          s.worn += kMoltenWear * dt * (_lava / kMoltenMax) * _wilts[i];
        case IslandKind.stones:
          if (s.phase == FighterPhase.dash) break;
          if (_onStone(s.x, s.y, size(i) * 0.3)) {
            s.burn = math.max(0.0, s.burn - dt);
          } else {
            s.burn += dt;
            gone = s.burn >= grace[i];
          }
      }
      if (gone) {
        s
          ..fellAt = tick
          ..phase = FighterPhase.fall
          ..phaseFrom = tick;
      }
    }
    if (s.fellAt != null && tick - s.fellAt! >= 30) {
      s
        ..outAt = tick
        ..phase = FighterPhase.out;
    }
  }

  /// How far fighter [i] is from going out, as it stands: from the edge
  /// on sand and ice; from the nearer of the edge and the lava (or the
  /// hole's heart) on the ring; from its stone's edge on the stones.
  double _safety(int i) {
    final s = states[i];
    final rr = math.sqrt(s.x * s.x + s.y * s.y);
    switch (bout.kind) {
      case IslandKind.sand:
      case IslandKind.ice:
        return _r - rr;
      case IslandKind.molten:
        return math.min(_r - rr, rr - _lava);
      case IslandKind.blackHole:
        return math.min(_r - rr, rr - _hole);
      case IslandKind.stones:
        return -_nearestStone(s.x, s.y).$1;
    }
  }

  /// Fighter indices, the winner first: the one left standing, then those
  /// who fell, last to fall first. A bout run out of time goes to the one
  /// nearest the middle (on the twists, the one furthest from going out).
  List<int> get standings {
    final order = [for (var i = 0; i < states.length; i++) i];
    double rank(int i) {
      final s = states[i];
      if (s.fellAt == null) {
        if (!bout.kind.plain) return 1e9 + _safety(i);
        final rr = math.sqrt(s.x * s.x + s.y * s.y);
        return 1e9 - rr;
      }
      return s.fellAt!.toDouble();
    }

    order.sort((a, b) {
      final c = rank(b).compareTo(rank(a));
      return c != 0 ? c : a.compareTo(b);
    });
    return order;
  }
}
