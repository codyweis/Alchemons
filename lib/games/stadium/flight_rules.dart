// lib/games/stadium/flight_rules.dart
//
// THE SPACE COURSE (the Emerald Cup; the author, 2026-10-12: "another
// cosmic obstacle course type cosmic thing", routes picked before the
// start). Three fly up a course through space that splits at forks; at
// each, one way is one kind of trouble and the other another — asteroids
// to smash through (Strength), a gravity well to sling round
// (Intelligence), comet tails to ride (Speed), a nebula whose glow lights
// up the beautiful (Beauty). Each picks its whole route before the start;
// the first through the gate wins.
//
// Flown as a race is run (race_rules.dart): each stretch judged by its
// trait under its own condition, a pace from that, boosts that wind up
// and surge. The three never touch, so each flies its own route and the
// times are set side by side. Deterministic: the same three on the same
// routes with the same taps make the same flight.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

/// What a stretch of the course is.
enum FlightKind {
  open('OPEN SPACE', CosmicContestTrait.speed, 1.0, 0.06),
  comets('COMET TAILS', CosmicContestTrait.speed, 1.1, 0.11),
  asteroids('ASTEROIDS', CosmicContestTrait.strength, 0.55, 0.13),
  gravity('GRAVITY WELL', CosmicContestTrait.intelligence, 0.62, 0.14),
  nebula('NEBULA', CosmicContestTrait.beauty, 0.8, 0.12);

  const FlightKind(this.title, this.trait, this.paceScale, this.pacePerPoint);

  final String title;
  final CosmicContestTrait trait;

  /// How fast it is flown against open space, and how much each point of
  /// judged score moves that.
  final double paceScale, pacePerPoint;

  /// One plain line of what it is.
  String get line => switch (this) {
    open => 'Open space.',
    comets => 'Ride the comets\' tails. The fast fly faster.',
    asteroids => 'Smash through the rocks. The strong go straight.',
    gravity => 'Sling round the well. The clever come out fastest.',
    nebula => 'Fly through the glow. It lights up the beautiful.',
  };

  ContestCondition condition(int level) =>
      _conditions[this] ?? contestCondition(trait, level);
}

const Map<FlightKind, ContestCondition> _conditions = {
  FlightKind.comets: ContestCondition(
    title: 'COMET TAILS',
    line: 'Riding the tails.',
    elementAdd: {
      'Air': 0.4,
      'Lightning': 0.4,
      'Ice': 0.3,
      'Light': 0.2,
      'Mud': -0.3,
    },
    familyAdd: {'wing': 0.4, 'let': 0.15, 'horn': -0.2},
    good: 'rides the tails',
    bad: 'is shaken off',
  ),
  FlightKind.asteroids: ContestCondition(
    title: 'ASTEROIDS',
    line: 'Through the rocks.',
    elementAdd: {
      'Earth': 0.5,
      'Crystal': 0.4,
      'Lava': 0.3,
      'Air': -0.2,
      'Spirit': -0.2,
    },
    familyAdd: {'horn': 0.45, 'mane': 0.15, 'wing': -0.2},
    good: 'smashes through',
    bad: 'is battered',
  ),
  FlightKind.gravity: ContestCondition(
    title: 'GRAVITY WELL',
    line: 'Round the well.',
    elementAdd: {'Dark': 0.5, 'Spirit': 0.35, 'Light': 0.25, 'Crystal': 0.15},
    familyAdd: {'mask': 0.35, 'kin': 0.2},
    good: 'slings round it',
    bad: 'is dragged in',
  ),
  FlightKind.nebula: ContestCondition(
    title: 'NEBULA',
    line: 'Through the glow.',
    elementAdd: {'Light': 0.4, 'Poison': 0.3, 'Spirit': 0.3, 'Water': 0.15},
    familyAdd: {'mask': 0.2, 'wing': 0.2},
    good: 'shines in it',
    bad: 'is lost in it',
  ),
};

/// One way through a stretch.
class FlightRoute {
  const FlightRoute(this.kind, this.length, {this.level = 2});

  final FlightKind kind;
  final double length;
  final int level;
}

/// A course: stretches flown in order, each one way (shared by all) or a
/// fork of two.
class FlightCourse {
  const FlightCourse(this.stretches);

  final List<List<FlightRoute>> stretches;

  /// The forks' places in [stretches].
  List<int> get forks => [
    for (var i = 0; i < stretches.length; i++)
      if (stretches[i].length > 1) i,
  ];

