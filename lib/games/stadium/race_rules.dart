// lib/games/stadium/race_rules.dart
//
// THE RACE: six Alchemons over a course of legs. Each leg is judged by the
// contest rules (contest_judging.dart) for one trait under one condition,
// and the score sets the pace: a sprint, a pond, a gap and ice by speed; a
// hill and mud by strength; a fusion station by intelligence; the crowd's
// stretch by beauty. The pond, the gap, the ice and the mud each have a
// condition of their own (who swims, who glides, who skates, who ploughs
// through); the rest climb their trait's contest ladder by level. Speed has
// the most ground, so it leads, but every stat is run somewhere.
//
// A course runs out of the stadium, through a place of its own (a meadow,
// the cliffs, a crystal cave — [RaceScene]), and back in for the finish.
// The place is only scenery: it changes nothing the simulation does.
//
// A fusion station holds an element. The racer fuses its own element with
// it by the recipe table (Fire + Water make Steam): a pair with a recipe
// fuses cleanly, a pair without one is worked out the long way.
//
// No chance: the same six on the same course with the same boost taps
// finish the same way, to the tick. Only + − × ÷ on doubles, which every
// platform rounds alike, so a live race can run on every phone at once with
// nothing but the taps sent between them.
//
// A boost spends one of the racer's stamina bars (3, or 4 with Dormant),
// refilled for every race. A tap winds up for [kRaceBoostWindupTicks] — the
// creature gathers itself, which also covers a live race's latency — then
// runs a fixed amount faster for [kRaceBoostSurgeTicks]. A fixed distance is
// worth the most time where the racer is slowest, so a boost is best spent on
// the leg it is worst at.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_heart.dart';

/// Simulation steps per second.
const int kRaceTickRate = 60;

/// Units a second on an open sprint for a racer judged 3.
const double kRaceBasePace = 120;

/// How far the pace can move from a racer judged 3.
const double kRacePaceFloor = 0.5, kRacePaceCeiling = 1.6;

/// How quickly a racer's speed settles to its leg's pace, per tick.
const double kRacePaceEase = 0.08;

/// A boost: the wind-up, the surge, and what the surge adds.
const int kRaceBoostWindupTicks = 36;
const int kRaceBoostSurgeTicks = 72;
const double kRaceBoostPace = 32;

/// A race stops being simulated after this long even if someone is left on
/// the course (nothing authored comes near it).
const int kRaceMaxTicks = kRaceTickRate * 240;

enum RaceLegKind { sprint, hill, pond, gap, ice, mud, fuse, crowd }

extension RaceLegKindX on RaceLegKind {
  /// The trait the leg is judged by.
  CosmicContestTrait get trait => switch (this) {
    RaceLegKind.sprint ||
    RaceLegKind.pond ||
    RaceLegKind.gap ||
    RaceLegKind.ice => CosmicContestTrait.speed,
    RaceLegKind.hill || RaceLegKind.mud => CosmicContestTrait.strength,
    RaceLegKind.fuse => CosmicContestTrait.intelligence,
    RaceLegKind.crowd => CosmicContestTrait.beauty,
  };

  /// How fast the leg is run against an open sprint: a hill is climbed, a
  /// pond swum, a fusion worked, mud waded.
  double get paceScale => switch (this) {
    RaceLegKind.sprint => 1.0,
    RaceLegKind.hill => 0.5,
    RaceLegKind.pond => 0.55,
    RaceLegKind.gap => 0.7,
    RaceLegKind.ice => 0.9,
    RaceLegKind.mud => 0.45,
    RaceLegKind.fuse => 0.6,
    RaceLegKind.crowd => 0.9,
  };

  /// How much each point of judged score moves the pace. The sprints are
  /// most of the race, so a point there is worth less a second; the short
  /// legs lean harder on their stat so that it still tells.
  double get pacePerPoint => switch (this) {
    RaceLegKind.sprint => 0.06,
    RaceLegKind.hill => 0.12,
    RaceLegKind.pond => 0.13,
    RaceLegKind.gap => 0.13,
    RaceLegKind.ice => 0.1,
    RaceLegKind.mud => 0.12,
    RaceLegKind.fuse => 0.15,
    RaceLegKind.crowd => 0.1,
  };

