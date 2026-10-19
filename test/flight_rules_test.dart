import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/flight_stage.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

Racer _f(
  String id, {
  String element = 'Fire',
  String family = 'mane',
  double spd = 3,
  double str = 3,
  double intel = 3,
  double bea = 3,
  bool player = false,
}) => Racer(
  id: id,
  isPlayer: player,
  entrant: ContestEntrant(
    name: id,
    element: element,
    family: family,
    statRating: 0,
  ),
  ratings: {
    CosmicContestTrait.speed: spd,
    CosmicContestTrait.strength: str,
    CosmicContestTrait.intelligence: intel,
    CosmicContestTrait.beauty: bea,
  },
  boosts: 3,
  autoBoostLegs: player ? const [] : const [0],
);

/// Which of a course's kinds a species is, for the catalog probe (besides
/// 'all'). The Gravity Chain: the well's own (an element or family its
/// condition favours: RIGHT) or not (wrong), and by how much it favours it.
/// The Element Gates: how many gates its element can fuse through on its
/// best route — the most there are is RIGHT.
List<String> _kindOf(FlightCourse course, String element, String family) {
  if (course.chain) {
    final c = FlightKind.gravity.condition(2);
    final add = (c.elementAdd[element] ?? 0) + (c.familyAdd[family] ?? 0);
    return [
      add > 0 ? 'RIGHT well' : 'wrong well',
      'add ${add >= 0.5 ? '0.5+' : (add >= 0.3 ? '0.3+' : (add > 0 ? '0+' : '0'))}',
    ];
  }
  if (course.gates) {
    int fuses(String e) => course.allChoices
        .map((c) => FlightLegs.of(_f('x', element: e), course, c).fusions)
        .reduce((a, b) => a > b ? a : b);
    final most = course.forks.length;
    final n = fuses(element);
    return [n == most ? 'RIGHT gates' : 'wrong gates', 'fuses $n'];
  }
  return const [];
}