  /// The way flown with [choices] (one per fork, 0 or 1).
  List<FlightRoute> route(List<int> choices) {
    final out = <FlightRoute>[];
    var f = 0;
    for (final s in stretches) {
      if (s.length == 1) {
        out.add(s.single);
      } else {
        final c = f < choices.length ? choices[f] : 0;
        out.add(s[c.clamp(0, s.length - 1)]);
        f++;
      }
    }
    return out;
  }
}

/// How [r] is judged on [route].
ContestVerdict judgeFlight(Racer r, FlightRoute route) => judgeEntrant(
  route.kind.trait,
  route.level,
  r.entrant.withRating(r.ratings[route.kind.trait] ?? 1),
  condition: route.kind.condition(route.level),
);

/// The pace (units a second) [score] flies [route] at.
double flightPace(FlightRoute route, double score) =>
    kRaceBasePace *
    route.kind.paceScale *
    (1 + route.kind.pacePerPoint * (score - 3)).clamp(
      kRacePaceFloor,
      kRacePaceCeiling,
    );

/// The way [r] would do best to fly [course]: at each fork, the one it
/// gets through soonest.
List<int> bestFlightRoute(Racer r, FlightCourse course) => [
  for (final f in course.forks)
    () {
      final s = course.stretches[f];
      var best = 0;
      var bestTime = double.infinity;
      for (var k = 0; k < s.length; k++) {
        final time = s[k].length / flightPace(s[k], judgeFlight(r, s[k]).score);
        if (time < bestTime) {
          bestTime = time;
          best = k;
        }
      }
      return best;
    }(),
];

class FlightRacer {
  FlightRacer(this.boostsLeft);

  double distance = 0, velocity = 0;
  int leg = 0;
  int boostsLeft;
  RacerPhase phase = RacerPhase.running;
  int phaseFrom = 0;
  final List<int> boostsAt = [];
  final List<int> legEnteredAt = [0];
  double? finishTime;

  bool get busy => phase != RacerPhase.running;
}

class FlightSim {
  FlightSim(this.course, this.fighters, this.choices)
    : assert(fighters.length == choices.length),
      routes = [for (final c in choices) course.route(c)],
      states = [for (final f in fighters) FlightRacer(f.boosts)] {
    verdicts = [
      for (var i = 0; i < fighters.length; i++)
        [for (final leg in routes[i]) judgeFlight(fighters[i], leg)],
    ];
    paces = [
      for (var i = 0; i < fighters.length; i++)
        [
          for (var j = 0; j < routes[i].length; j++)
            flightPace(routes[i][j], verdicts[i][j].score),
        ],
    ];
    starts = [
      for (final r in routes)
        () {
          final out = <double>[];
          var at = 0.0;
          for (final l in r) {
            out.add(at);
            at += l.length;
          }
          return out;
        }(),
    ];
    lengths = [for (final r in routes) r.fold(0.0, (s, l) => s + l.length)];
    // A computer flyer spends its stamina as it enters its slowest
    // stretches (a canny one), or its first ones.
    autoLegs = [
      for (var i = 0; i < fighters.length; i++)
        fighters[i].isPlayer ? const <int>[] : _plan(i),
    ];
  }

  final FlightCourse course;
  final List<Racer> fighters;

  /// Each one's choices at the forks, and the way that makes.
  final List<List<int>> choices;
  final List<List<FlightRoute>> routes;
  final List<FlightRacer> states;
  late final List<List<ContestVerdict>> verdicts;
  late final List<List<double>> paces;
  late final List<List<double>> starts;
  late final List<double> lengths;
  late final List<List<int>> autoLegs;
  int tick = 0;

  final Map<int, List<int>> _pending = {};
  final Map<int, List<int>> taps = {};

  List<int> _plan(int i) {
    final r = fighters[i];
    final n = r.boosts.clamp(0, routes[i].length);
    final legs = [for (var j = 0; j < routes[i].length; j++) j];
    if (r.autoBoostLegs.isEmpty) return legs.take(n).toList();
    double slowness(int j) => 1 / paces[i][j];
    legs.sort((a, b) {
      final c = slowness(b).compareTo(slowness(a));
      return c != 0 ? c : a.compareTo(b);
    });
    return legs.take(n).toList()..sort();
  }

  bool get over =>
      tick >= kRaceMaxTicks || states.every((s) => s.finishTime != null);

  /// How far through its own route each is, 0..1.
  double progress(int i) => (states[i].distance / lengths[i]).clamp(0.0, 1.0);

  void tap(int i, [int? atTick]) {
    final at = atTick ?? tick;
    (taps[i] ??= []).add(at);
    if (at >= tick) (_pending[i] ??= []).add(at);
  }

