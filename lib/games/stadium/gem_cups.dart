// lib/games/stadium/gem_cups.dart
//
// The Trials' gem cups (the author, 2026-10-12): Ruby, Sapphire and
// Emerald, opened by winning the Silver Cup, one after another. Each is its
// own event, fought one against two — the island (Ruby: the last one
// standing on a crumbling island), the night sky (Sapphire: each lets its
// special loose into the sky, and the most stars lit wins) and the space
// course (Emerald: a course through space, its route planned before the
// start) — in three bouts, each against two of the cup's rivals.
//
// A cup's first bout is its event plain; the other two each turn it with a
// rule of their own (the author, 2026-10-18: the cups were "too
// repetitive", three of the same with new colours). Ruby: the Molten Heart
// (the island melts from its middle, so the fight is on a ring) and the
// Stepping Stones (three stones drift apart and back). Sapphire: the Mirror
// Lake (a cast that stands apart from the others' colours lights twice) and
// the Fusion Sky (each round's sky holds an element to fuse with). Emerald:
// the Gravity Chain (each sling flings faster the cleaner the last) and the
// Element Gates (the forks are gates to fuse through). Each favours its own
// kind of Alchemon, so no one of them wins them all.
//
// Their wins are kept with the races' (RaceProgress, by cup id).

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

/// What a gem cup's bouts are.
enum GemEvent {
  island('THE ISLAND', 'Last one standing on a crumbling island.'),
  sky('THE NIGHT SKY', 'Light the most stars.'),
  flight('THE SPACE COURSE', 'Plan a route through space, then fly it.');

  const GemEvent(this.title, this.line);
  final String title, line;
}

class GemBout {
  const GemBout({
    required this.id,
    required this.name,
    required this.place,
    required this.level,
    required this.rivals,
    this.line = '',
  });

  final String id, name;

  /// One plain line of what is different about it (the hub shows it in
  /// place of the event's own line); empty for a cup's plain first bout.
  final String line;

  /// Where it is fought, in the event's own terms (an island's kind).
  final String place;

  /// How hard it is judged, 1..3.
  final int level;

  /// The two of the cup's rivals it is fought against.
  final List<int> rivals;
}

class GemCup {
  const GemCup({
    required this.id,
    required this.name,
    required this.event,
    required this.rivals,
    required this.bouts,
    required this.gold,
    this.rivalForm = const [1, 1, 1],
  });

  final String id, name;
  final GemEvent event;
  final List<RaceRival> rivals;
  final List<GemBout> bouts;

  /// Gold for the first win of each bout.
  final List<int> gold;

  /// How hard the rivals go each bout, as a multiple of their stats.
  final List<double> rivalForm;

  /// Bout [b]'s two rivals.
  List<RaceRival> rivalsOf(int b) => [
    for (final i in bouts[b].rivals) rivals[i],
  ];
}

