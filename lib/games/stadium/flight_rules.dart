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
// The cup's three bouts each fly it by their own rule (the author,
// 2026-10-18: the gem cups were "too repetitive"):
//
//  * The plain course: pick the way that suits you at every fork.
//  * The Gravity Chain: wells line the course, and each sling flings you
//    on faster the cleaner the last one was — a well slung straight after
//    another carries what the last one gave it, and the run-out after it
//    is flown that much faster. Any other way breaks the chain. A strong
//    chain pays off more than one-off picks, and it is the clever (and
//    the dark, the spirited, the masks) who sling cleanly.
//  * The Element Gates: each fork is two gates of an element. Flying
//    through one the flyer's element fuses with by the recipe table makes
//    it the product (as the race's fusion stations do) and that stretch
//    fast; a gate with no recipe is slow. A route is a chain of fusions
//    planned before the start, and the flyer changes form as it goes.
//
// Flown as a race is run (race_rules.dart): each stretch judged by its
// trait under its own condition, a pace from that, boosts that wind up
// and surge. The three never touch, so each flies its own route and the
// times are set side by side. Deterministic, + − × ÷ only: the same three
// on the same routes with the same taps make the same flight on every
// phone.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

/// What a stretch of the course is.
enum FlightKind {
  open('OPEN SPACE', CosmicContestTrait.speed, 1.0, 0.06),
  comets('COMET TAILS', CosmicContestTrait.speed, 1.1, 0.11),
  asteroids('ASTEROIDS', CosmicContestTrait.strength, 0.55, 0.13),
  gravity('GRAVITY WELL', CosmicContestTrait.intelligence, 0.62, 0.14),
  nebula('NEBULA', CosmicContestTrait.beauty, 0.8, 0.12),
  gate('GATE', CosmicContestTrait.speed, 0.95, 0.1);

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
    gate => 'Fly through the gate.',
  };

  ContestCondition condition(int level) =>
      _conditions[this] ?? contestCondition(trait, level);
}

const Map<FlightKind, ContestCondition> _conditions = {
  // Open space is open at every level (the speed ladder's wet and stormy
  // lanes are the stadium's, not space's).
  FlightKind.open: ContestCondition(title: 'OPEN SPACE', line: 'Open space.'),
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
    strangers: -0.25,
  ),
  FlightKind.nebula: ContestCondition(
    title: 'NEBULA',
    line: 'Through the glow.',
    elementAdd: {'Light': 0.4, 'Poison': 0.3, 'Spirit': 0.3, 'Water': 0.15},
    familyAdd: {'mask': 0.2, 'wing': 0.2},
    good: 'shines in it',
    bad: 'is lost in it',
  ),
  // A gate is flown as open space is; what counts there is the recipe.
  FlightKind.gate: ContestCondition(title: 'GATE', line: 'Through the gate.'),
};

// ── the rules' weights ──────────────────────────────────────────────────────

/// The Gravity Chain. A well's sling is its score over 3, and it carries
/// [kChainCarry] of the sling before it while the chain holds; the next
/// well is flown [kChainWell] faster for each point the chain brings in,
/// and the run-out after a well [kFlingPerPoint] faster for each point of
/// its sling (each at most [kFlingMax] times as fast).
const double kChainCarry = 0.55, kChainWell = 0.06, kFlingPerPoint = 0.06;
const double kFlingMax = 1.8;

/// The Element Gates: how much a gate's recipe (or none) counts (as the
/// race's fusion stations, [fusionFactor]), and how fast a gate is flown
/// with a recipe and without one.
const double kGateGround = 2, kGateFast = 1.0, kGateSlow = 0.7;

/// One way through a stretch.
class FlightRoute {
  const FlightRoute(
    this.kind,
    this.length, {
    this.level = 2,
    this.element,
    this.ground = 1,
  }) : assert((kind == FlightKind.gate) == (element != null));

  final FlightKind kind;
  final double length;
  final int level;

  /// A gate's element.
  final String? element;

  /// How much the way's own condition counts over an ordinary one (a
  /// deeper well): its element and family extras, [ground] times over.
  final double ground;