  bool canBoost(int i) {
    final s = states[i];
    return s.boostsLeft > 0 && !s.busy && s.finishTime == null;
  }

  void step() {
    if (over) return;
    for (var i = 0; i < states.length; i++) {
      _step(i);
    }
    tick++;
  }

  void _step(int i) {
    final s = states[i];
    final due = _pending[i];
    if (due != null && due.isNotEmpty) {
      due.removeWhere((t) {
        if (t > tick) return false;
        if (t == tick && canBoost(i)) {
          s
            ..boostsLeft -= 1
            ..phase = RacerPhase.windup
            ..phaseFrom = tick;
          s.boostsAt.add(tick);
        }
        return true;
      });
    }
    if (s.phase == RacerPhase.windup &&
        tick - s.phaseFrom >= kRaceBoostWindupTicks) {
      s
        ..phase = RacerPhase.surge
        ..phaseFrom = tick;
    } else if (s.phase == RacerPhase.surge &&
        tick - s.phaseFrom >= kRaceBoostSurgeTicks) {
      s.phase = RacerPhase.running;
    }
    final target =
        paces[i][s.leg] + (s.phase == RacerPhase.surge ? kRaceBoostPace : 0);
    s.velocity += (target - s.velocity) * kRacePaceEase;
    final before = s.distance;
    s.distance += s.velocity / kRaceTickRate;
    if (s.finishTime == null && s.distance >= lengths[i]) {
      final part = (lengths[i] - before) / (s.distance - before);
      s.finishTime = (tick + part) / kRaceTickRate;
    }
    while (s.leg + 1 < routes[i].length && s.distance >= starts[i][s.leg + 1]) {
      s.leg++;
      s.legEnteredAt.add(tick + 1);
      if (autoLegs[i].contains(s.leg)) tap(i, tick + 1);
    }
  }

  /// The three, the first through the gate first; those still flying by
  /// how far through their routes.
  List<int> get standings {
    final order = [for (var i = 0; i < states.length; i++) i];
    order.sort((a, b) {
      final fa = states[a].finishTime, fb = states[b].finishTime;
      if (fa != null || fb != null) {
        if (fa == null) return 1;
        if (fb == null) return -1;
        final c = fa.compareTo(fb);
        if (c != 0) return c;
      }
      final c = progress(b).compareTo(progress(a));
      return c != 0 ? c : a.compareTo(b);
    });
    return order;
  }

  factory FlightSim.run(
    FlightCourse course,
    List<Racer> fighters,
    List<List<int>> choices, [
    Map<int, List<int>> taps = const {},
  ]) {
    final sim = FlightSim(course, fighters, choices);
    for (final e in taps.entries) {
      for (final t in e.value) {
        sim.tap(e.key, t);
      }
    }
    while (!sim.over) {
      sim.step();
    }
    return sim;
  }
}

const _o = FlightKind.open;
const _c = FlightKind.comets;
const _a = FlightKind.asteroids;
const _g = FlightKind.gravity;
const _n = FlightKind.nebula;

/// The Emerald Cup's courses, by their bouts' places. Each way through a
/// fork takes about as long for a flyer judged 3, so which is the quicker
/// is down to who flies it.
const Map<String, FlightCourse> kFlightCourses = {
  'asteroids': FlightCourse([
    [FlightRoute(_o, 800, level: 1)],
    [FlightRoute(_a, 430, level: 1), FlightRoute(_c, 860, level: 1)],
    [FlightRoute(_o, 500, level: 1)],
    [FlightRoute(_g, 485, level: 1), FlightRoute(_n, 625, level: 1)],
    [FlightRoute(_o, 600, level: 1)],
  ]),
  'nebula': FlightCourse([
    [FlightRoute(_o, 600)],
    [FlightRoute(_n, 700), FlightRoute(_a, 480)],
    [FlightRoute(_o, 400)],
    [FlightRoute(_c, 960), FlightRoute(_g, 540)],
    [FlightRoute(_o, 400)],
    [FlightRoute(_a, 450), FlightRoute(_n, 655)],
    [FlightRoute(_o, 500)],
  ]),
  'stars': FlightCourse([
    [FlightRoute(_o, 700, level: 3)],
    [FlightRoute(_g, 560, level: 3), FlightRoute(_c, 1000, level: 3)],
    [FlightRoute(_o, 400, level: 3)],
    [FlightRoute(_a, 500, level: 3), FlightRoute(_n, 720, level: 3)],
    [FlightRoute(_o, 400, level: 3)],
    [FlightRoute(_c, 990, level: 3), FlightRoute(_g, 555, level: 3)],
    [FlightRoute(_o, 600, level: 3)],
  ]),
};
