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
// Every one of the three fights on its own; the player's taps are charges
// of their own — harder ones — one for each stamina bar.
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

/// The island's radius as it starts, in island units, and the least it
/// crumbles to.
const double kIslandRadius = 100, kIslandMinRadius = 16;

/// What a bout is fought on.
enum IslandKind {
  /// Plain sand.
  sand,

  /// Sheet ice: charges slide on, and stopping is hard.
  ice,

  /// Hot rock that crumbles faster at the edge.
  ember,
}

/// One bout: its island, and how hard it is judged (1..3).
class IslandBout {
  const IslandBout(this.kind, this.level);

  final IslandKind kind;
  final int level;

  /// How each trait is judged on it.
  ContestCondition condition(CosmicContestTrait trait) =>
      switch ((kind, trait)) {
        (IslandKind.ice, CosmicContestTrait.speed) => _onIce,
        (IslandKind.ice, CosmicContestTrait.strength) => _footingOnIce,
        (IslandKind.ember, CosmicContestTrait.strength) => _inTheHeat,
        _ => contestCondition(trait, level),
      };

  /// How much a charge keeps its speed, per tick.
  double get grip => switch (kind) {
    IslandKind.ice => 0.986,
    _ => 0.93,
  };

  /// How fast the edge crumbles, in units a second once it starts.
  double get crumble => switch (kind) {
    IslandKind.ember => 3.0,
    IslandKind.ice => 2.0,
    IslandKind.sand => 2.4,
  };
}

const _onIce = ContestCondition(
  title: 'ICE',
  line: 'Sheet ice: fast and hard to stop.',
  elementAdd: {'Ice': 0.5, 'Water': 0.3, 'Air': 0.15, 'Fire': -0.25},
  familyAdd: {'let': 0.2, 'horn': -0.15},
  good: 'skates',
  bad: 'slips',
);

const _footingOnIce = ContestCondition(
  title: 'FOOTING',
  line: 'Standing firm on ice.',
  elementAdd: {'Ice': 0.4, 'Crystal': 0.25, 'Earth': 0.15, 'Lava': -0.3},
  familyAdd: {'horn': 0.2, 'wing': -0.2},
  good: 'stands firm',
  bad: 'skids',
);

const _inTheHeat = ContestCondition(
  title: 'HEAT',
  line: 'Hot rock underfoot.',
  elementAdd: {
    'Fire': 0.5,
    'Lava': 0.5,
    'Earth': 0.2,
    'Ice': -0.4,
    'Plant': -0.3,
  },
  familyAdd: {'mane': 0.2},
  good: 'thrives in the heat',
  bad: 'wilts in the heat',
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

  /// Stamina charges left; when it next looks for someone to charge.
  int charges;
  int nextThink = 0;

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
      states = [] {
    final n = fighters.length;
    for (var i = 0; i < n; i++) {
      // The player at the front (the bottom of the screen), the rest
      // round the island from there.
      final a = math.pi / 2 + i * 2 * math.pi / n;
      states.add(
        IslandFighter(
          islandCos(a) * kIslandRadius * 0.55,
          islandSin(a) * kIslandRadius * 0.55,
          fighters[i].boosts,
        )..nextThink = 50 + i * 23,
      );
    }
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

  final IslandBout bout;

  /// Who fights: the race's [Racer] (what the judges see, its ratings, its
  /// stamina); a computer one is `canny` if it has autoBoostLegs.
  final List<Racer> fighters;

  /// Each one's judged Strength, Speed, Intelligence and Beauty here.
  final List<double> push, pace, wits, poise;
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

  /// The island's radius now: whole for five seconds, then crumbling.
  double get radius => radiusAt(tick);

  double radiusAt(int t) {
    final since = (t - 5 * kIslandTickRate) / kIslandTickRate;
    if (since <= 0) return kIslandRadius;
    return math.max(kIslandMinRadius, kIslandRadius - since * bout.crumble);
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

  /// The one [i] would do best to charge: the one nearest the edge and
  /// lined up with it, for a clever one; the nearest, for one that is not.
  int _pick(int i) {
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

  void _charge(int i, {required bool boosted}) {
    final s = states[i];
    final t = _pick(i);
    if (t < 0) return;
    if (boosted) s.charges -= 1;
    s
      ..phase = FighterPhase.windup
      ..phaseFrom = tick
      ..target = t
      ..boosted = boosted;
    s.chargesAt.add(tick);
  }

  /// How long a charge winds up, and how long it runs.
  static const int _windup = 18, _dash = 22;
  static const int windupTicks = _windup;

  void step() {
    if (over) return;
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
      _edge(i, r);
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
    // A computer one spends its stamina on a charge that can finish
    // someone (canny), or on its first ones (green).
    final r = fighters[i];
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
    // The clever think again sooner.
    s.nextThink =
        tick +
        (62 + (6 - wits[i]).clamp(0.0, 6.0) * 15 + _hash(tick, i) * 40).round();
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
        if (tick - s.phaseFrom >= _dash) {
          s
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
        // Back towards where it would rather stand: well inside the edge,
        // and away from the others, so there is room to charge — a clever
        // one keeps nearer the middle; one that is not wanders.
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
        final keep = (0.22 + 0.18 * (1 - clever)) * r;
        final a = tick * 0.012 + i * 2.1;
        final wander = (1 - clever) * 0.18 * r;
        final hx = (al < 1e-9 ? 0 : ax / al * keep) + islandCos(a) * wander;
        final hy = (al < 1e-9 ? 0 : ay / al * keep) + islandSin(a) * wander;
        final ox = hx - s.x, oy = hy - s.y;
        final d = math.sqrt(ox * ox + oy * oy);
        if (d > 2) {
          final acc = 46 + 12 * pace[i];
          s
            ..vx += ox / d * acc * dt
            ..vy += oy / d * acc * dt;
        }
        final cap = 30 + 7 * pace[i];
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
        ..vx *= bout.grip
        ..vy *= bout.grip;
    }
    // The crumbling edge slopes away: near it, the sand slides outward.
    // The crowd steadies its favourite at the brink: what carries it out
    // is checked a little, the more so the more beautiful it is.
    if (s.standing) {
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
    }
    s
      ..x += s.vx * dt
      ..y += s.vy * dt;
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
    b
      ..vx += nx * hit
      ..vy += ny * hit
      ..phase = FighterPhase.reel
      ..phaseFrom = tick;
    a
      ..vx *= 0.2
      ..vy *= 0.2
      ..phase = FighterPhase.stand
      ..phaseFrom = tick;
    a.hitsAt.add(tick);
  }

  void _edge(int i, double r) {
    final s = states[i];
    if (s.outAt != null) return;
    final rr = math.sqrt(s.x * s.x + s.y * s.y);
    if (s.fellAt == null && rr > r + size(i) * 0.3) {
      s
        ..fellAt = tick
        ..phase = FighterPhase.fall
        ..phaseFrom = tick;
    }
    if (s.fellAt != null && tick - s.fellAt! >= 30) {
      s
        ..outAt = tick
        ..phase = FighterPhase.out;
    }
  }

  /// Fighter indices, the winner first: the one left standing, then those
  /// who fell, last to fall first. A bout run out of time goes to the one
  /// nearest the middle.
  List<int> get standings {
    final order = [for (var i = 0; i < states.length; i++) i];
    double rank(int i) {
      final s = states[i];
      if (s.fellAt == null) {
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