  /// What it is called: its kind, or a gate by its element.
  String get title => element?.toUpperCase() ?? kind.title;

  ContestCondition get condition {
    final c = kind.condition(level);
    return ground == 1 ? c : c.deeper(ground);
  }
}

/// A course: stretches flown in order, each one way (shared by all) or a
/// fork of two. A [chain] course chains its wells (the Gravity Chain).
class FlightCourse {
  const FlightCourse(this.stretches, {this.chain = false});

  final List<List<FlightRoute>> stretches;
  final bool chain;

  /// The forks' places in [stretches].
  List<int> get forks => [
    for (var i = 0; i < stretches.length; i++)
      if (stretches[i].length > 1) i,
  ];

  /// Whether any way through it is a gate.
  bool get gates => stretches.any((s) => s.any((w) => w.element != null));

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

  /// Every route through it, one choice per fork, in order (0, 0, …
  /// first).
  List<List<int>> get allChoices {
    var out = <List<int>>[const []];
    for (final f in forks) {
      out = [
        for (final c in out)
          for (var k = 0; k < stretches[f].length; k++) [...c, k],
      ];
    }
    return out;
  }
}

/// How [r] is judged on [route], as the [element] it is by then (its own,
/// unless a gate back along the course has made it something else).
ContestVerdict judgeFlight(Racer r, FlightRoute route, {String? element}) =>
    judgeEntrant(
      route.kind.trait,
      route.level,
      r.entrant.withRating(
        r.ratings[route.kind.trait] ?? 1,
        element: element ?? r.entrant.element,
      ),
      condition: route.condition,
    );

/// The pace (units a second) [score] flies [route] at.
double flightPace(FlightRoute route, double score) =>
    kRaceBasePace *
    route.kind.paceScale *
    (1 + route.kind.pacePerPoint * (score - 3)).clamp(
      kRacePaceFloor,
      kRacePaceCeiling,
    );

/// How one flyer flies one route: each stretch's way, what it is as it
/// enters it, how it is judged there and the pace that gives — the chain's
/// carry and fling and the gates' fusions counted in. Fixed by the route,
/// so a live flight stays the same flight.
class FlightLegs {
  FlightLegs._(
    this.ways,
    this.elements,
    this.verdicts,
    this.paces,
    this.links,
    this.flings,
    this.made,
  );

  /// How [r] flies [course] by [choices].
  factory FlightLegs.of(Racer r, FlightCourse course, List<int> choices) {
    final ways = course.route(choices);
    final elements = <String>[];
    final verdicts = <ContestVerdict>[];
    final paces = <double>[];
    final links = <int>[];
    final flings = <double>[];
    final made = <String?>[];
    var e = r.entrant.element;
    // The chain's sling so far (0: none, or broken), and how many wells
    // it holds.
    var sling = 0.0;
    var chain = 0;
    var afterWell = false;
    for (var j = 0; j < ways.length; j++) {
      final way = ways[j];
      elements.add(e);
      var v = judgeFlight(r, way, element: e);
      var mul = 1.0;
      String? product;
      if (way.kind == FlightKind.gate) {
        final f = fusionFactor(e, way.element!, ground: kGateGround);
        v = ContestVerdict(
          (v.score + f.delta).clamp(0.0, kContestScoreMax).toDouble(),
          [f, ...v.factors],
        );
        product = raceFusion(e, way.element!);
        mul = product == null ? kGateSlow : kGateFast;
      }
      var fling = 1.0;
      if (course.chain) {
        if (way.kind == FlightKind.gravity) {
          // In on the last sling, out on this one and what it carried.
          fling = (1 + kChainWell * sling).clamp(1.0, kFlingMax);
          final own = v.score > 3 ? v.score - 3 : 0.0;
          sling = own + kChainCarry * sling;
          chain++;
          afterWell = true;
        } else if (course.stretches[j].length > 1) {
          // Another way at a fork: the chain is broken.
          sling = 0;
          chain = 0;
          afterWell = false;
        } else {
          if (afterWell) {
            fling = (1 + kFlingPerPoint * sling).clamp(1.0, kFlingMax);
          }
          afterWell = false;
        }
      }
      verdicts.add(v);
      paces.add(flightPace(way, v.score) * mul * fling);
      links.add(chain);
      flings.add(fling);
      made.add(product);
      if (product != null) e = product;
    }
    elements.add(e);
    return FlightLegs._(ways, elements, verdicts, paces, links, flings, made);
  }

