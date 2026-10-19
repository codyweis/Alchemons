// lib/games/stadium/sky_rules.dart
//
// THE NIGHT SKY (the Sapphire Cup; the author, 2026-10-12: "an ability
// measuring contest ... creative and beautiful", picked over a glass gauge
// and a still lake; the player just watches). Three Alchemons stand on a
// ridge under a dark sky, each with its own figure hung faint above it in
// stars. Three rounds, each judged on one stat; in each, every one of the
// three lets its special loose up into the sky — the same handful of grains
// for all — and as many as the judges give it catch and light stars in its
// figure. The rest drift on and go out. After the last round, the most
// stars lit wins.
//
// Three nights (the author, 2026-10-18: the bouts were "too repetitive",
// the same night re-coloured, four identical rounds each):
//   · CLEAR NIGHT — the night plain.
//   · MIRROR LAKE — the sky shows in a still lake below. A cast whose
//     colours (its element's group) stand apart from the other two lights
//     twice, in the sky and in the water; one that shares another's colours
//     is drowned out, and lights only in the sky.
//   · FUSION SKY — each round the sky holds an element, known before the
//     start ([SkyBout.elements]). A cast that fuses with it by the recipe
//     table lights brightly as what the two make (Fire into a Water sky
//     burns as Steam); one with no recipe goes up dim. Judged as a race's
//     fusion station is (fusionFactor), only harder.
// Each twist wants its own kind of Alchemon, so no one of them wins all
// three nights by its stats alone.
//
// Each cast is judged as the race judges a leg (judgeEntrant on the round's
// stat). Nothing is left to chance and there is nothing to tap: the same
// three under the same sky light the same stars.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/models/elemental_group.dart';

/// The grains every cast lets loose; the most stars one cast can light.
const int kSkyCastGrains = 40;

/// Stars lit for each point the judges give a cast (the most a cast can be
/// judged, kContestScoreMax, lights nearly all its grains).
const double kSkyStarsPerPoint = 4.2;

/// Rounds in a night.
const int kSkyRoundCount = 3;

/// The stars in each one's figure: every grain of every round.
const int kSkyFigureStars = kSkyCastGrains * kSkyRoundCount;

/// How much the Fusion Sky's recipes count, as a race's fusion station's
/// ground (a recipe +0.5 a time, none −0.4).
const double kSkyFusionGround = 3.4;

/// What the night is like: the stat each round is judged on, and what the
/// sky holds in each.
enum SkyNight {
  /// The night plain.
  clear([
    CosmicContestTrait.speed,
    CosmicContestTrait.strength,
    CosmicContestTrait.beauty,
  ]),

  /// A still lake below that doubles a cast standing apart.
  mirror([
    CosmicContestTrait.speed,
    CosmicContestTrait.intelligence,
    CosmicContestTrait.beauty,
  ]),

  /// A sky holding an element each round. Lightning, then Dark, then Light:
  /// Earth fuses with the first and the last, Plant with the first two,
  /// Dark and Light with the last two (Dark into Light burns as Blood), and
  /// nothing fuses with all three.
  fusion(
    [
      CosmicContestTrait.strength,
      CosmicContestTrait.intelligence,
      CosmicContestTrait.beauty,
    ],
    ['Lightning', 'Dark', 'Light'],
  );

  const SkyNight(this.rounds, [this.elements = const []]);

  final List<CosmicContestTrait> rounds;

  /// The sky's element in each round, in order (none on a plain night).
  final List<String> elements;
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

  /// The bout's level. The judging is plain on every night — only the
  /// night's own rule tilts it; how hard it is is the rivals' form.
  final int level;

  /// The stat each round is judged on, in order.
  List<CosmicContestTrait> get rounds => night.rounds;

  /// The sky's element for each round in order: what to fuse with in the
  /// Fusion Sky, shown before the pick. Empty on the other nights.
  List<String> get elements => night.elements;

  /// The sky's element in [round], if it holds one.
  String? skyOf(int round) =>
      round < night.elements.length ? night.elements[round] : null;

  /// Whether the lake doubles a cast that stands apart.
  bool get lake => night == SkyNight.mirror;

  ContestCondition condition(CosmicContestTrait trait) =>
      contestCondition(trait, 1);
}

/// The colours an element shows: its group (Fire, Lava and Lightning are
/// one; Air, Plant and Poison another).
Object skyColoursOf(String element) {
  final e = element.isEmpty
      ? element
      : element[0].toUpperCase() + element.substring(1).toLowerCase();
  for (final g in ElementalGroup.values) {
    if (g.elementTypes.contains(e)) return g;
  }
  return e;
}

/// One cast: who, in which round, how it was judged and the stars it lit.
class SkyCast {
  const SkyCast(
    this.fighter,
    this.round,
    this.verdict,
    this.stars, {
    this.water = 0,
    this.sky,
    this.made,
  });

  final int fighter, round;
  final ContestVerdict verdict;

  /// Stars lit in its figure in the sky.
  final int stars;

  /// Stars its reflection lit in the lake (the Mirror Lake: as many again
  /// for a cast standing apart, none for one drowned out).
  final int water;

  /// The round's element (the Fusion Sky), and what the cast made with it
  /// (null: no recipe, it went up dim).
  final String? sky, made;

  int get total => stars + water;
}

/// A whole night, worked out at once.
class SkyContest {
  SkyContest(this.bout, this.fighters, {this.last = 0})
    : assert(fighters.length >= 2) {
    for (var r = 0; r < bout.rounds.length; r++) {
      final sky = bout.skyOf(r);
      for (final i in castOrder) {
        final v = judge(fighters[i], r);
        final stars = starsFor(v.score);
        casts.add(
          SkyCast(
            i,
            r,
            v,
            stars,
            water: bout.lake && apart(i) ? stars : 0,
            sky: sky,
            made: sky == null
                ? null
                : raceFusion(fighters[i].entrant.element, sky),
          ),
        );
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

  /// Whether [i]'s colours stand apart from every other's (the Mirror
  /// Lake: its cast lights again in the water).
  bool apart(int i) {
    final mine = skyColoursOf(fighters[i].entrant.element);
    for (var j = 0; j < fighters.length; j++) {
      if (j != i && skyColoursOf(fighters[j].entrant.element) == mine) {
        return false;
      }
    }
    return true;
  }

  /// How [r] is judged in round [round]: on the round's stat, and in the
  /// Fusion Sky on whether it fuses with the round's element.
  ContestVerdict judge(Racer r, int round) {
    final trait = bout.rounds[round];
    final v = judgeEntrant(
      trait,
      bout.level,
      r.entrant.withRating(r.ratings[trait] ?? 1),
      condition: bout.condition(trait),
    );
    final sky = bout.skyOf(round);
    if (sky == null) return v;
    final f = fusionFactor(r.entrant.element, sky, ground: kSkyFusionGround);
    return ContestVerdict(
      (v.score + f.delta).clamp(0.0, kContestScoreMax).toDouble(),
      [...v.factors, f]..sort((a, b) => b.delta.abs().compareTo(a.delta.abs())),
    );
  }

  /// The stars a cast the judges give [score] lights.
  static int starsFor(double score) =>
      (score * kSkyStarsPerPoint).round().clamp(0, kSkyCastGrains);

  /// Stars [i] has lit, sky and water, after the first [castsDone] casts of
  /// the night.
  int starsOf(int i, [int? castsDone]) {
    var n = 0;
    final upTo = castsDone ?? casts.length;
    for (var k = 0; k < upTo && k < casts.length; k++) {
      if (casts[k].fighter == i) n += casts[k].total;
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
