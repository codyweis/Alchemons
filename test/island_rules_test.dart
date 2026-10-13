import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/island_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/games/stadium/island_stage.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Racer _f(
  String id, {
  String element = 'Fire',
  String family = 'mane',
  double v = 3,
  double str = 0,
  double scale = 1,
  bool player = false,
  bool canny = false,
}) => Racer(
  id: id,
  isPlayer: player,
  entrant: ContestEntrant(
    name: id,
    element: element,
    family: family,
    statRating: 0,
    scale: scale,
  ),
  ratings: {
    CosmicContestTrait.speed: v,
    CosmicContestTrait.strength: v + str,
    CosmicContestTrait.intelligence: v,
    CosmicContestTrait.beauty: v,
  },
  boosts: 3,
  autoBoostLegs: canny ? const [0] : const [],
);

void main() {
  const sand = IslandBout(IslandKind.sand, 1);

  test('a bout ends with one left standing, in good time', () {
    final sim = IslandSim.run(sand, [
      _f('a', player: true),
      _f('b', element: 'Water', family: 'pip'),
      _f('c', element: 'Earth', family: 'horn'),
    ]);
    expect(sim.over, isTrue);
    expect(sim.tick, lessThan(kIslandMaxTicks));
    expect(sim.states.where((s) => s.outAt == null).length, 1);
    expect(sim.standings.length, 3);
    expect(sim.states[sim.standings.first].outAt, isNull);
  });

  test('the same three with the same taps make the same bout', () {
    final three = [
      _f('a', player: true),
      _f('b', element: 'Water'),
      _f('c', element: 'Earth'),
    ];
    final x = IslandSim.run(sand, three, {
      0: [200, 700],
    });
    final y = IslandSim.run(sand, three, {
      0: [200, 700],
    });
    expect(x.standings, y.standings);
    expect(x.tick, y.tick);
    expect(x.states[0].x, y.states[0].x);
  });

  test('balance report', () {
    if (Platform.environment['ISLAND_REPORT'] == null) return;
    for (final kind in IslandKind.values) {
      for (final v in [2.0, 3.0, 4.0, 5.0, 6.0]) {
        var wins = 0, ticks = 0;
        const n = 30;
        for (var k = 0; k < n; k++) {
          // Rivals at 4 with a little variety; the player at v.
          final sim = IslandSim.run(
            IslandBout(kind, 2),
            [
              _f('p', v: v, player: true),
              _f(
                'r1',
                element: k.isEven ? 'Water' : 'Ice',
                v: 4 + (k % 3) * 0.1,
              ),
              _f('r2', element: 'Earth', family: 'horn', v: 4 - (k % 2) * 0.1),
            ],
            {
              0: [120 + k * 7, 600 + k * 11, 1100 + k * 5],
            },
          );
          if (sim.standings.first == 0) wins++;
          ticks += sim.tick;
        }
        // ignore: avoid_print
        print(
          '${kind.name} v$v: wins ${(100 * wins / n).round()}% · '
          '${(ticks / n / kIslandTickRate).toStringAsFixed(1)} s',
        );
      }
    }
  });

  // Who can win each Ruby bout: every catalog species at level 10, all
  // four Potentials alike, charging three times a few seconds apart.
  //
  //   ISLAND_CATALOG=1 flutter test test/island_rules_test.dart \
  //     --plain-name 'catalog balance'
  test('catalog balance', () {
    if (Platform.environment['ISLAND_CATALOG'] == null) return;
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
    final cup = kGemCups[0];
    for (var b = 0; b < cup.bouts.length; b++) {
      final line = StringBuffer('${cup.name} ${cup.bouts[b].name}:');
      final form = cup.rivalForm[b];
      for (final p in [50, 60, 70, 80, 90]) {
        var n = 0;
        for (final c in species) {
          final s = c.baseStats!;
          final me = Racer(
            id: 'me',
            isPlayer: true,
            entrant: ContestEntrant(
              name: c.name,
              element: c.types.first,
              family: (c.mutationFamily ?? 'kin').toLowerCase(),
              statRating: 0,
            ),
            ratings: {
              CosmicContestTrait.speed: rate(s.speed, p),
              CosmicContestTrait.strength: rate(s.strength, p),
              CosmicContestTrait.intelligence: rate(s.intelligence, p),
              CosmicContestTrait.beauty: rate(s.beauty, p),
            },
            boosts: 3,
          );
          final sim = IslandSim.run(
            islandBoutOf(cup.bouts[b]),
            [me, for (final r in cup.rivalsOf(b)) gemRivalRacer(r, form)],
            {
              0: [400, 900, 1400],
            },
          );
          if (sim.standings.first == 0) n++;
        }
        line.write(' P$p ${(100 * n / species.length).round()}%');
      }
      // ignore: avoid_print
      print(line);
    }
  });
}
