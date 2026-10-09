// Trait contests are judged by rules, not dice — and the rules make
// different Alchemons the right pick for different levels.
//
// CONTEST_REPORT=1 prints, per level, what each archetype needs to win.

import 'dart:io';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:flutter_test/flutter_test.dart';

/// A spread of the kinds of creature a party might bring, all with the same
/// stat so only what they are decides between them.
const _archetypes = <ContestEntrant>[
  ContestEntrant(
    name: 'Lightning let',
    element: 'Lightning',
    family: 'let',
    statRating: 0,
    scale: 0.85,
  ),
  ContestEntrant(
    name: 'Water pip',
    element: 'Water',
    family: 'pip',
    statRating: 0,
    scale: 0.9,
  ),
  ContestEntrant(
    name: 'Air wing',
    element: 'Air',
    family: 'wing',
    statRating: 0,
  ),
  ContestEntrant(
    name: 'Earth horn',
    element: 'Earth',
    family: 'horn',
    statRating: 0,
    scale: 1.3,
  ),
  ContestEntrant(
    name: 'Lava mane',
    element: 'Lava',
    family: 'mane',
    statRating: 0,
    scale: 1.2,
  ),
  ContestEntrant(
    name: 'Fire kin',
    element: 'Fire',
    family: 'kin',
    statRating: 0,
  ),
  ContestEntrant(
    name: 'Crystal mask',
    element: 'Crystal',
    family: 'mask',
    statRating: 0,
  ),
  ContestEntrant(
    name: 'Spirit mask',
    element: 'Spirit',
    family: 'mask',
    statRating: 0,
    elementKinds: 3,
    familyKinds: 3,
    generations: 4,
  ),
  ContestEntrant(
    name: 'Light wing (prismatic)',
    element: 'Light',
    family: 'wing',
    statRating: 0,
    prismatic: true,
  ),
  ContestEntrant(
    name: 'Poison kin',
    element: 'Poison',
    family: 'kin',
    statRating: 0,
  ),
];

ContestEntrant _withStat(ContestEntrant e, double rating) => ContestEntrant(
  name: e.name,
  element: e.element,
  family: e.family,
  statRating: rating,
  scale: e.scale,
  prismatic: e.prismatic,
  effect: e.effect,
  variant: e.variant,
  tinted: e.tinted,
  pureElement: e.pureElement,
  pureFamily: e.pureFamily,
  speciesPure: e.speciesPure,
  elementKinds: e.elementKinds,
  factionKinds: e.factionKinds,
  familyKinds: e.familyKinds,
  generations: e.generations,
);