  final List<FlightRoute> ways;

  /// What the flyer is entering each stretch, and (last) at the gate.
  final List<String> elements;

  final List<ContestVerdict> verdicts;
  final List<double> paces;

  /// A chain course: how many wells the chain holds once each stretch is
  /// flown (0 once it is broken), and how much faster each is flown for
  /// the sling before it (1: not flung).
  final List<int> links;
  final List<double> flings;

  /// What each gate made the flyer (null: not a gate, or no recipe).
  final List<String?> made;

  /// Seconds the route takes at its paces (no boosts, no easing).
  double get time {
    var t = 0.0;
    for (var j = 0; j < ways.length; j++) {
      t += ways[j].length / paces[j];
    }
    return t;
  }

  /// How many gates it fused through.
  int get fusions => made.where((m) => m != null).length;
}

/// The way [r] would do best to fly [course]: every route tried (the forks
/// are few), the quickest taken; ties to the first.
List<int> bestFlightRoute(Racer r, FlightCourse course) {
  var best = const <int>[];
  var bestTime = double.infinity;
  for (final c in course.allChoices) {
    final t = FlightLegs.of(r, course, c).time;
    if (t < bestTime) {
      bestTime = t;
      best = c;
    }
  }
  return best;
}

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
      legs = [
        for (var i = 0; i < fighters.length; i++)
          FlightLegs.of(fighters[i], course, choices[i]),
      ],
      states = [for (final f in fighters) FlightRacer(f.boosts)] {
    starts = [
      for (final l in legs)
        () {
          final out = <double>[];
          var at = 0.0;
          for (final w in l.ways) {
            out.add(at);
            at += w.length;
          }
          return out;
        }(),
    ];
    lengths = [for (final l in legs) l.ways.fold(0.0, (s, w) => s + w.length)];
    // A computer flyer spends its stamina as it enters its slowest
    // stretches (a canny one), or its first ones.
    autoLegs = [
      for (var i = 0; i < fighters.length; i++)
        fighters[i].isPlayer ? const <int>[] : _plan(i),
    ];
  }

  final FlightCourse course;
  final List<Racer> fighters;

  /// Each one's choices at the forks, and how it flies the way that makes.
  final List<List<int>> choices;
  final List<FlightLegs> legs;
  final List<FlightRacer> states;
  late final List<List<double>> starts;
  late final List<double> lengths;
  late final List<List<int>> autoLegs;
  int tick = 0;

  late final List<List<FlightRoute>> routes = [for (final l in legs) l.ways];
  late final List<List<ContestVerdict>> verdicts = [
    for (final l in legs) l.verdicts,
  ];
  late final List<List<double>> paces = [for (final l in legs) l.paces];

  final Map<int, List<int>> _pending = {};
  final Map<int, List<int>> taps = {};

  List<int> _plan(int i) {
    final r = fighters[i];
    final ways = legs[i].ways;
    final n = r.boosts.clamp(0, ways.length);
    final order = [for (var j = 0; j < ways.length; j++) j];
    if (r.autoBoostLegs.isEmpty) return order.take(n).toList();
    final paces = legs[i].paces;
    double slowness(int j) => 1 / paces[j];
    order.sort((a, b) {
      final c = slowness(b).compareTo(slowness(a));
      return c != 0 ? c : a.compareTo(b);
    });
    return order.take(n).toList()..sort();
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

  /// Whether [i] has a boost tapped and waiting for its tick.
  bool hasPending(int i) => _pending[i]?.isNotEmpty ?? false;

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
        legs[i].paces[s.leg] +
        (s.phase == RacerPhase.surge ? kRaceBoostPace : 0);
    s.velocity += (target - s.velocity) * kRacePaceEase;
    final before = s.distance;
    s.distance += s.velocity / kRaceTickRate;
    if (s.finishTime == null && s.distance >= lengths[i]) {
      final part = (lengths[i] - before) / (s.distance - before);
      s.finishTime = (tick + part) / kRaceTickRate;
    }
    final ways = legs[i].ways;
    while (s.leg + 1 < ways.length && s.distance >= starts[i][s.leg + 1]) {
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
  ]) => FlightSim.replay(course, fighters, choices, taps, kRaceMaxTicks);

  /// A fresh flight with [taps] (flyer → ticks) replayed up to [tick]: a
  /// tap from another phone that came late, put in where it belongs. Only
  /// the players' taps (a computer flyer taps again by itself).
  factory FlightSim.replay(
    FlightCourse course,
    List<Racer> fighters,
    List<List<int>> choices,
    Map<int, List<int>> taps,
    int tick,
  ) {
    final sim = FlightSim(course, fighters, choices);
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
}