const List<GemCup> kGemCups = [
  GemCup(
    id: 'ruby',
    name: 'Ruby Cup',
    event: GemEvent.island,
    gold: [3, 4, 5],
    // The Molten Heart's two go harder: the heat already tells against
    // most of those who come (island_rules.dart).
    rivalForm: [1.02, 1.16, 1.0],
    rivals: [
      RaceRival(
        name: 'Lavahorn',
        element: 'Lava',
        family: 'horn',
        speed: 4.5,
        strength: 5.9,
        intelligence: 4.2,
        beauty: 4.1,
        scale: 1.15,
      ),
      RaceRival(
        name: 'Crystalkin',
        element: 'Crystal',
        family: 'kin',
        speed: 4.4,
        strength: 5.3,
        intelligence: 5.3,
        beauty: 4.7,
        canny: true,
      ),
      RaceRival(
        name: 'Spiritwing',
        element: 'Spirit',
        family: 'wing',
        speed: 5.4,
        strength: 4.6,
        intelligence: 5.2,
        beauty: 5.4,
        canny: true,
      ),
      RaceRival(
        name: 'Mudhorn',
        element: 'Mud',
        family: 'horn',
        speed: 4.6,
        strength: 5.8,
        intelligence: 4.6,
        beauty: 4.2,
        scale: 1.1,
        canny: true,
      ),
    ],
    bouts: [
      GemBout(
        id: 'sand_island',
        name: 'Sand Island',
        place: 'sand',
        level: 1,
        rivals: [0, 1],
      ),
      GemBout(
        id: 'molten_heart',
        name: 'Molten Heart',
        place: 'molten',
        level: 2,
        line: 'The island melts from its middle.',
        rivals: [0, 3],
      ),
      GemBout(
        id: 'stepping_stones',
        name: 'Stepping Stones',
        place: 'stones',
        level: 3,
        line: 'Three stones drift apart and back.',
        rivals: [2, 3],
      ),
    ],
  ),
  GemCup(
    id: 'sapphire',
    name: 'Sapphire Cup',
    event: GemEvent.sky,
    gold: [4, 5, 6],
    // The Clear Night as it was; the Mirror Lake's and the Fusion Sky's
    // rivals strong enough that only the right kind beats them (test/
    // sky_rules_test.dart 'catalog balance').
    rivalForm: [0.985, 1.03, 1.295],
    rivals: [
      RaceRival(
        name: 'Lightningpip',
        element: 'Lightning',
        family: 'pip',
        speed: 6.0,
        strength: 4.4,
        intelligence: 5.2,
        beauty: 4.8,
        canny: true,
      ),
      RaceRival(
        name: 'Airmask',
        element: 'Air',
        family: 'mask',
        speed: 5.8,
        strength: 4.2,
        intelligence: 5.6,
        beauty: 5.0,
        canny: true,
      ),
      RaceRival(
        name: 'Spiritlet',
        element: 'Spirit',
        family: 'let',
        speed: 5.4,
        strength: 4.6,
        intelligence: 6.0,
        beauty: 5.6,
        canny: true,
      ),
      RaceRival(
        name: 'Steamhorn',
        element: 'Steam',
        family: 'horn',
        speed: 5.0,
        strength: 6.0,
        intelligence: 4.8,
        beauty: 4.6,
        scale: 1.1,
        canny: true,
      ),
    ],
    bouts: [
      GemBout(
        id: 'clear_night',
        name: 'Clear Night',
        place: 'clear',
        level: 1,
        rivals: [0, 3],
      ),
      GemBout(
        id: 'mirror_lake',
        name: 'Mirror Lake',
        place: 'mirror',
        level: 2,
        line: 'A still lake below shows the sky.',
        rivals: [1, 2],
      ),
      GemBout(
        id: 'fusion_sky',
        name: 'Fusion Sky',
        place: 'fusion',
        level: 3,
        line: 'Each round, the sky holds an element.',
        rivals: [0, 2],
      ),
    ],
  ),
  GemCup(
    id: 'emerald',
    name: 'Emerald Cup',
    event: GemEvent.flight,
    gold: [5, 6, 8],
    // The Gravity Chain's two sling as well as they fly, so they go easier;
    // the Element Gates' two fuse one gate fewer than the right Alchemon
    // can, so they go harder (test/flight_rules_test.dart 'catalog
    // balance').
    rivalForm: [0.9, 0.77, 1.0975],
    rivals: [
      RaceRival(
        name: 'Lightwing',
        element: 'Light',
        family: 'wing',
        speed: 6.4,
        strength: 5.0,
        intelligence: 5.8,
        beauty: 6.2,
        canny: true,
      ),
      RaceRival(
        name: 'Darkmask',
        element: 'Dark',
        family: 'mask',
        speed: 6.0,
        strength: 5.4,
        intelligence: 6.4,
        beauty: 5.4,
        canny: true,
      ),
      RaceRival(
        name: 'Crystalwing',
        element: 'Crystal',
        family: 'wing',
        speed: 6.2,
        strength: 6.0,
        intelligence: 5.6,
        beauty: 5.8,
        canny: true,
      ),
      RaceRival(
        name: 'Poisonlet',
        element: 'Poison',
        family: 'let',
        speed: 6.6,
        strength: 5.2,
        intelligence: 5.6,
        beauty: 5.6,
        canny: true,
      ),
    ],
    bouts: [
      GemBout(
        id: 'asteroid_run',
        name: 'Asteroid Run',
        place: 'asteroids',
        level: 1,
        rivals: [0, 3],
      ),
      GemBout(
        id: 'gravity_chain',
        name: 'Gravity Chain',
        place: 'gravity',
        level: 2,
        line: 'A gravity well at every fork.',
        rivals: [1, 2],
      ),
      GemBout(
        id: 'element_gates',
        name: 'Element Gates',
        place: 'gates',
        level: 3,
        line: 'Every fork is a pair of element gates.',
        rivals: [0, 2],
      ),
    ],
  ),
];

/// The gem cups' wins, kept with the races'.
extension GemProgress on RaceProgress {
  int wonInGem(GemCup cup) => (won[cup.id] ?? 0).clamp(0, cup.bouts.length);

  bool gemDone(GemCup cup) => wonInGem(cup) >= cup.bouts.length;

  /// The first gem cup opens with the Silver Cup won; each of the rest
  /// with the one before it.
  bool gemOpen(int index) =>
      allOpen ||
      (index == 0 ? cupDone(kRaceCups[1]) : gemDone(kGemCups[index - 1]));

  /// A bout is open once the one before it in its cup is won.
  bool boutOpen(GemCup cup, int bout) => allOpen || bout <= wonInGem(cup);

  /// After winning [cup]'s [bout]: the progress, and whether it was the
  /// first win of that bout (the one that pays gold).
  (RaceProgress, bool) afterGemWin(GemCup cup, int bout) {
    final first = bout == wonInGem(cup);
    if (!first) return (this, false);
    return (RaceProgress({...won, cup.id: bout + 1}, allOpen), true);
  }
}

/// [r] as one of a bout's three, going at [form] (its stats times it). A
/// canny one spends its stamina where it counts.
Racer gemRivalRacer(RaceRival r, double form) => Racer(
  id: 'rival:${r.name}',
  entrant: ContestEntrant(
    name: r.name,
    element: r.element,
    family: r.family,
    statRating: 0,
    scale: r.scale,
  ),
  ratings: {
    CosmicContestTrait.speed: r.speed * form,
    CosmicContestTrait.strength: r.strength * form,
    CosmicContestTrait.intelligence: r.intelligence * form,
    CosmicContestTrait.beauty: r.beauty * form,
  },
  boosts: r.boosts,
  autoBoostLegs: r.canny ? const [0] : const [],
);

/// Whether the Trials cup [id] — a race cup or a gem cup — has been won
/// outright.
bool trialsCupDone(RaceProgress progress, String id) {
  for (final c in kRaceCups) {
    if (c.id == id) return progress.cupDone(c);
  }
  for (final c in kGemCups) {
    if (c.id == id) return progress.gemDone(c);
  }
  return false;
}