  String get label => switch (this) {
    RaceLegKind.sprint => 'SPRINT',
    RaceLegKind.hill => 'HILL',
    RaceLegKind.pond => 'POND',
    RaceLegKind.gap => 'GAP',
    RaceLegKind.ice => 'ICE',
    RaceLegKind.mud => 'MUD',
    RaceLegKind.fuse => 'FUSION',
    RaceLegKind.crowd => 'CROWD',
  };
}

/// The stadium's own conditions: what a pond, a gap, ice and mud favour.
/// Judged like any contest condition (contest_judging.dart), so the same
/// lines come back in the results ("WATER · swims well").
const Map<RaceLegKind, ContestCondition> _terrain = {
  RaceLegKind.pond: ContestCondition(
    title: 'POND',
    line: 'A swim.',
    elementAdd: {
      'Water': 0.5,
      'Ice': 0.3,
      'Steam': 0.2,
      'Mud': 0.1,
      'Fire': -0.4,
      'Lava': -0.4,
      'Earth': -0.2,
      'Dust': -0.25,
      'Crystal': -0.15,
    },
    familyAdd: {'pip': 0.3, 'horn': -0.15},
    good: 'swims well',
    bad: 'struggles in the water',
    sizeMul: 0.5,
  ),
  RaceLegKind.gap: ContestCondition(
    title: 'GAP',
    line: 'A gap to cross.',
    elementAdd: {
      'Air': 0.5,
      'Spirit': 0.3,
      'Lightning': 0.2,
      'Light': 0.15,
      'Earth': -0.2,
      'Mud': -0.2,
      'Lava': -0.15,
      'Crystal': -0.15,
    },
    familyAdd: {'wing': 0.55, 'let': 0.1, 'horn': -0.2},
    good: 'glides across',
    bad: 'climbs down and out',
    sizeMul: 1.2,
  ),
  RaceLegKind.ice: ContestCondition(
    title: 'ICE',
    line: 'Slick ground.',
    elementAdd: {
      'Ice': 0.5,
      'Crystal': 0.2,
      'Water': 0.15,
      'Plant': -0.1,
      'Fire': -0.25,
      'Lava': -0.3,
    },
    familyAdd: {'let': 0.2, 'kin': -0.1},
    good: 'skates the ice',
    bad: 'slips on the ice',
  ),
  RaceLegKind.mud: ContestCondition(
    title: 'MUD',
    line: 'Thick going.',
    elementAdd: {
      'Mud': 0.5,
      'Earth': 0.4,
      'Plant': 0.25,
      'Water': 0.1,
      'Air': -0.3,
      'Light': -0.2,
      'Lightning': -0.2,
    },
    familyAdd: {'horn': 0.3, 'mane': 0.1, 'let': -0.2, 'wing': -0.15},
    good: 'ploughs through',
    bad: 'sinks in the mud',
    sizeMul: 1.5,
  ),
};

/// Where a course runs, between leaving the stadium and coming back in.
/// Scenery only.
enum RaceScene { stadium, meadow, volcano, cliffs, hills, forest, caves, space }

/// What each leg is called, and its one line, by level (the author,
/// 2026-10-12: the contest names on the course map — TITAN BOUT and the
/// like — were "cheesy"). Plain words for what is on the track; the space
/// arenas keep their own names. A leg with one condition has one entry.
const Map<RaceLegKind, List<(String, String)>> _legWords = {
  RaceLegKind.sprint: [
    ('SPRINT', 'A clear track.'),
    ('RAIN', 'Rain on the track.'),
    ('STORM', 'Lightning on the track.'),
    ('TURNS', 'Tight turns all the way.'),
    ('LONG SPRINT', 'Everything counts for more.'),
  ],
  RaceLegKind.hill: [
    ('HILL', 'A hill to climb.'),
    ('HOT HILL', 'The rocks are hot.'),
    ('STEEP HILL', 'Big climbers have the reach.'),
    ('ROCKY HILL', 'Technique over bulk.'),
    ('BIG HILL', 'Everything counts for more.'),
  ],
  RaceLegKind.pond: [('POND', 'A swim.')],
  RaceLegKind.gap: [('GAP', 'A gap to cross.')],
  RaceLegKind.ice: [('ICE', 'Slick ground.')],
  RaceLegKind.mud: [('MUD', 'Thick going.')],
  RaceLegKind.crowd: [
    ('CROWD', 'The crowd carries the ones it loves.'),
    ('CONTRAST', 'Stand apart from the others.'),
    ('MOONLIGHT', 'Cool light only: silver, blue and shadow.'),
    ('PUREBREDS', 'The crowd loves a clean bloodline.'),
    ('BIG CROWD', 'Everything counts for more.'),
  ],
};

