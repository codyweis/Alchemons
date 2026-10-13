// lib/games/stadium/sky_rules.dart
//
// THE NIGHT SKY (the Sapphire Cup; the author, 2026-10-12: "an ability
// measuring contest ... creative and beautiful", picked over a glass gauge
// and a still lake; the player just watches). Three Alchemons stand on a
// ridge under a dark sky, each with its own figure hung faint above it in
// stars. Four rounds, one for each stat; in each, every one of the three
// lets its special loose up into the sky — the same handful of grains for
// all — and as many as the judges give it catch and light stars in its
// figure. The rest drift on and go out. After the fourth round, the most
// stars lit wins.
//
// Each cast is judged as the race judges a leg (judgeEntrant on the round's
// stat, under the night's condition). Nothing is left to chance and there
// is nothing to tap: the same three under the same sky light the same
// stars.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

/// The grains every cast lets loose; the most stars one cast can light.
const int kSkyCastGrains = 30;

/// Stars lit for each point the judges give a cast.
const double kSkyStarsPerPoint = 4.2;

/// The rounds, in order: one for each stat.
const List<CosmicContestTrait> kSkyRounds = [
  CosmicContestTrait.speed,
  CosmicContestTrait.strength,
  CosmicContestTrait.intelligence,
  CosmicContestTrait.beauty,
];

/// The stars in each one's figure: every grain of every round.
const int kSkyFigureStars = kSkyCastGrains * 4;

/// What the night is like.
enum SkyNight {
  /// Clear, with a moon: judged as usual.
  clear,

  /// No moon: what shines by its own light shows best in the beauty round.
  newMoon,

  /// The sky moving with the lights: the quick ride them in the speed
  /// round.
  aurora,
}

/// The night a Sapphire Cup bout is held under.
SkyBout skyBoutOf(GemBout bout) => SkyBout(
  SkyNight.values.firstWhere(
    (n) => n.name == bout.place,
    orElse: () => SkyNight.clear,
  ),
  bout.level,
);

class SkyBout {
  const SkyBout(this.night, this.level);

  final SkyNight night;
  final int level;

  ContestCondition condition(CosmicContestTrait trait) =>
      switch ((night, trait)) {
        (SkyNight.newMoon, CosmicContestTrait.beauty) => _noMoon,
        (SkyNight.aurora, CosmicContestTrait.speed) => _aurora,
        _ => contestCondition(trait, level),
      };
}

const _noMoon = ContestCondition(
  title: 'NO MOON',
  line: 'A night with no moon.',
  elementAdd: {
    'Light': 0.45,
    'Fire': 0.3,
    'Lightning': 0.3,
    'Lava': 0.25,
    'Spirit': 0.25,
    'Crystal': 0.15,
    'Dark': -0.3,
    'Mud': -0.2,
  },
  good: 'shines in the dark',
  bad: 'is lost in the dark',
);

const _aurora = ContestCondition(
  title: 'AURORA',
  line: 'The sky is moving.',
  elementAdd: {
    'Air': 0.4,
    'Lightning': 0.4,
    'Ice': 0.25,
    'Light': 0.2,
    'Mud': -0.3,
    'Earth': -0.2,
  },
  familyAdd: {'wing': 0.25, 'horn': -0.15},
  good: 'rides the lights',
  bad: 'is left behind',
);

/// One cast: who, in which round, how it was judged and the stars it lit.
class SkyCast {
  const SkyCast(this.fighter, this.round, this.verdict, this.stars);

  final int fighter, round;
  final ContestVerdict verdict;
  final int stars;
}

/// A whole night, worked out at once.
class SkyContest {
  SkyContest(this.bout, this.fighters, {this.last = 0})
    : assert(fighters.length >= 2) {
    for (var r = 0; r < kSkyRounds.length; r++) {
      for (final i in castOrder) {
        final v = judge(fighters[i], r);
        casts.add(SkyCast(i, r, v, starsFor(v.score)));
      }
    }
  }

  final SkyBout bout;
  final List<Racer> fighters;
  final List<SkyCast> casts = [];

  /// Who casts last in each round: the player watching.
  final int last;

  /// Who casts when in each round: the others first, the player ([last])
  /// last, so the player sees what it has to beat. (Only the show's order:
  /// the stars are the same whoever watches.)
  List<int> get castOrder => [
    for (var i = 0; i < fighters.length; i++)
      if (i != last) i,
    last,
  ];

  /// How [r] is judged in round [round].
  ContestVerdict judge(Racer r, int round) {
    final trait = kSkyRounds[round];
    return judgeEntrant(
      trait,
      bout.level,
      r.entrant.withRating(r.ratings[trait] ?? 1),
      condition: bout.condition(trait),
    );
  }

  /// The stars a cast the judges give [score] lights.
  static int starsFor(double score) =>
      (score * kSkyStarsPerPoint).round().clamp(0, kSkyCastGrains);

  /// Stars [i] has lit after the first [castsDone] casts of the night.
  int starsOf(int i, [int? castsDone]) {
    var n = 0;
    final upTo = castsDone ?? casts.length;
    for (var k = 0; k < upTo && k < casts.length; k++) {
      if (casts[k].fighter == i) n += casts[k].stars;
    }
    return n;
  }

  /// Everything the judges gave [i], to part a tie on stars.
  double scoreOf(int i) => casts
      .where((c) => c.fighter == i)
      .fold(0.0, (s, c) => s + c.verdict.score);

  /// The three, the most stars first (a tie goes to the better judged).
  List<int> get standings {
    final order = [for (var i = 0; i < fighters.length; i++) i];
    order.sort((a, b) {
      final c = starsOf(b).compareTo(starsOf(a));
      if (c != 0) return c;
      final d = scoreOf(b).compareTo(scoreOf(a));
      return d != 0 ? d : a.compareTo(b);
    });
    return order;
  }
}