void main() {
  final report = Platform.environment['CONTEST_REPORT'] != null;

  test('the same entrant always scores the same', () {
    final e = _withStat(_archetypes.first, 3.4);
    for (final trait in CosmicContestTrait.values) {
      for (var level = 1; level <= 5; level++) {
        final a = judgeEntrant(trait, level, e, rivalElement: 'Fire').score;
        final b = judgeEntrant(trait, level, e, rivalElement: 'Fire').score;
        expect(a, b);
      }
    }
  });

  test('intuition holds: lightning is quick, horns are strong, crystal '
      'catches the eye, spirit is sharp', () {
    double s(CosmicContestTrait t, ContestEntrant e) =>
        judgeEntrant(t, 1, _withStat(e, 3)).score;
    final lightning = _archetypes[0], earthHorn = _archetypes[3];
    final crystal = _archetypes[6], spirit = _archetypes[7];
    expect(
      s(CosmicContestTrait.speed, lightning),
      greaterThan(s(CosmicContestTrait.speed, earthHorn)),
    );
    expect(
      s(CosmicContestTrait.strength, earthHorn),
      greaterThan(s(CosmicContestTrait.strength, lightning)),
    );
    expect(
      s(CosmicContestTrait.beauty, crystal),
      greaterThan(s(CosmicContestTrait.beauty, _archetypes.last)),
    );
    expect(
      s(CosmicContestTrait.intelligence, spirit),
      greaterThan(s(CosmicContestTrait.intelligence, _archetypes[4])),
    );
  });

  test('different levels favour different creatures', () {
    for (final trait in CosmicContestTrait.values) {
      final leaders = <String>{};
      for (var level = 1; level <= 5; level++) {
        final rival = kCosmicContestLevels[trait]![level - 1].opponent;
        final ranked = [
          for (final e in _archetypes)
            (
              e.name,
              judgeEntrant(
                trait,
                level,
                _withStat(e, 3),
                rivalElement: rival.element,
              ).score,
            ),
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        leaders.add(ranked.first.$1);
        if (report) {
          final rivalScore = judgeRival(trait, level, rival).score;
          // ignore: avoid_print
          print(
            '${trait.name} L$level ${contestCondition(trait, level).title}'
            ' vs ${rival.name} (${rivalScore.toStringAsFixed(2)}):',
          );
          for (final (name, score) in ranked) {
            // The stat rating this creature needs to win here.
            final need = rivalScore - (score - 3);
            // ignore: avoid_print
            print(
              '   ${name.padRight(24)} needs stat ${need.toStringAsFixed(2)}',
            );
          }
        }
      }
      expect(
        leaders.length,
        greaterThanOrEqualTo(2),
        reason: '${trait.name}: one creature leads every level ($leaders)',
      );
    }
  });

  test('every rule the judges apply shows on the scorecard', () {
    final e = _withStat(_archetypes[3], 3.2);
    for (final trait in CosmicContestTrait.values) {
      for (var level = 1; level <= 5; level++) {
        final v = judgeEntrant(trait, level, e, rivalElement: 'Water');
        final bonus = v.factors.fold<double>(0, (s, f) => s + f.delta);
        expect(
          v.score,
          closeTo(
            (3.2 + bonus.clamp(kContestBonusFloor, kContestBonusCeiling)),
            1e-9,
          ),
        );
        for (final f in v.factors) {
          expect(f.text.trim(), isNotEmpty);
          expect(f.text.endsWith('· '), isFalse, reason: f.text);
        }
      }
    }
  });

  test('what the lore notes claim is what the judges do', () {
    double el(CosmicContestTrait t, String e, [int level = 1]) => judgeEntrant(
      t,
      level,
      ContestEntrant(name: e, element: e, family: 'pip', statRating: 3),
    ).score;
    double fam(CosmicContestTrait t, String f, [int level = 1]) => judgeEntrant(
      t,
      level,
      ContestEntrant(name: f, element: 'Plant', family: f, statRating: 3),
    ).score;
    double size(CosmicContestTrait t, double s, [int level = 1]) =>
        judgeEntrant(
          t,
          level,
          ContestEntrant(
            name: '$s',
            element: 'Plant',
            family: 'pip',
            statRating: 3,
            scale: s,
          ),
        ).score;
    const speed = CosmicContestTrait.speed,
        strength = CosmicContestTrait.strength;
    const beauty = CosmicContestTrait.beauty,
        mind = CosmicContestTrait.intelligence;

    // "Lightning runs fastest, then water and ice. Mud is slowest of all."
    expect(el(speed, 'Lightning'), greaterThan(el(speed, 'Water')));
    expect(el(speed, 'Water'), greaterThan(el(speed, 'Ice')));
    for (final e in ['Fire', 'Earth', 'Lava', 'Plant', 'Air']) {
      expect(el(speed, 'Mud'), lessThan(el(speed, e)), reason: e);
    }
    // "Wings are built for speed. Horns are not."
    expect(fam(speed, 'wing'), greaterThan(fam(speed, 'pip')));
    expect(fam(speed, 'horn'), lessThan(fam(speed, 'pip')));
    // "Small frames are nimble on the track. Big ones are heavy."
    expect(size(speed, 0.8), greaterThan(size(speed, 1)));
    expect(size(speed, 1.3), lessThan(size(speed, 1)));
    // "When it rains, water and ice glide. Fire and earth bog down."
    expect(el(speed, 'Water', 2) - el(speed, 'Water'), greaterThan(0));
    expect(el(speed, 'Fire', 2) - el(speed, 'Fire'), lessThan(0));
    // "In the storm lane, lightning and air ride the weather, and wings."
    expect(el(speed, 'Air', 3), greaterThan(el(speed, 'Air')));
    expect(fam(speed, 'wing', 3), greaterThan(fam(speed, 'wing')));
    // "On the switchback, kin, pips and lets take the turns. Wings overshoot."
    expect(fam(speed, 'kin', 4), greaterThan(fam(speed, 'kin')));
    expect(fam(speed, 'wing', 4), lessThan(fam(speed, 'wing')));

    // "Earth is strongest, then lava and fire. Air is weakest."
    expect(el(strength, 'Earth'), greaterThan(el(strength, 'Lava')));
    expect(el(strength, 'Lava'), greaterThan(el(strength, 'Fire')));
    for (final e in ['Water', 'Plant', 'Spirit', 'Earth']) {
      expect(el(strength, 'Air'), lessThan(el(strength, e)), reason: e);
    }
    // "Horns and manes are the strongest lines."
    for (final f in ['kin', 'pip', 'wing', 'let', 'mask']) {
      expect(fam(strength, 'mane'), greaterThan(fam(strength, f)), reason: f);
    }
    // "Big frames carry mass. In the heavyweight round, size counts most."
    expect(size(strength, 1.3), greaterThan(size(strength, 1)));
    expect(
      size(strength, 1.3, 3) - size(strength, 1, 3),
      greaterThan(size(strength, 1.3) - size(strength, 1)),
    );
    // "The molten ring suits fire and lava. Ice and plants wilt."
    expect(el(strength, 'Fire', 2), greaterThan(el(strength, 'Fire')));
    expect(el(strength, 'Plant', 2), lessThan(el(strength, 'Plant')));
    // "In the leverage bout technique beats bulk."
    expect(fam(strength, 'mask', 4), greaterThan(fam(strength, 'horn', 4)));

    // "Crystal and light catch the eye. Poison and blood do not."
    expect(el(beauty, 'Crystal'), greaterThan(el(beauty, 'Fire')));
    expect(el(beauty, 'Poison'), lessThan(el(beauty, 'Plant')));
    // "Under moonlight, silver, blue and shadow are lovely. Fire and light look harsh."
    expect(el(beauty, 'Dark', 3), greaterThan(el(beauty, 'Light', 3)));
    // "In the contrast rounds, wear different colors from the rival."
    final same = judgeEntrant(
      beauty,
      2,
      const ContestEntrant(
        name: 'a',
        element: 'Fire',
        family: 'pip',
        statRating: 3,
      ),
      rivalElement: 'Fire',
    ).score;
    final apart = judgeEntrant(
      beauty,
      2,
      const ContestEntrant(
        name: 'a',
        element: 'Water',
        family: 'pip',
        statRating: 3,
      ),
      rivalElement: 'Fire',
    ).score;
    expect(apart, greaterThan(same));

    // "Spirit, light, dark and crystal are sharpest. Lava and mud are muddled."
    expect(el(mind, 'Spirit'), greaterThan(el(mind, 'Fire')));
    expect(el(mind, 'Lava'), lessThan(el(mind, 'Fire')));
    // "Masks and kin are the sharpest lines."
    expect(fam(mind, 'mask'), greaterThan(fam(mind, 'horn')));
    // "Pattern rounds favour crystal and masks."
    expect(el(mind, 'Crystal', 3), greaterThan(el(mind, 'Crystal')));
    // "In every final, everything that counts counts for more."
    expect(
      el(speed, 'Lightning', 5) - 3,
      greaterThan(el(speed, 'Lightning') - 3),
    );
  });
}
