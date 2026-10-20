// lib/games/stadium/gem_cups.dart
//
// The Trials' gem cups: Ruby, Sapphire and Emerald, all three opened by
// winning the Silver Cup, each won on its own, five rounds each (the
// author, 2026-10-20). Ruby is the island (the last one standing on a
// crumbling island), Sapphire the space course (a course through space,
// its route planned before the start) and Emerald the battle ladder (two
// at a time from four, against five set teams that grow stronger). The
// night sky that Sapphire used to hold is gone.
//
// A cup's first round is its event plain; the rest each turn it with a
// rule of their own or a harder go at one (the author, 2026-10-18: the
// cups were "too repetitive", three of the same with new colours). Ruby:
// the Molten Heart, the Stepping Stones, the Ice Island and the Black
// Hole. Sapphire: the Gravity Chain and the Element Gates, then each again
// longer and against stronger rivals. Emerald: a team of each kind — Horns
// and Kin, Wings and Lets, two Kin, Manes and Pips — then the last four.
//
// Their wins are kept with the races' (RaceProgress, by [GemCup.progressId]).

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

/// What a gem cup's bouts are.
enum GemEvent {
  island('THE ISLAND', 'Last one standing on a crumbling island.'),
  flight('THE SPACE COURSE', 'Plan a route through space, then fly it.'),
  battle('THE BATTLE', 'Two at a time from four, against a set team.');

  const GemEvent(this.title, this.line);
  final String title, line;
}

class GemBout {
  const GemBout({
    required this.id,
    required this.name,
    required this.place,
    required this.level,
    this.rivals = const [],
    this.line = '',
    this.team = const [],
    this.potential = 50,
    this.enhancement = 0,
  });

  final String id, name;

  /// One plain line of what is different about it (the hub shows it in
  /// place of the event's own line); empty for a cup's plain first bout.
  final String line;

  /// Where it is fought, in the event's own terms (an island's kind, a
  /// course, a battle arena).
  final String place;

  /// How hard it is judged, 1..3.
  final int level;

  /// The two of the cup's rivals it is fought against (the island, the
  /// course).
  final List<int> rivals;

  /// A battle round's team of four, by family and element (catalog
  /// species), at [potential] in every stat, level 10, enhanced
  /// [enhancement] ranks: bred about as well as a team must be to beat it.
  final List<(String, String)> team;
  final int potential;
  final int enhancement;
}

class GemCup {
  const GemCup({
    required this.id,
    required this.name,
    required this.event,
    required this.rivals,
    required this.bouts,
    required this.gold,
    this.rivalForm = const [1, 1, 1, 1, 1],
    String? progressId,
  }) : _progressId = progressId;

  final String id, name;

  final String? _progressId;