void main() {
  final course = kFlightCourses['asteroids']!;

  test('every one finishes, each on its own way', () {
    final three = [_f('a', player: true), _f('b'), _f('c')];
    final sim = FlightSim.run(course, three, [
      [0, 0],
      [1, 1],
      [0, 1],
    ]);
    expect(sim.states.every((s) => s.finishTime != null), isTrue);
    expect(sim.routes[0][1].kind, FlightKind.asteroids);
    expect(sim.routes[1][1].kind, FlightKind.comets);
    final t = sim.states[0].finishTime!;
    expect(t, inInclusiveRange(20, 50));
  });

  test(
    'a strong flyer is quicker through the rocks, a fast one on the tails',
    () {
      final strong = _f('s', element: 'Earth', family: 'horn', str: 5.5);
      final fast = _f('f', element: 'Air', family: 'wing', spd: 5.5);
      expect(bestFlightRoute(strong, course).first, 0);
      expect(bestFlightRoute(fast, course).first, 1);
    },
  );

  test('the gravity chain: each sling carries the last, a break costs', () {
    final chain = kFlightCourses['gravity']!;
    expect(chain.chain, isTrue);
    final mask = _f('m', element: 'Dark', family: 'mask', intel: 5);
    final all = FlightLegs.of(mask, chain, const [0, 0, 0, 0]);
    final wells = [
      for (var j = 0; j < all.ways.length; j++)
        if (all.ways[j].kind == FlightKind.gravity) j,
    ];
    expect(wells.length, 4);
    // The first well comes in on nothing; each after it on the chain, and
    // each run-out is flung faster than the one before.
    expect(all.flings[wells.first], 1);
    for (var q = 1; q < wells.length; q++) {
      expect(all.flings[wells[q]], greaterThan(all.flings[wells[q - 1]]));
      expect(
        all.flings[wells[q] + 1],
        greaterThan(all.flings[wells[q - 1] + 1]),
      );
      expect(all.paces[wells[q]], greaterThan(all.paces[wells.first]));
    }
    expect(all.links[wells.last], 4);
    // Broken at the second fork: the third well starts the chain again.
    final broken = FlightLegs.of(mask, chain, const [0, 1, 0, 0]);
    expect(broken.flings[wells[2]], 1);
    expect(broken.links[wells[2]], 1);
    // The well's own kind plans the whole chain; a strong one of the wrong
    // kind does not.
    expect(bestFlightRoute(mask, chain), [0, 0, 0, 0]);
    final horn = _f('h', element: 'Earth', family: 'horn', str: 5.5, spd: 4);
    expect(bestFlightRoute(horn, chain), contains(1));
  });

  test('the element gates: a recipe makes the flyer the product', () {
    final gates = kFlightCourses['gates']!;
    expect(gates.gates, isTrue);
    expect(gates.allChoices.length, 16);
    final fire = _f('f', element: 'Fire', family: 'pip', spd: 4);
    final best = bestFlightRoute(fire, gates);
    expect(best, [1, 0, 1, 1]);
    final legs = FlightLegs.of(fire, gates, best);
    expect(legs.fusions, 4);
    // Fire through Ice is Water, through Spirit Ice, through Poison
    // Crystal, through Lava Earth — and each stretch after is judged as it.
    expect(legs.elements.toSet().toList(), [
      'Fire',
      'Water',
      'Ice',
      'Crystal',
      'Earth',
    ]);
    // Keeping its own fire at the first gate fuses less later on.
    final greedy = FlightLegs.of(fire, gates, const [0, 0, 0, 0]);
    expect(greedy.fusions, lessThan(4));
    expect(greedy.time, greaterThan(legs.time));
    // A gate with no recipe is flown much slower than one with.
    final j = gates.forks.first;
    final fast = FlightLegs.of(fire, gates, const [1, 0, 0, 0]).paces[j];
    final blood = _f('b', element: 'Blood', family: 'pip', spd: 4);
    final slow = FlightLegs.of(blood, gates, const [1, 0, 0, 0]).paces[j];
    expect(slow, lessThan(fast * 0.75));
  });

  test('every course flies the same twice', () {
    for (final course in kFlightCourses.values) {
      final three = [
        _f('a', player: true, element: 'Spirit', family: 'mask'),
        _f('b', element: 'Fire', family: 'wing', spd: 4.5),
        _f('c', element: 'Earth', family: 'horn', str: 5),
      ];
      final routes = [for (final r in three) bestFlightRoute(r, course)];
      final x = FlightSim.run(course, three, routes, {
        0: [200, 900],
      });
      final y = FlightSim.run(course, three, routes, {
        0: [200, 900],
      });
      expect(x.states.every((s) => s.finishTime != null), isTrue);
      expect(x.standings, y.standings);
      expect(
        [for (final s in x.states) s.finishTime],
        [for (final s in y.states) s.finishTime],
      );
    }
  });

  // As test/gem_live_test.dart flies the plain course: two phones, one
  // hearing the other's taps a second late, agree to the tick — on the
  // chain and the gates too.
  test('two phones fly the chain and the gates alike', () {
    final bodies = [
      for (var i = 0; i < 3; i++)
        RaceBody(
          CosmicPartyMember(
            instanceId: 'x$i',
            baseId: '',
            displayName: 'Flyer $i',
            element: 'Fire',
            family: 'pip',
            level: 1,
            statSpeed: 3,
            statIntelligence: 3,
            statStrength: 3,
            statBeauty: 3,
            slotIndex: -1,
            staminaMax: 3,
            staminaBars: 3,
          ),
        ),
    ];
    for (final place in ['gravity', 'gates']) {
      final course = kFlightCourses[place]!;
      final fighters = [
        gemRivalRacer(kGemCups[2].rivals[1], 0.9),
        _f('a', player: true, element: 'Spirit', family: 'mask', intel: 4.6),
        _f('b', player: true, element: 'Air', family: 'wing', spd: 4.8),
      ];
      final routes = [for (final r in fighters) bestFlightRoute(r, course)];
      var wall = 0.0;
      FlightStage stage(int me) => FlightStage(
        course: course,
        fighters: fighters,
        bodies: bodies,
        player: me,
        choices: routes,
        live: BoutLive(gunAt: 10, wall: () => wall),
      );
      final a = stage(1), b = stage(2);
      final aLate = <(double, List<int>)>[];
      var aTapped = 0, bTapped = 0;
      while (wall < 150 && !(a.sim.over && b.sim.over)) {
        wall += 1 / 60;
        a.advance(1 / 60);
        b.advance(1 / 60);
        final t = wall - 10;
        if (aTapped < 3 && t > 1.5 + aTapped * 3.1 && a.act()) {
          aTapped++;
          aLate.add((wall + 1.0, a.myTaps));
        }
        if (bTapped < 3 && t > 2.2 + bTapped * 2.7 && b.act()) {
          bTapped++;
          a.mergeTaps(b.player, b.myTaps);
        }
        while (aLate.isNotEmpty && aLate.first.$1 <= wall) {
          b.mergeTaps(a.player, aLate.removeAt(0).$2);
        }
      }
      expect(aTapped, 3);
      expect(bTapped, 3);
      final whole = FlightSim.run(course, fighters, routes, {
        1: a.myTaps,
        2: b.myTaps,
      });
      for (final s in [a.sim, b.sim]) {
        expect(s.standings, whole.standings);
        expect(
          [for (final st in s.states) st.finishTime],
          [for (final st in whole.states) st.finishTime],
        );
      }
    }
  });

  test('the same routes and taps make the same flight', () {
    final three = [_f('a', player: true), _f('b'), _f('c')];
    final routes = [
      [0, 1],
      [1, 0],
      [0, 0],
    ];
    final x = FlightSim.run(course, three, routes, {
      0: [200, 900],
    });
    final y = FlightSim.run(course, three, routes, {
      0: [200, 900],
    });
    expect(x.standings, y.standings);
    expect(x.states[0].finishTime, y.states[0].finishTime);
  });

  // Who can win each Emerald course: every catalog species at level 10, at
  // a Potential and Enhancement rank, flying the way that suits it best,
  // boosting as it enters its three slowest stretches. Each twist bout also
  // splits the field into its "right kind" (see [_kindOf]) and the rest.
  //
  //   FLIGHT_CATALOG=1 flutter test test/flight_rules_test.dart \
  //     --plain-name 'catalog balance'
  //
  // FLIGHT_FORM=0.9,0.96,0.93 tries other rival forms.
  test('catalog balance', () {
    final env = Platform.environment;
    if (env['FLIGHT_CATALOG'] == null) return;
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final species = [
      for (final c in json['creatures'] as List)
        Creature.fromJson(c as Map<String, dynamic>),
    ].where((c) => c.baseStats != null && c.types.isNotEmpty).toList();
    double rate(int base, int p, int e) =>
        AlchemonStatSystem.legacyGameplayRating(
          AlchemonStatSystem.effectiveInternal(
            speciesBase: base,
            level: 10,
            potential: p,
            enhancementRank: e,
          ),
        );
    const setups = [
      (70, 0),
      (80, 0),
      (90, 0),
      (100, 0),
      (90, 5),
      (95, 10),
      (100, 10),
    ];
    final forms = env['FLIGHT_FORM']?.split(',').map(double.parse).toList();
    final cup = kGemCups[2];
    for (var b = 0; b < cup.bouts.length; b++) {
      final course = flightCourseOf(cup.bouts[b]);
      final form = forms?[b] ?? cup.rivalForm[b];
      final rivals = [for (final r in cup.rivalsOf(b)) gemRivalRacer(r, form)];
      final rivalWays = [
        for (final r in rivals)
          () {
            final c = bestFlightRoute(r, course);
            final legs = FlightLegs.of(r, course, c);
            return '${r.entrant.name} $c ${legs.time.toStringAsFixed(1)}s'
                '${course.gates ? ' ${legs.elements.toSet().join('>')}' : ''}';
          }(),
      ];
      final out = StringBuffer(
        '${cup.name} ${cup.bouts[b].name} (form $form) · '
        '${rivalWays.join(' · ')}\n'
        '${'kind'.padRight(22)}'
        '${setups.map((s) => 'P${s.$1}e${s.$2}'.padLeft(9)).join()}\n',
      );
      // kind → wins per setup, and how many species are of it.
      final wins = <String, List<int>>{};
      final count = <String, int>{};
      for (final c in species) {
        final s = c.baseStats!;
        final element = c.types.first;
        final family = (c.mutationFamily ?? 'kin').toLowerCase();
        final kinds = ['all', ..._kindOf(course, element, family)];
        for (final k in kinds) {
          count[k] = (count[k] ?? 0) + 1;
          wins[k] ??= List.filled(setups.length, 0);
        }
        for (var q = 0; q < setups.length; q++) {
          final (p, e) = setups[q];
          final me = _f(
            c.name,
            element: element,
            family: family,
            spd: rate(s.speed, p, e),
            str: rate(s.strength, p, e),
            intel: rate(s.intelligence, p, e),
            bea: rate(s.beauty, p, e),
            player: true,
          );
          final three = [me, ...rivals];
          final sim = FlightSim(course, three, [
            for (final r in three) bestFlightRoute(r, course),
          ]);
          final legs = [for (var j = 0; j < sim.routes[0].length; j++) j]
            ..sort((x, y) => sim.paces[0][x].compareTo(sim.paces[0][y]));
          final slow = legs.take(3).toSet();
          var seen = 0;
          if (slow.contains(0)) sim.tap(0);
          while (!sim.over) {
            final s0 = sim.states[0];
            if (s0.leg != seen) {
              seen = s0.leg;
              if (slow.contains(seen)) sim.tap(0);
            }
            sim.step();
          }
          if (sim.standings.first == 0) {
            for (final k in kinds) {
              wins[k]![q]++;
            }
          }
        }
      }
      final keys = wins.keys.toList()..sort();
      for (final k in keys) {
        out.write('$k (${count[k]})'.padRight(22));
        for (final w in wins[k]!) {
          out.write('${(100 * w / count[k]!).round()}%'.padLeft(9));
        }
        out.write('\n');
      }
      // ignore: avoid_print
      print(out);
    }
  });
}
