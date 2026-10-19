import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/sky_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

Racer _f(
  String id, {
  String element = 'Fire',
  String family = 'mane',
  double v = 3,
  Map<CosmicContestTrait, double>? ratings,
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
  ratings: ratings ?? {for (final t in CosmicContestTrait.values) t: v},
  boosts: 3,
);

void main() {
  const clear = SkyBout(SkyNight.clear, 1);

  test('every one casts once a round, the player last', () {
    final night = SkyContest(clear, [
      _f('a', player: true),
      _f('b', element: 'Water', family: 'pip'),
      _f('c', element: 'Earth', family: 'horn'),
    ]);
    expect(night.casts.length, 3 * kSkyRoundCount);
    for (var r = 0; r < kSkyRoundCount; r++) {
      final round = night.casts.where((c) => c.round == r).toList();
      expect([for (final c in round) c.fighter], [1, 2, 0]);
    }
    for (final c in night.casts) {
      expect(c.stars, inInclusiveRange(0, kSkyCastGrains));
    }
    expect(
      [for (var i = 0; i < 3; i++) night.starsOf(i)].reduce((a, b) => a + b),
      night.casts.fold(0, (n, c) => n + c.stars),
    );
  });

  test('more of a stat lights more stars in its round', () {
    final quick = _f(
      'q',
      ratings: {
        CosmicContestTrait.speed: 5,
        CosmicContestTrait.strength: 1.5,
        CosmicContestTrait.intelligence: 1.5,
        CosmicContestTrait.beauty: 1.5,
      },
    );
    final night = SkyContest(clear, [quick, _f('b'), _f('c')]);
    final cast = night.casts.where((c) => c.fighter == 0).toList();
    expect(clear.rounds.first, CosmicContestTrait.speed);
    expect(cast[0].stars, greaterThan(cast[1].stars));
    expect(night.starsOf(0), lessThan(night.starsOf(1)));
  });

  test('the most stars wins; the same three light the same stars', () {
    final three = [_f('a', v: 4.5, player: true), _f('b', v: 3), _f('c', v: 4)];
    final x = SkyContest(clear, three), y = SkyContest(clear, three);
    expect(x.standings, [0, 2, 1]);
    expect(x.standings, y.standings);
    expect(
      [for (final c in x.casts) c.stars],
      [for (final c in y.casts) c.stars],
    );
  });

  test('every night is three rounds, and every stat counts in the cup', () {
    final seen = <CosmicContestTrait>{};
    for (final n in SkyNight.values) {
      expect(n.rounds.length, kSkyRoundCount);
      seen.addAll(n.rounds);
    }
    expect(seen, CosmicContestTrait.values.toSet());
    expect(const SkyBout(SkyNight.clear, 1).elements, isEmpty);
    expect(const SkyBout(SkyNight.mirror, 2).elements, isEmpty);
    expect(const SkyBout(SkyNight.fusion, 3).elements.length, kSkyRoundCount);
    // The Sapphire Cup's bouts are the three nights, in order.
    expect([
      for (final b in kGemCups[1].bouts) skyBoutOf(b).night,
    ], SkyNight.values);
  });

  test('the lake doubles a cast that stands apart, and drowns the rest', () {
    const lake = SkyBout(SkyNight.mirror, 2);
    // Fire stands apart from Air and Spirit: all three light twice.
    final apart = SkyContest(lake, [
      _f('f', player: true),
      _f('a', element: 'Air', family: 'mask'),
      _f('s', element: 'Spirit', family: 'let'),
    ]);
    for (final c in apart.casts) {
      expect(c.water, c.stars);
    }
    // Plant shares Air's colours: both drowned, Spirit alone lights twice.
    final drowned = SkyContest(lake, [
      _f('p', element: 'Plant', player: true),
      _f('a', element: 'Air', family: 'mask'),
      _f('s', element: 'Spirit', family: 'let'),
    ]);
    expect(
      [for (var i = 0; i < 3; i++) drowned.apart(i)],
      [false, false, true],
    );
    for (final c in drowned.casts) {
      expect(c.water, c.fighter == 2 ? c.stars : 0);
    }
    // The same three under a clear night light nothing in water.
    final plain = SkyContest(clear, drowned.fighters);
    expect(plain.casts.every((c) => c.water == 0), isTrue);
    // Standing apart is worth more than a bigger stat.
    final strong = SkyContest(lake, [
      _f('p', element: 'Plant', v: 5.5, player: true),
      _f('a', element: 'Air', family: 'mask', v: 3),
      _f('s', element: 'Spirit', family: 'let', v: 3.5),
    ]);
    expect(strong.standings.first, 2);
  });

  test('the fusion sky lights what fuses, and dims what does not', () {
    const sky = SkyBout(SkyNight.fusion, 3);
    final els = sky.elements;
    // Fire into a Water sky would burn as Steam; here Earth into the
    // Lightning sky makes Crystal, and Fire has no recipe with it.
    final n = SkyContest(sky, [
      _f('e', element: 'Earth', player: true),
      _f('f', element: 'Fire'),
      _f('d', element: 'Dark'),
    ]);
    final first = n.casts.where((c) => c.round == 0).toList();
    final earth = first.firstWhere((c) => c.fighter == 0);
    final fire = first.firstWhere((c) => c.fighter == 1);
    expect(earth.sky, els[0]);
    expect(earth.made, raceFusion('Earth', els[0]));
    expect(earth.made, isNotNull);
    expect(fire.made, isNull);
    expect(earth.stars, greaterThan(fire.stars));
    // No element fuses with every round's sky; some fuse with two, each
    // pair of rounds wanted by a different one.
    const all = [
      'Fire', 'Water', 'Earth', 'Air', 'Steam', 'Lava', 'Lightning', 'Mud', //
      'Ice', 'Dust', 'Crystal', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
      'Blood',
    ];
    final pairs = <String>{};
    for (final e in all) {
      final fuses = [
        for (var r = 0; r < els.length; r++)
          if (raceFusion(e, els[r]) != null) r,
      ];
      expect(fuses.length, lessThan(els.length), reason: e);
      if (fuses.length == 2) pairs.add(fuses.join());
    }
    expect(pairs, {'01', '02', '12'});
  });

  // Who can win each Sapphire bout: every catalog species at level 10, all
  // four Potentials alike (and with Enhancement ranks, eN). For the Mirror
  // Lake and the Fusion Sky, the right kind (colours apart from both
  // rivals'; fuses with the sky on most rounds) against everyone else.
  // Targets (the author, 2026-10-18): the Clear Night as it was (P80 ≈ 66%,
  // P90 ≈ 95%); the right kind ~40–60% at P90e5 and ~70–85% at P95e10; the
  // wrong kind ≤ ~20% at P100e10.
  //
  //   SKY_CATALOG=1 flutter test test/sky_rules_test.dart \
  //     --plain-name 'catalog balance'
  test('catalog balance', () {
    if (Platform.environment['SKY_CATALOG'] == null) return;
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
    Racer me(Creature c, int p, int e) {
      final s = c.baseStats!;
      return Racer(
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
      );
    }

    final cup = kGemCups[1];
    String pct(Iterable<bool> wins) {
      final l = wins.toList();
      return l.isEmpty
          ? '-'
          : '${(100 * l.where((w) => w).length / l.length).round()}%';
    }

    const grid = [
      (60, 0),
      (70, 0),
      (80, 0),
      (90, 0),
      (100, 0),
      (90, 5),
      (95, 10),
      (100, 10),
    ];
    final sweep = <String, int>{};
    for (var b = 0; b < cup.bouts.length; b++) {
      final line = StringBuffer('${cup.name} ${cup.bouts[b].name}:');
      // SKY_FORMS=0.9,1,1 tries other forms.
      final forms = Platform.environment['SKY_FORMS']?.split(',');
      final form = forms != null ? double.parse(forms[b]) : cup.rivalForm[b];
      final rivals = [for (final r in cup.rivalsOf(b)) gemRivalRacer(r, form)];
      final bout = skyBoutOf(cup.bouts[b]);
      final probe = SkyContest(bout, [rivals.first, ...rivals]);
      line.write(' rivals ${probe.starsOf(1)}/${probe.starsOf(2)} ·');
      bool wins(Creature c, int p, int e) =>
          SkyContest(bout, [me(c, p, e), ...rivals]).standings.first == 0;
      for (final (p, e) in grid) {
        line.write(
          ' P$p${e > 0 ? 'e$e' : ''} ${pct(species.map((c) => wins(c, p, e)))}',
        );
      }
      // ignore: avoid_print
      print(line);
      // The twists: the right kind for the night against everyone else.
      final right = _rightKind(bout, [for (final r in rivals) r.entrant]);
      if (right != null) {
        final yes = species.where((c) => right(c.types.first)).toList();
        final no = species.where((c) => !right(c.types.first)).toList();
        final out = StringBuffer(
          '    right kind (${yes.length}: '
          '${{for (final c in yes) c.types.first}.join(' ')}):',
        );
        for (final (p, e) in grid.skip(3)) {
          out.write(
            ' P$p${e > 0 ? 'e$e' : ''} ${pct(yes.map((c) => wins(c, p, e)))}',
          );
        }
        out.write('  | others (${no.length}):');
        for (final (p, e) in grid.skip(3)) {
          out.write(
            ' P$p${e > 0 ? 'e$e' : ''} ${pct(no.map((c) => wins(c, p, e)))}',
          );
        }
        // ignore: avoid_print
        print(out);
        final strong = [
          for (final c in no)
            if (wins(c, 100, 10)) '${c.name}(${c.types.first})',
        ];
        // ignore: avoid_print
        print('    others winning at P100e10: ${strong.join(' ')}');
      }
      for (final c in species) {
        if (wins(c, 95, 10)) sweep[c.name] = (sweep[c.name] ?? 0) + 1;
      }
    }
    final all = [
      for (final e in sweep.entries)
        if (e.value == cup.bouts.length) e.key,
    ];
    // ignore: avoid_print
    print('${cup.name} won whole at P95e10 by ${all.length}: $all');
  });
}

/// Who is the right kind for a twist night, by element; null for a plain
/// night.
bool Function(String element)? _rightKind(
  SkyBout bout,
  List<ContestEntrant> rivals,
) => switch (bout.night) {
  SkyNight.clear => null,
  // Its colours stand apart from both rivals'.
  SkyNight.mirror => (e) => rivals.every(
    (r) => skyColoursOf(r.element) != skyColoursOf(e),
  ),
  // It fuses with the sky on most rounds.
  SkyNight.fusion =>
    (e) =>
        bout.elements.where((s) => raceFusion(e, s) != null).length * 2 >
        bout.elements.length,
};