  /// The key its wins are kept under: its id, unless its rounds changed
  /// under it (Sapphire's night sky became the space course, Emerald's
  /// course became the battle ladder; 2026-10-20), when a new key starts
  /// it over.
  String get progressId => _progressId ?? id;
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
    gold: [3, 4, 5, 6, 8],
    // The Molten Heart's two go harder: the heat already tells against
    // most of those who come (island_rules.dart). The Ice Island's and the
    // Black Hole's are set from the catalog probe (test/island_rules_test
    // 'catalog balance'): the right kind bred to P95 and enhanced ten ranks
    // wins about three in four, any other about one in eight.
    rivalForm: [1.02, 1.16, 1.0, 1.03, 1.03],
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
      RaceRival(
        name: 'Icehorn',
        element: 'Ice',
        family: 'horn',
        speed: 4.8,
        strength: 6.0,
        intelligence: 4.6,
        beauty: 4.6,
        scale: 1.12,
        canny: true,
      ),
      RaceRival(
        name: 'Darkhorn',
        element: 'Dark',
        family: 'horn',
        speed: 4.8,
        strength: 6.2,
        intelligence: 5.0,
        beauty: 4.4,
        scale: 1.15,
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
      GemBout(
        id: 'ice_island',
        name: 'Ice Island',
        place: 'ice',
        level: 3,
        line: 'Sheet ice: fast, and hard to stop.',
        rivals: [4, 1],
      ),
      GemBout(
        id: 'black_hole',
        name: 'Black Hole',
        place: 'black_hole',
        level: 3,
        line: 'A black hole at its heart pulls everyone in.',
        rivals: [5, 2],
      ),
    ],
  ),
  GemCup(
    id: 'sapphire',
    name: 'Sapphire Cup',
    event: GemEvent.flight,
    progressId: 'sapphire_course',
    gold: [4, 5, 6, 7, 9],
    // The Gravity Chain's two sling as well as they fly, so they go easier;
    // the Element Gates' two fuse one gate fewer than the right Alchemon
    // can, so they go harder (test/flight_rules_test.dart 'catalog
    // balance'). Rounds 4 and 5 are the two again, longer: the right
    // Alchemon bred to P95 and enhanced ten ranks wins about two in three
    // (round 3 four in five), one at P90 about one in four.
    rivalForm: [0.9, 0.77, 1.0975, 0.74, 1.08],
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
      GemBout(
        id: 'deep_gravity',
        name: 'Deep Gravity',
        place: 'gravity_deep',
        level: 3,
        line: 'The Gravity Chain again: longer, deeper wells.',
        rivals: [1, 3],
      ),
      GemBout(
        id: 'gate_run',
        name: 'Gate Run',
        place: 'gates_long',
        level: 3,
        line: 'The Element Gates again: six forks.',
        rivals: [2, 0],
      ),
    ],
  ),
  GemCup(
    id: 'emerald',
    name: 'Emerald Cup',
    event: GemEvent.battle,
    progressId: 'emerald_battle',
    gold: [5, 6, 8, 10, 12],
    rivals: [],
    // Five set teams, each harder than the last, each in an arena of its
    // own (models/battle_arenas.dart). Tuned with test/
    // gem_battle_ladder_test.dart so that four drawn at random from the
    // catalog win about half the time bred to P50, P65, P78 (2 ranks),
    // P88 (5 ranks) and P95 (10 ranks), round by round; a team picked for
    // the fight does better. How well a set team is bred is only half of
    // it: Kin and Horns hold, Wings hit hard.
    bouts: [
      GemBout(
        id: 'horns_and_kin',
        name: 'Horns and Kin',
        place: 'obsidian',
        level: 1,
        line: 'Two Horns hold the front, with a Kin behind them.',
        team: [
          ('Horn', 'Mud'),
          ('Kin', 'Lightning'),
          ('Horn', 'Earth'),
          ('Mane', 'Water'),
        ],
        potential: 40,
      ),
      GemBout(
        id: 'wings_and_lets',
        name: 'Wings and Lets',
        place: 'garden',
        level: 1,
        line: 'Wings and Lets that hit from far off.',
        team: [
          ('Wing', 'Air'),
          ('Let', 'Ice'),
          ('Wing', 'Fire'),
          ('Let', 'Lightning'),
        ],
        potential: 78,
      ),
      GemBout(
        id: 'two_kin',
        name: 'Two Kin',
        place: 'tidal',
        level: 1,
        line: 'Two Kin keep the others standing.',
        team: [
          ('Kin', 'Water'),
          ('Horn', 'Crystal'),
          ('Kin', 'Light'),
          ('Mask', 'Plant'),
        ],
        potential: 72,
      ),
      GemBout(
        id: 'manes_and_pips',
        name: 'Manes and Pips',
        place: 'orrery',
        level: 1,
        line: 'Fast Manes and Pips that swarm.',
        team: [
          ('Mane', 'Lava'),
          ('Pip', 'Lightning'),
          ('Mane', 'Air'),
          ('Pip', 'Fire'),
        ],
        potential: 95,
        enhancement: 8,
      ),
      GemBout(
        id: 'the_last_four',
        name: 'The Last Four',
        place: 'obsidian',
        level: 1,
        line: 'The strongest four in the Trials, bred perfectly.',
        team: [
          ('Wing', 'Air'),
          ('Kin', 'Blood'),
          ('Horn', 'Crystal'),
          ('Let', 'Spirit'),
        ],
        potential: 100,
        enhancement: 10,
      ),
    ],
  ),
];

/// The gem cups' wins, kept with the races'.
extension GemProgress on RaceProgress {
  int wonInGem(GemCup cup) =>
      (won[cup.progressId] ?? 0).clamp(0, cup.bouts.length);

  bool gemDone(GemCup cup) => wonInGem(cup) >= cup.bouts.length;

  /// All three gem cups open together, with the Silver Cup won.
  bool gemOpen(int index) => allOpen || cupDone(kRaceCups[1]);

  /// A bout is open once the one before it in its cup is won.
  bool boutOpen(GemCup cup, int bout) => allOpen || bout <= wonInGem(cup);

  /// After winning [cup]'s [bout]: the progress, and whether it was the
  /// first win of that bout (the one that pays gold).
  (RaceProgress, bool) afterGemWin(GemCup cup, int bout) {
    final first = bout == wonInGem(cup);
    if (!first) return (this, false);
    return (RaceProgress({...won, cup.progressId: bout + 1}, allOpen), true);
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