const _o = FlightKind.open;
const _c = FlightKind.comets;
const _a = FlightKind.asteroids;
const _g = FlightKind.gravity;
const _n = FlightKind.nebula;
const _t = FlightKind.gate;

/// The course for an Emerald Cup bout.
FlightCourse flightCourseOf(GemBout bout) =>
    kFlightCourses[bout.place] ?? kFlightCourses.values.first;

/// The Emerald Cup's courses, by their bouts' places. Each way through a
/// fork takes about as long for a flyer judged 3, so which is the quicker
/// is down to who flies it.
const Map<String, FlightCourse> kFlightCourses = {
  // The Asteroid Run: the course plain.
  'asteroids': FlightCourse([
    [FlightRoute(_o, 800, level: 1)],
    [FlightRoute(_a, 430, level: 1), FlightRoute(_c, 860, level: 1)],
    [FlightRoute(_o, 500, level: 1)],
    [FlightRoute(_g, 485, level: 1), FlightRoute(_n, 625, level: 1)],
    [FlightRoute(_o, 600, level: 1)],
  ]),
  // The Gravity Chain: a well at every fork, a short run-out after each.
  // Its wells are deep (their element and family extras count twice).
  'gravity': FlightCourse(chain: true, [
    [FlightRoute(_o, 600)],
    [FlightRoute(_g, 480, ground: 2.5), FlightRoute(_a, 430)],
    [FlightRoute(_o, 320)],
    [FlightRoute(_g, 480, ground: 2.5), FlightRoute(_c, 860)],
    [FlightRoute(_o, 320)],
    [FlightRoute(_g, 480, ground: 2.5), FlightRoute(_n, 620)],
    [FlightRoute(_o, 320)],
    [FlightRoute(_g, 480, ground: 2.5), FlightRoute(_a, 430)],
    [FlightRoute(_o, 480)],
  ]),
  // The Element Gates: Fire or Ice, Spirit or Lightning, Mud or Poison,
  // Plant or Lava. Fire and Air can fuse through all four (Ice: Water,
  // Spirit: Ice, Poison: Crystal, Lava: Earth), Ice too (Fire: Water, then
  // the same), and Poison by a way of its own (Ice: Crystal, Spirit: Light,
  // Mud: Plant, Plant); Crystal, Plant, Spirit and Light three; the rest
  // fewer. The way that fuses first is not always the way that fuses most.
  'gates': FlightCourse([
    [FlightRoute(_o, 520, level: 3)],
    [
      FlightRoute(_t, 460, level: 3, element: 'Fire'),
      FlightRoute(_t, 460, level: 3, element: 'Ice'),
    ],
    [FlightRoute(_o, 300, level: 3)],
    [
      FlightRoute(_t, 460, level: 3, element: 'Spirit'),
      FlightRoute(_t, 460, level: 3, element: 'Lightning'),
    ],
    [FlightRoute(_o, 300, level: 3)],
    [
      FlightRoute(_t, 460, level: 3, element: 'Mud'),
      FlightRoute(_t, 460, level: 3, element: 'Poison'),
    ],
    [FlightRoute(_o, 300, level: 3)],
    [
      FlightRoute(_t, 460, level: 3, element: 'Plant'),
      FlightRoute(_t, 460, level: 3, element: 'Lava'),
    ],
    [FlightRoute(_o, 480, level: 3)],
  ]),
};
