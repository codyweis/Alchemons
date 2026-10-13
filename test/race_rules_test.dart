import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

Racer _player({
  String element = 'Fire',
  String family = 'mane',
  double speed = 3,
  double strength = 3,
  double intelligence = 3,
  double beauty = 3,
  int boosts = 3,
}) => Racer(
  id: 'player',
  isPlayer: true,
  entrant: ContestEntrant(
    name: 'Player',
    element: element,
    family: family,
    statRating: 0,
  ),
  ratings: {
    CosmicContestTrait.speed: speed,
    CosmicContestTrait.strength: strength,
    CosmicContestTrait.intelligence: intelligence,
    CosmicContestTrait.beauty: beauty,
  },
  boosts: boosts,
);

const _course = RaceCourse(
  id: 't',
  name: 'Test',
  legs: [
    RaceLeg(RaceLegKind.sprint, 600),
    RaceLeg(RaceLegKind.hill, 300),
    RaceLeg(RaceLegKind.sprint, 600),
  ],
);

double _finish(RaceSim sim, int i) => sim.states[i].finishTime!;

void main() {
  test('the same race always finishes the same way', () {
    final cup = kRaceCups[1];
    final field = raceField(cup, 0, _player(speed: 3.6));
    final a = RaceSim.run(cup.courses[0], field, {
      2: [120, 900],
    });
    final b = RaceSim.run(cup.courses[0], field, {
      2: [120, 900],
    });
    for (var i = 0; i < field.length; i++) {
      expect(a.states[i].finishTime, b.states[i].finishTime);
    }
    expect(a.standings, b.standings);
  });

  test('a boost gains time, and more on a hill than on a sprint', () {
    final p = _player();
    final none = _finish(RaceSim.run(_course, [p]), 0);
    final onSprint = _finish(
      RaceSim.run(
        _course,
        [p],
        {
          0: [30],
        },
      ),
      0,
    );
    // Reaches the hill about five seconds in (600 units at 120).
    final onWall = _finish(
      RaceSim.run(
        _course,
        [p],
        {
          0: [5 * kRaceTickRate + 10],
        },
      ),
      0,
    );
    expect(onSprint, lessThan(none));
    expect(onWall, lessThan(onSprint));
  });

  test('a tap while a boost runs is spent on nothing', () {
    final p = _player();
    final sim = RaceSim.run(
      _course,
      [p],
      {
        0: [30, 40, 50],
      },
    );
    expect(sim.states[0].boostsAt, [30]);
    expect(sim.states[0].boostsLeft, 2);
  });

  test('no more boosts than stamina bars', () {
    final p = _player(boosts: 2);
    final sim = RaceSim.run(
      _course,
      [p],
      {
        0: [10, 200, 400, 600],
      },
    );
    expect(sim.states[0].boostsAt, [10, 200]);
  });

  test('a late tap replays to the same race as one given in time', () {
    final cup = kRaceCups[0];
    final field = raceField(cup, 1, _player());
    final live = RaceSim(cup.courses[1], field);
    for (var t = 0; t < 600; t++) {
      if (t == 300) live.tap(2);
      live.step();
    }
    // The tap at 300 reaches another phone at tick 340.
    final remote = RaceSim(cup.courses[1], field);
    for (var t = 0; t < 340; t++) {
      remote.step();
    }
    final caught = RaceSim.replay(cup.courses[1], field, {
      2: [300],
    }, 340);
    while (caught.tick < 600) {
      caught.step();
    }
    for (var i = 0; i < field.length; i++) {
      expect(caught.states[i].distance, live.states[i].distance);
    }
  });

  test('a fusion station follows the recipe table', () {
    expect(raceFusion('Fire', 'Water'), 'Steam');
    expect(raceFusion('plant', 'Water'), 'Mud');
    expect(raceFusion('Water', 'Water'), 'Water');
    expect(raceFusion('Light', 'Water'), isNull);
    expect(fusionFactor('Fire', 'Water').delta, greaterThan(0));
    expect(fusionFactor('Light', 'Water').delta, lessThan(0));

    const leg = RaceLeg(RaceLegKind.fuse, 360, element: 'Water');
    final knows = _player(element: 'Fire').judge(leg);
    final guesses = _player(element: 'Light').judge(leg);
    expect(knows.score, greaterThan(guesses.score));
    expect(knows.factors.any((f) => f.text.contains('STEAM')), isTrue);
  });

  test('the water swims, the winged glide, Ice skates, Earth ploughs', () {
    Racer racer(String element, String family) => Racer(
      id: '$element$family',
      entrant: ContestEntrant(
        name: element,
        element: element,
        family: family,
        statRating: 0,
      ),
      ratings: {for (final t in CosmicContestTrait.values) t: 3},
    );
    double score(Racer r, RaceLegKind kind) =>
        r.judge(RaceLeg(kind, 300)).score;
    expect(
      score(racer('Water', 'pip'), RaceLegKind.pond),
      greaterThan(score(racer('Fire', 'mane'), RaceLegKind.pond)),
    );
    expect(
      score(racer('Air', 'wing'), RaceLegKind.gap),
      greaterThan(score(racer('Earth', 'horn'), RaceLegKind.gap)),
    );
    expect(
      score(racer('Ice', 'let'), RaceLegKind.ice),
      greaterThan(score(racer('Lava', 'mane'), RaceLegKind.ice)),
    );
    expect(
      score(racer('Earth', 'horn'), RaceLegKind.mud),
      greaterThan(score(racer('Air', 'wing'), RaceLegKind.mud)),
    );
    // What the judges said comes back in plain words.
    final swim = racer(
      'Water',
      'pip',
    ).judge(const RaceLeg(RaceLegKind.pond, 300));
    expect(swim.factors.any((f) => f.text.contains('swims well')), isTrue);
  });

  test('a fusion makes the racer its product for the rest of the race', () {
    const course = RaceCourse(
      id: 'f',
      name: 'Fuse',
      legs: [
        RaceLeg(RaceLegKind.sprint, 300),
        RaceLeg(RaceLegKind.fuse, 300, element: 'Water'),
        RaceLeg(RaceLegKind.pond, 300),
        RaceLeg(RaceLegKind.fuse, 300, element: 'Light'),
        RaceLeg(RaceLegKind.sprint, 300),
      ],
    );
    // Fire + Water make Steam; Steam + Light has no recipe, so it stays.
    expect(raceElements('Fire', course), [
      'Fire',
      'Fire',
      'Steam',
      'Steam',
      'Steam',
      'Steam',
    ]);
    // The pond after the station judges the Steam it became, not the Fire
    // it was: it swims better than a Fire racer that never fused.
    Racer racer(String element) => Racer(
      id: element,
      entrant: ContestEntrant(
        name: element,
        element: element,
        family: 'mask',
        statRating: 0,
      ),
      ratings: {for (final t in CosmicContestTrait.values) t: 3},
    );
    final sim = RaceSim(course, [racer('Fire')]);
    final pond = sim.verdicts[0][2];
    expect(pond.factors.any((f) => f.text.startsWith('STEAM')), isTrue);
    expect(pond.score, greaterThan(racer('Fire').judge(course.legs[2]).score));
  });

  test('every course leaves the stadium for its own country', () {
    final scenes = {
      for (final cup in kRaceCups)
        for (final c in cup.courses) c.scene,
    };
    expect(scenes.length, greaterThanOrEqualTo(7));
    final kinds = {
      for (final cup in kRaceCups)
        for (final c in cup.courses)
          for (final l in c.legs) l.kind,
    };
    expect(kinds, containsAll(RaceLegKind.values));
  });

  test('a canny rival spends its boosts on its slowest legs', () {
    final course = kRaceCups[0].courses[0];
    const rival = RaceRival(
      name: 'Pebble',
      element: 'Earth',
      family: 'horn',
      speed: 2,
      strength: 3,
      intelligence: 2,
      beauty: 2,
      canny: true,
    );
    final legs = rival.racer(course).autoBoostLegs;
    expect(legs, hasLength(3));
    for (final i in legs) {
      expect(course.legs[i].kind, isNot(RaceLegKind.sprint));
    }
  });

  test('every course runs between 30 and 75 seconds', () {
    for (final cup in kRaceCups) {
      for (var r = 0; r < cup.courses.length; r++) {
        final sim = RaceSim.run(cup.courses[r], raceField(cup, r, _player()));
        for (final s in sim.states) {
          expect(s.finishTime, inInclusiveRange(30, 75), reason: cup.name);
        }
      }
    }
  });

  test('progress opens races and cups in order', () {
    var p = const RaceProgress();
    final copper = kRaceCups[0];
    expect(p.raceOpen(copper, 0), isTrue);
    expect(p.raceOpen(copper, 1), isFalse);
    expect(p.cupOpen(1), isFalse);
    bool first;
    (p, first) = p.afterWin(copper, 0);
    expect(first, isTrue);
    (p, first) = p.afterWin(copper, 0);
    expect(first, isFalse);
    (p, _) = p.afterWin(copper, 1);
    (p, _) = p.afterWin(copper, 2);
    expect(p.cupOpen(1), isTrue);
    expect(RaceProgress.deserialise(p.serialise()).wonIn(copper), 3);
  });

  // RACE_REPORT=1: where archetype racers place in every race, unboosted
  // and boosting on their three slowest legs.
  test('balance report', () {
    if (Platform.environment['RACE_REPORT'] == null) return;
    final archetypes = <String, Racer Function(double)>{
      'even': (v) => _player(
        element: 'Water',
        family: 'pip',
        speed: v,
        strength: v,
        intelligence: v,
        beauty: v,
      ),
      'sprinter': (v) => _player(
        element: 'Lightning',
        family: 'wing',
        speed: v + 0.6,
        strength: v - 0.6,
        intelligence: v - 0.4,
        beauty: v - 0.2,
      ),
      'bruiser': (v) => _player(
        element: 'Earth',
        family: 'horn',
        speed: v - 0.4,
        strength: v + 0.8,
        intelligence: v - 0.4,
        beauty: v - 0.4,
      ),
    };
    for (final cup in kRaceCups) {
      for (var r = 0; r < cup.courses.length; r++) {
        final course = cup.courses[r];
        final line = StringBuffer('${cup.name} ${course.name}:');
        for (final e in archetypes.entries) {
          for (final v in [2.0, 2.6, 3.2, 3.8, 4.4, 5.0]) {
            final p = e.value(v);
            final field = raceField(cup, r, p);
            int place(bool canny) {
              final boosting = Racer(
                id: p.id,
                entrant: p.entrant,
                ratings: p.ratings,
                boosts: p.boosts,
                autoBoostLegs: planRaceBoosts(p, course, canny: canny),
              );
              final sim = RaceSim.run(course, raceField(cup, r, boosting));
              return sim.standings.indexOf(2) + 1;
            }

            final plain = RaceSim.run(course, field).standings.indexOf(2) + 1;
            line.write(' ${e.key[0]}$v:$plain/${place(false)}/${place(true)}');
          }
        }
        // ignore: avoid_print
        print(line);
      }
    }
  });

  // Who can win each race: every catalog species at level 10 (and level 7
  // for Copper), all four Potentials alike, boosts on its slowest legs —
  // the share that wins, and the least Potential any species wins it from.
  // Targets (the author, 2026-10-12): Copper ≈ level 10 P50, Silver
  // ≈ P70–80, Gold endgame (≈ P100, or the right Alchemon from P80–90).
  //
  //   RACE_CATALOG=1 flutter test test/race_rules_test.dart \
  //     --plain-name 'catalog balance'
  test('catalog balance', () {
    if (Platform.environment['RACE_CATALOG'] == null) return;
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final species = [
      for (final c in json['creatures'] as List)
        Creature.fromJson(c as Map<String, dynamic>),
    ].where((c) => c.baseStats != null && c.types.isNotEmpty).toList();
    double rate(int base, int p, int level) =>
        AlchemonStatSystem.legacyGameplayRating(
          AlchemonStatSystem.effectiveInternal(
            speciesBase: base,
            level: level,
            potential: p,
          ),
        );
    Racer racer(Creature c, int p, int level, RaceCourse course) {
      final b = c.baseStats!;
      final r = _player(
        element: c.types.first,
        family: (c.mutationFamily ?? 'kin').toLowerCase(),
        speed: rate(b.speed, p, level),
        strength: rate(b.strength, p, level),
        intelligence: rate(b.intelligence, p, level),
        beauty: rate(b.beauty, p, level),
      );
      return Racer(
        id: r.id,
        isPlayer: true,
        entrant: r.entrant,
        ratings: r.ratings,
        boosts: r.boosts,
        autoBoostLegs: planRaceBoosts(r, course, canny: true),
      );
    }

    bool wins(int cup, int race, Creature c, int p, int level) {
      final course = kRaceCups[cup].courses[race];
      final field = raceField(kRaceCups[cup], race, racer(c, p, level, course));
      return RaceSim.run(course, field).standings.indexOf(2) == 0;
    }

    const grid = [
      [(7, 50), (10, 30), (10, 40), (10, 50), (10, 60), (10, 70)],
      [(10, 50), (10, 60), (10, 70), (10, 80), (10, 90)],
      [(10, 70), (10, 80), (10, 90), (10, 100)],
    ];
    for (var ci = 0; ci < kRaceCups.length; ci++) {
      for (var r = 0; r < kRaceCups[ci].courses.length; r++) {
        final line = StringBuffer(
          '${kRaceCups[ci].name} ${kRaceCups[ci].courses[r].name}:',
        );
        for (final (level, p) in grid[ci]) {
          final n = species.where((c) => wins(ci, r, c, p, level)).length;
          line.write(' L${level}P$p ${(100 * n / species.length).round()}%');
        }
        String? best;
        for (var p = 20; p <= 100 && best == null; p += 5) {
          final c = species.where((c) => wins(ci, r, c, p, 10)).firstOrNull;
          if (c != null) best = '${c.name} P$p';
        }
        // ignore: avoid_print
        print('$line  best: $best');
      }
    }
  });

  test('the developer tools open every cup, race and bout, winning none', () {
    final shut = RaceProgress.deserialise('{"copper":1}');
    expect(shut.cupOpen(2), isFalse);
    expect(shut.gemOpen(0), isFalse);
    final open = shut.opened();
    expect(
      [for (var i = 0; i < kRaceCups.length; i++) open.cupOpen(i)],
      [true, true, true],
    );
    expect(open.raceOpen(kRaceCups[2], 2), isTrue);
    expect(
      [for (var i = 0; i < kGemCups.length; i++) open.gemOpen(i)],
      [true, true, true],
    );
    expect(open.boutOpen(kGemCups[2], 2), isTrue);
    // Nothing is won by it, nor saved.
    expect(open.cupDone(kRaceCups[0]), isFalse);
    expect(open.serialise(), shut.serialise());
    // A win keeps everything open.
    final (next, first) = open.afterWin(kRaceCups[0], 1);
    expect(first, isTrue);
    expect(next.allOpen, isTrue);
  });
}