class RaceLeg {
  const RaceLeg(this.kind, this.length, {this.level = 1, this.element})
    : assert((kind == RaceLegKind.fuse) == (element != null));
  final RaceLegKind kind;
  final double length;

  /// A fusion station's element.
  final String? element;

  /// The leg's condition, as the level (1–5) of its trait's contest ladder:
  /// a level-2 sprint is wet, a level-2 hill hot. A pond, a gap, ice and
  /// mud have one condition of their own and ignore it.
  final int level;

  ContestCondition get condition =>
      _terrain[kind] ?? contestCondition(kind.trait, level);

  (String, String) get _words {
    final list = _legWords[kind]!;
    return list[(level - 1).clamp(0, list.length - 1)];
  }

  /// How the leg is named: plainly, what is on the track (RAIN, HOT WALL,
  /// MOONLIGHT); a fusion station by its element.
  String get title => switch (kind) {
    RaceLegKind.fuse => 'FUSION · ${element!.toUpperCase()}',
    _ => _words.$1,
  };

  /// One plain line of what the leg is (none for a fusion: the HUD says
  /// what the racer makes there).
  String get line => kind == RaceLegKind.fuse ? '' : _words.$2;

  /// What the course map writes under it: nothing for a clear sprint (most
  /// of every course), the element for a fusion station.
  String get mapLabel => switch (kind) {
    RaceLegKind.sprint when level <= 1 => '',
    RaceLegKind.fuse => element!.toUpperCase(),
    _ => _words.$1,
  };
}

class RaceCourse {
  const RaceCourse({
    required this.id,
    required this.name,
    required this.legs,
    this.scene = RaceScene.stadium,
  });
  final String id, name;
  final List<RaceLeg> legs;

  /// Where it runs once out of the stadium.
  final RaceScene scene;

  double get length => legs.fold(0.0, (s, l) => s + l.length);

  /// Where each leg begins, from the start line.
  List<double> get legStarts {
    final out = <double>[];
    var at = 0.0;
    for (final l in legs) {
      out.add(at);
      at += l.length;
    }
    return out;
  }
}

/// One of the six in a race.
class Racer {
  const Racer({
    required this.id,
    required this.entrant,
    required this.ratings,
    this.boosts = 3,
    this.autoBoostLegs = const [],
    this.isPlayer = false,
  });

  final String id;

  /// What the judges see; its statRating is replaced per leg from [ratings].
  final ContestEntrant entrant;

  /// Each trait's stat on the 1–5 gameplay rating.
  final Map<CosmicContestTrait, double> ratings;

  /// Stamina bars to spend on boosts this race.
  final int boosts;

  /// A computer racer taps a boost as it enters each of these legs.
  final List<int> autoBoostLegs;

  final bool isPlayer;

  /// How the judges score it on [leg], as the [element] it is by then (its
  /// own, unless a fusion station earlier on the course changed it).
  ContestVerdict judge(RaceLeg leg, {String? element}) {
    final el = element ?? entrant.element;
    final v = judgeEntrant(
      leg.kind.trait,
      leg.level,
      entrant.withRating(ratings[leg.kind.trait] ?? 1, element: el),
      condition: _terrain[leg.kind],
    );
    final station = leg.element;
    if (station == null) return v;
    final f = fusionFactor(el, station);
    final factors = [...v.factors, f]
      ..sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    return ContestVerdict(
      (v.score + f.delta).clamp(0.0, kContestScoreMax).toDouble(),
      factors,
    );
  }
}

/// What a racer that starts as [start] is as it enters each leg of
/// [course], and (last) once over the line. A fusion station with a recipe
/// for it makes it the recipe's product from the next leg on — a Fire Mask
/// at a Water station runs on as Steam — and the stretches after judge it
/// as that (the author, 2026-10-12); a pair with no recipe leaves it as it
/// was. Fixed by the course, so a live race stays the same race.
List<String> raceElements(String start, RaceCourse course) {
  final out = <String>[start];
  var e = start;
  for (final leg in course.legs) {
    final station = leg.element;
    if (leg.kind == RaceLegKind.fuse && station != null) {
      e = raceFusion(e, station) ?? e;
    }
    out.add(e);
  }
  return out;
}

