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
    expect(night.casts.length, 3 * kSkyRounds.length);
    for (var r = 0; r < kSkyRounds.length; r++) {
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
        CosmicContestTrait.strength: 2,
        CosmicContestTrait.intelligence: 2,
        CosmicContestTrait.beauty: 2,
      },
    );
    final night = SkyContest(clear, [quick, _f('b'), _f('c')]);
    final cast = night.casts.where((c) => c.fighter == 0).toList();
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

  test('the night tilts its round', () {
    final light = _f('l', element: 'Light', family: 'kin');
    final dark = _f('d', element: 'Dark', family: 'kin');
    const moonless = SkyBout(SkyNight.newMoon, 2);
    final n = SkyContest(moonless, [light, dark, _f('c')]);
    final beauty = kSkyRounds.indexOf(CosmicContestTrait.beauty);
    double score(int i) => n.casts
        .firstWhere((c) => c.fighter == i && c.round == beauty)
        .verdict
        .score;
    expect(score(0), greaterThan(score(1)));
  });

  // Who can win each Sapphire bout: every catalog species at level 10.
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
    double rate(int base, int p) => AlchemonStatSystem.legacyGameplayRating(
      AlchemonStatSystem.effectiveInternal(
        speciesBase: base,
        level: 10,
        potential: p,
      ),
    );
    final cup = kGemCups[1];
    for (var b = 0; b < cup.bouts.length; b++) {
      final line = StringBuffer('${cup.name} ${cup.bouts[b].name}:');
      // SKY_FORMS=0.9,1,1 tries other forms.
      final forms = Platform.environment['SKY_FORMS']?.split(',');
      final form = forms != null ? double.parse(forms[b]) : cup.rivalForm[b];
      final rivals = [for (final r in cup.rivalsOf(b)) gemRivalRacer(r, form)];
      final probe = SkyContest(skyBoutOf(cup.bouts[b]), [
        rivals.first,
        ...rivals,
      ]);
      line.write(' rivals ${probe.starsOf(1)}/${probe.starsOf(2)} ·');
      for (final p in [60, 70, 80, 90, 100]) {
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
          );
          final night = SkyContest(skyBoutOf(cup.bouts[b]), [me, ...rivals]);
          if (night.standings.first == 0) n++;
        }
        line.write(' P$p ${(100 * n / species.length).round()}%');
      }
      // ignore: avoid_print
      print(line);
    }
  });
}
