import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/island_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/games/stadium/island_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
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

List<RaceBody> _bodies(int n) => [
  for (var i = 0; i < n; i++)
    RaceBody(
      CosmicPartyMember(
        instanceId: 'x$i',
        baseId: '',
        displayName: 'Fighter $i',
        element: 'Fire',
        family: 'pip',
        level: 1,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: -1,
        staminaBars: 3,
        staminaMax: 3,
      ),
    ),
];

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

  group('the twists', () {
    const molten = IslandBout(IslandKind.molten, 2);
    const stones = IslandBout(IslandKind.stones, 3);
    List<Racer> three() => [
      _f('a', player: true, v: 4),
      _f('b', element: 'Water', family: 'pip', v: 4, canny: true),
      _f('c', element: 'Earth', family: 'horn', v: 4, canny: true),
    ];

    test('each ends with one left standing, in good time', () {
      for (final bout in [molten, stones]) {
        final sim = IslandSim.run(bout, three(), {
          0: [200, 700, 1300],
        });
        expect(sim.over, isTrue, reason: bout.kind.name);
        expect(sim.tick, lessThan(kIslandMaxTicks), reason: bout.kind.name);
        expect(sim.states.where((s) => s.outAt == null).length, 1);
      }
    });

    test('the knack is for its own kind, never a bigger stat', () {
      final sim = IslandSim(molten, [
        _f('fire', element: 'Fire', family: 'mane', v: 2),
        _f('lava', element: 'Lava', family: 'kin', v: 2),
        _f('water', element: 'Water', family: 'mane', v: 6),
      ]);
      expect(sim.grace[0], greaterThan(sim.grace[1]));
      expect(sim.grace[1], greaterThan(1));
      expect(sim.grace[2], 0);
      final sky = IslandSim(stones, [
        _f('air', element: 'Air', family: 'wing', v: 2),
        _f('spirit', element: 'Spirit', family: 'pip', v: 2),
        _f('earth', element: 'Earth', family: 'horn', v: 6, scale: 1.3),
      ]);
      expect(sky.grace[0], greaterThan(sky.grace[1]));
      expect(sky.grace[1], greaterThan(0));
      expect(sky.grace[2], 0);
      // On plain sand there is none.
      expect(IslandSim(sand, three()).grace, everyElement(0));
    });

    test('the lava opens in the middle; the stones part and come back', () {
      final sim = IslandSim(molten, three());
      expect(sim.lavaAt(0), 0);
      expect(sim.lavaAt(20 * kIslandTickRate), kMoltenMax);
      expect(sim.radiusAt(20 * kIslandTickRate), greaterThan(kMoltenMax));
      final sky = IslandSim(stones, three());
      final together = sky.stoneGapAt(0);
      final apart = sky.stoneGapAt(
        (5 + kStonesCycle / 2) * kIslandTickRate ~/ 1,
      );
      final again = sky.stoneGapAt((5 + kStonesCycle) * kIslandTickRate ~/ 1);
      expect(together, lessThan(0));
      expect(apart, closeTo(kStonesGapMax, 1e-6));
      expect(again, lessThan(0));
      // Each starts on a stone of its own.
      for (var i = 0; i < 3; i++) {
        expect(sky.adrift(i), isFalse);
      }
    });

    test('two phones agree, one hearing the other a second late', () {
      for (final bout in [molten, stones]) {
        final fighters = [
          _f('cpu', element: 'Lava', family: 'horn', v: 4.4, canny: true),
          _f('a', element: 'Fire', family: 'mane', v: 4.6, player: true),
          _f('b', element: 'Air', family: 'wing', v: 4.5, player: true),
        ];
        var wall = 0.0;
        IslandStage stage(int me) => IslandStage(
          bout: bout,
          fighters: fighters,
          bodies: _bodies(3),
          player: me,
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
        expect(aTapped, greaterThan(0));
        expect(bTapped, greaterThan(0));
        final whole = IslandSim.run(bout, fighters, {1: a.myTaps, 2: b.myTaps});
        for (final s in [a.sim, b.sim]) {
          expect(s.tick, whole.tick, reason: bout.kind.name);
          expect(s.standings, whole.standings, reason: bout.kind.name);
          expect(
            [for (final st in s.states) st.fellAt],
            [for (final st in whole.states) st.fellAt],
          );
        }
        // Each phone sees its own fighter start at the front.
        for (final me in [1, 2]) {
          final fresh = stage(me);
          expect(fresh.y[me], closeTo(kIslandRadius * 0.55, 1e-6));
          expect(fresh.x[me], closeTo(0, 1e-6));
        }
      }
    });
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
  // four Potentials alike (and, for the last three columns, Enhanced),
  // charging three times a few seconds apart (eight ways). For the two twists, how its
  // own kind (heat: Fire and Lava; the leap: Air, Spirit, Lightning, Light
  // and the wing line) fares against everyone else.
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
      (50, 0),
      (60, 0),
      (70, 0),
      (80, 0),
      (90, 0),
      (90, 5),
      (95, 10),
      (100, 10),
    ];
    // Three charges, a few seconds apart, eight ways (some early).
    const schedules = [
      [400, 900, 1400],
      [250, 700, 1200],
      [550, 1100, 1700],
      [320, 1000, 1550],
      [90, 600, 1300],
      [150, 480, 1050],
      [700, 1250, 1900],
      [200, 820, 1650],
    ];
    bool native(String place, Creature c) {
      final el = c.types.first;
      final fam = (c.mutationFamily ?? 'kin').toLowerCase();
      return switch (place) {
        'molten' => el == 'Fire' || el == 'Lava',
        'stones' =>
          const ['Air', 'Spirit', 'Lightning', 'Light'].contains(el) ||
              fam == 'wing',
        _ => false,
      };
    }

    final cup = kGemCups[0];
    final out = StringBuffer(
      '${''.padRight(24)}${setups.map((s) => 'P${s.$1}e${s.$2}'.padLeft(8)).join()}\n',
    );
    // ISLAND_FORM=1.02,0.98,1.01 tries other rival forms.
    final forms = Platform.environment['ISLAND_FORM']?.split(',');
    for (var b = 0; b < cup.bouts.length; b++) {
      final bout = islandBoutOf(cup.bouts[b]);
      final form = forms == null ? cup.rivalForm[b] : double.parse(forms[b]);
      final all = <String>[], own = <String>[], rest = <String>[];
      var secs = 0.0, runs = 0;
      for (final (p, e) in setups) {
        var n = 0, nOwn = 0, ownN = 0, nRest = 0, restN = 0;
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
              CosmicContestTrait.speed: rate(s.speed, p, e),
              CosmicContestTrait.strength: rate(s.strength, p, e),
              CosmicContestTrait.intelligence: rate(s.intelligence, p, e),
              CosmicContestTrait.beauty: rate(s.beauty, p, e),
            },
            boosts: 3,
          );
          for (final taps in schedules) {
            final sim = IslandSim.run(
              bout,
              [me, for (final r in cup.rivalsOf(b)) gemRivalRacer(r, form)],
              {0: taps},
            );
            final won = sim.standings.first == 0;
            secs += sim.tick / kIslandTickRate;
            runs++;
            if (won) n++;
            if (native(cup.bouts[b].place, c)) {
              ownN++;
              if (won) nOwn++;
            } else {
              restN++;
              if (won) nRest++;
            }
          }
        }
        String pc(int k, int of) =>
            of == 0 ? '-' : '${(100 * k / of).round()}%';
        all.add(pc(n, species.length * schedules.length));
        own.add(pc(nOwn, ownN));
        rest.add(pc(nRest, restN));
      }
      String row(String name, List<String> v) =>
          '${name.padRight(24)}${v.map((x) => x.padLeft(8)).join()}\n';
      out.write(row('${cup.bouts[b].name} (all)', all));
      if (cup.bouts[b].place != 'sand') {
        out.write(row('  its own kind', own));
        out.write(row('  everyone else', rest));
      }
      out.write('  ${(secs / runs).toStringAsFixed(1)} s a bout\n');
    }
    // ignore: avoid_print
    print(out);
  });
}