/// What [racer] and a station's [station] element make, by the recipe table:
/// the same element twice makes itself; a pair with no recipe, null.
String? raceFusion(String racer, String station) {
  final a = _cap(racer), b = _cap(station);
  return a == b ? a : heartRecipe(a, b);
}

/// What the judges count at a fusion station.
ContestFactor fusionFactor(String racer, String station) {
  final a = _cap(racer).toUpperCase(), b = _cap(station).toUpperCase();
  final made = raceFusion(racer, station);
  return made == null
      ? ContestFactor('$a + $b · NO RECIPE', -0.4)
      : ContestFactor('$a + $b → ${made.toUpperCase()}', 0.5);
}

String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

/// The pace (units a second) a judged [score] runs [leg] at.
double racePace(RaceLeg leg, double score) =>
    kRaceBasePace *
    leg.kind.paceScale *
    (1 + leg.kind.pacePerPoint * (score - 3)).clamp(
      kRacePaceFloor,
      kRacePaceCeiling,
    );

/// A computer racer's boosts: a canny one spends them on its slowest legs,
/// a green one on the first legs it reaches.
List<int> planRaceBoosts(
  Racer racer,
  RaceCourse course, {
  required bool canny,
}) {
  final n = racer.boosts.clamp(0, course.legs.length);
  if (!canny) return [for (var i = 0; i < n; i++) i];
  final legs = [for (var i = 0; i < course.legs.length; i++) i];
  final els = raceElements(racer.entrant.element, course);
  double time(int i) {
    final leg = course.legs[i];
    return leg.length / racePace(leg, racer.judge(leg, element: els[i]).score);
  }

  // Slowest per unit of ground first; one boost per leg.
  double slowness(int i) => time(i) / course.legs[i].length;
  legs.sort((a, b) {
    final c = slowness(b).compareTo(slowness(a));
    return c != 0 ? c : a.compareTo(b);
  });
  return (legs.take(n).toList()..sort());
}

enum RacerPhase { running, windup, surge }

class RacerState {
  RacerState(this.boostsLeft);

  double distance = 0, velocity = 0;
  int boostsLeft;
  int leg = 0;

  /// The tick the current wind-up or surge began.
  int phaseFrom = 0;
  RacerPhase phase = RacerPhase.running;

  /// Ticks a boost was accepted at.
  final List<int> boostsAt = [];

  /// The tick each leg was entered (the first is 0).
  final List<int> legEnteredAt = [0];

  /// Seconds from the gun to the line, between ticks; null while running.
  double? finishTime;

  bool get busy => phase != RacerPhase.running;
}

/// A race in progress. Step it at [kRaceTickRate]; tap boosts in as they
/// come. A tap that arrives late (a live race) is replayed with
/// [RaceSim.replay].
class RaceSim {
  RaceSim(this.course, this.racers)
    : assert(racers.isNotEmpty),
      _legStarts = course.legStarts,
      verdicts = [
        for (final r in racers)
          () {
            final els = raceElements(r.entrant.element, course);
            return [
              for (var j = 0; j < course.legs.length; j++)
                r.judge(course.legs[j], element: els[j]),
            ];
          }(),
      ],
      states = [for (final r in racers) RacerState(r.boosts)] {
    paces = [
      for (var i = 0; i < racers.length; i++)
        [
          for (var j = 0; j < course.legs.length; j++)
            racePace(course.legs[j], verdicts[i][j].score),
        ],
    ];
  }

