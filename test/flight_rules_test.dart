import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
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

  // Who can win each Emerald course: every catalog species at level 10,
  // flying the way that suits it best, boosting on its slowest stretches.
  //
  //   FLIGHT_CATALOG=1 flutter test test/flight_rules_test.dart \
  //     --plain-name 'catalog balance'
  test('catalog balance', () {
    if (Platform.environment['FLIGHT_CATALOG'] == null) return;
    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final species = [
      for (final c in json['creatures'] as List)
        Creature.fromJson(c as Map<String, dynamic>),
    ].where((c) => c.baseStats != null && c.types.isNotEmpty).toList();
    double rate(int base, int p) => AlchemonStatSystem.legacyGameplayRating(
      AlchemonStatSystem.effectiveInternal(
        speciesBase: base,
        level: 10,
        potential: p,
      ),
    );
    final cup = kGemCups[2];
    for (var b = 0; b < cup.bouts.length; b++) {
      final course = kFlightCourses[cup.bouts[b].place]!;
      final line = StringBuffer('${cup.name} ${cup.bouts[b].name}:');
      final form = cup.rivalForm[b];
      for (final p in [70, 80, 90, 100]) {
        var n = 0;
        for (final c in species) {
          final s = c.baseStats!;
          final me = _f(
            c.name,
            element: c.types.first,
            family: (c.mutationFamily ?? 'kin').toLowerCase(),
            spd: rate(s.speed, p),
            str: rate(s.strength, p),
            intel: rate(s.intelligence, p),
            bea: rate(s.beauty, p),
            player: true,
          );
          final rivals = [
            for (final r in cup.rivalsOf(b)) gemRivalRacer(r, form),
          ];
          final three = [me, ...rivals];
          final sim = FlightSim(course, three, [
            for (final r in three) bestFlightRoute(r, course),
          ]);
          // The player boosts as it enters its three slowest stretches.
          final legs = [for (var j = 0; j < sim.routes[0].length; j++) j]
            ..sort((x, y) => sim.paces[0][x].compareTo(sim.paces[0][y]));
          final slow = legs.take(3).toSet();
          var seen = 0;
          while (!sim.over) {
            final s0 = sim.states[0];
            if (s0.leg != seen) {
              seen = s0.leg;
              if (slow.contains(seen)) sim.tap(0);
            }
            sim.step();
          }
          if (sim.standings.first == 0) n++;
        }
        line.write(' P$p ${(100 * n / species.length).round()}%');
      }
      // ignore: avoid_print
      print(line);
    }
  });
}