  /// A fresh race with [taps] (racer index → ticks) replayed up to [tick].
  factory RaceSim.replay(
    RaceCourse course,
    List<Racer> racers,
    Map<int, List<int>> taps,
    int tick,
  ) {
    final sim = RaceSim(course, racers);
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

  /// The whole race, start to finish, with [taps] (racer index → ticks).
  factory RaceSim.run(
    RaceCourse course,
    List<Racer> racers, [
    Map<int, List<int>> taps = const {},
  ]) => RaceSim.replay(course, racers, taps, kRaceMaxTicks);

  final RaceCourse course;
  final List<Racer> racers;
  final List<double> _legStarts;

  /// Each racer's verdict on each leg, and the pace it gives.
  final List<List<ContestVerdict>> verdicts;
  late final List<List<double>> paces;

  final List<RacerState> states;
  int tick = 0;

  /// Taps waiting for their tick, per racer.
  final Map<int, List<int>> _pending = {};

  /// Every tap given, per racer, for a replay.
  final Map<int, List<int>> taps = {};

  double get seconds => tick / kRaceTickRate;

  bool get over =>
      tick >= kRaceMaxTicks || states.every((s) => s.finishTime != null);

  /// Racer [i] taps a boost at [atTick] (now, if null). Taps for a tick
  /// already stepped are not applied here — replay the race instead.
  void tap(int i, [int? atTick]) {
    final at = atTick ?? tick;
    (taps[i] ??= []).add(at);
    if (at >= tick) (_pending[i] ??= []).add(at);
  }

  /// Whether racer [i] could boost right now.
  bool canBoost(int i) {
    final s = states[i];
    return s.boostsLeft > 0 && !s.busy && s.finishTime == null;
  }

  void step() {
    if (over) return;
    for (var i = 0; i < racers.length; i++) {
      _stepRacer(i);
    }
    tick++;
  }

  void _stepRacer(int i) {
    final s = states[i];
    final r = racers[i];

    // Taps due now. One boost at a time: a tap while one is running is spent
    // on nothing (and costs nothing).
    final due = _pending[i];
    if (due != null && due.isNotEmpty) {
      due.removeWhere((t) {
        if (t > tick) return false;
        if (t == tick) _boost(i);
        return true;
      });
    }

    // Phase changes.
    if (s.phase == RacerPhase.windup &&
        tick - s.phaseFrom >= kRaceBoostWindupTicks) {
      s
        ..phase = RacerPhase.surge
        ..phaseFrom = tick;
    } else if (s.phase == RacerPhase.surge &&
        tick - s.phaseFrom >= kRaceBoostSurgeTicks) {
      s.phase = RacerPhase.running;
    }

    // Past the line the racer eases on at its last pace, for the eye only.
    final target =
        paces[i][s.leg] + (s.phase == RacerPhase.surge ? kRaceBoostPace : 0);
    s.velocity += (target - s.velocity) * kRacePaceEase;
    final before = s.distance;
    s.distance += s.velocity / kRaceTickRate;

    if (s.finishTime == null) {
      final length = course.length;
      if (s.distance >= length) {
        final part = (length - before) / (s.distance - before);
        s.finishTime = (tick + part) / kRaceTickRate;
      }
    }

    // Into the next leg.
    while (s.leg + 1 < course.legs.length &&
        s.distance >= _legStarts[s.leg + 1]) {
      s.leg++;
      s.legEnteredAt.add(tick + 1);
      if (r.autoBoostLegs.contains(s.leg)) tap(i, tick + 1);
    }
  }

  void _boost(int i) {
    if (!canBoost(i)) return;
    final s = states[i];
    s
      ..boostsLeft -= 1
      ..phase = RacerPhase.windup
      ..phaseFrom = tick;
    s.boostsAt.add(tick);
  }

  /// Racer indices, leader first: by finish time once over the line, then
  /// by distance; ties to the lower lane.
  List<int> get standings {
    final order = [for (var i = 0; i < racers.length; i++) i];
    order.sort((a, b) {
      final fa = states[a].finishTime, fb = states[b].finishTime;
      if (fa != null || fb != null) {
        if (fa == null) return 1;
        if (fb == null) return -1;
        final c = fa.compareTo(fb);
        if (c != 0) return c;
      } else {
        final c = states[b].distance.compareTo(states[a].distance);
        if (c != 0) return c;
      }
      return a.compareTo(b);
    });
    return order;
  }

  /// Seconds racer [i] spent on each leg it has finished.
  List<double> legTimes(int i) {
    final s = states[i];
    final out = <double>[];
    for (var j = 0; j < s.legEnteredAt.length; j++) {
      final from = s.legEnteredAt[j] / kRaceTickRate;
      final to = j + 1 < s.legEnteredAt.length
          ? s.legEnteredAt[j + 1] / kRaceTickRate
          : s.finishTime;
      if (to == null) break;
      out.add(to - from);
    }
    return out;
  }
}
