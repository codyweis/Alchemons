// lib/games/stadium/race_cups.dart
//
// The stadium's race ladder: three cups of three races. A cup's five rivals
// run all three of its races, so the player comes to know them; each race is
// a different course, so a different one of them leads. Win a race to open
// the next; win a cup's last to open the next cup.
//
// Sprint legs are most of every course. Wall, fusion and show legs come once
// or twice, each under one of its trait's contest conditions (race_rules.dart
// judges them).

import 'dart:convert';

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_rules.dart';

/// A computer racer. Its body is the catalog species of its element and
/// family, and it goes by that species' name (Airlet, Earthhorn — the
/// author, 2026-10-12: "rename all the rivals to what they actually are").
class RaceRival {
  const RaceRival({
    required this.name,
    required this.element,
    required this.family,
    required this.speed,
    required this.strength,
    required this.intelligence,
    required this.beauty,
    this.scale = 1,
    this.boosts = 3,
    this.canny = false,
  });

  final String name, element, family;
  final double speed, strength, intelligence, beauty;
  final double scale;
  final int boosts;

  /// Spends its boosts on its slowest legs rather than its first ones.
  final bool canny;

  /// Its racer on [course], running at [form] (its stats times it: the
  /// rivals run harder in a cup's later races).
  Racer racer(RaceCourse course, {double form = 1}) {
    final base = Racer(
      id: 'rival:$name',
      entrant: ContestEntrant(
        name: name,
        element: element,
        family: family,
        statRating: 0,
        scale: scale,
      ),
      ratings: {
        CosmicContestTrait.speed: speed * form,
        CosmicContestTrait.strength: strength * form,
        CosmicContestTrait.intelligence: intelligence * form,
        CosmicContestTrait.beauty: beauty * form,
      },
      boosts: boosts,
    );
    return Racer(
      id: base.id,
      entrant: base.entrant,
      ratings: base.ratings,
      boosts: boosts,
      autoBoostLegs: planRaceBoosts(base, course, canny: canny),
    );
  }
}

class RaceCup {
  const RaceCup({
    required this.id,
    required this.name,
    required this.rivals,
    required this.courses,
    required this.gold,
    this.rivalForm = const [1, 1, 1],
  });

  final String id, name;
  final List<RaceRival> rivals;
  final List<RaceCourse> courses;

  /// Gold for the first win of each race.
  final List<int> gold;

  /// How hard the rivals run each race, as a multiple of their stats: each
  /// race of a cup asks a little more than the last.
  final List<double> rivalForm;
}

const _s = RaceLegKind.sprint;
const _h = RaceLegKind.hill;
const _p = RaceLegKind.pond;
const _g = RaceLegKind.gap;
const _i = RaceLegKind.ice;
const _m = RaceLegKind.mud;
const _f = RaceLegKind.fuse;
const _c = RaceLegKind.crowd;

const List<RaceCup> kRaceCups = [
  RaceCup(
    id: 'copper',
    name: 'Copper Cup',
    gold: [1, 1, 2],
    rivalForm: [1, 1.06, 1.12],
    rivals: [
      RaceRival(
        name: 'Airlet',
        element: 'Air',
        family: 'let',
        speed: 4.5,
        strength: 2.5,
        intelligence: 3.25,
        beauty: 3.1,
        scale: 0.9,
      ),
      RaceRival(
        name: 'Earthhorn',
        element: 'Earth',
        family: 'horn',
        speed: 3.1,
        strength: 4.8,
        intelligence: 2.8,
        beauty: 2.8,
        scale: 1.1,
      ),
      RaceRival(
        name: 'Waterpip',
        element: 'Water',
        family: 'pip',
        speed: 3.9,
        strength: 2.8,
        intelligence: 4.05,
        beauty: 3.4,
      ),
      RaceRival(
        name: 'Firemane',
        element: 'Fire',
        family: 'mane',
        speed: 3.55,
        strength: 4.05,
        intelligence: 3.1,
        beauty: 3.7,
      ),
      RaceRival(
        name: 'Plantwing',
        element: 'Plant',
        family: 'wing',
        speed: 4.05,
        strength: 2.8,
        intelligence: 3.1,
        beauty: 4.35,
      ),
    ],
    courses: [
      RaceCourse(
        id: 'open',
        name: 'Open Track',
        // Round the stadium itself: the gentle one.
        scene: RaceScene.stadium,
        legs: [
          RaceLeg(_s, 960),
          RaceLeg(_h, 300),
          RaceLeg(_s, 840),
          RaceLeg(_f, 360, element: 'Water'),
          RaceLeg(_s, 720),
          RaceLeg(_c, 510),
          RaceLeg(_s, 720),
        ],
      ),
      RaceCourse(
        id: 'rain',
        name: 'Rain Track',
        scene: RaceScene.meadow,
        legs: [
          RaceLeg(_s, 720),
          RaceLeg(_s, 700, level: 2),
          RaceLeg(_p, 300),
          RaceLeg(_s, 660, level: 2),
          RaceLeg(_h, 300),
          RaceLeg(_f, 360, element: 'Earth'),
          RaceLeg(_c, 510),
          RaceLeg(_s, 720, level: 2),
        ],
      ),
      RaceCourse(
        id: 'ember',
        name: 'Flare Track',
        scene: RaceScene.volcano,
        legs: [
          RaceLeg(_s, 840),
          RaceLeg(_h, 360, level: 2),
          RaceLeg(_s, 720),
          RaceLeg(_f, 360, element: 'Fire'),
          RaceLeg(_s, 600),
          RaceLeg(_h, 300, level: 2),
          RaceLeg(_c, 510),
          RaceLeg(_s, 720),
        ],
      ),
    ],
  ),
  RaceCup(
    id: 'silver',
    name: 'Silver Cup',
    gold: [2, 3, 3],
    rivalForm: [1, 1.18, 1.07],
    rivals: [
      RaceRival(
        name: 'Airwing',
        element: 'Air',
        family: 'wing',
        speed: 5.2,
        strength: 3.3,
        intelligence: 3.85,
        beauty: 4.1,
        canny: true,
      ),
      RaceRival(
        name: 'Lightningkin',
        element: 'Lightning',
        family: 'kin',
        speed: 5.05,
        strength: 3.85,
        intelligence: 4.1,
        beauty: 3.55,
      ),
      RaceRival(
        name: 'Watermask',
        element: 'Water',
        family: 'mask',
        speed: 4.4,
        strength: 3.3,
        intelligence: 5.2,
        beauty: 4.65,
        canny: true,
      ),
      RaceRival(
        name: 'Lavamane',
        element: 'Lava',
        family: 'mane',
        speed: 3.85,
        strength: 5.35,
        intelligence: 3.3,
        beauty: 3.55,
        scale: 1.15,
      ),
      RaceRival(
        name: 'Icelet',
        element: 'Ice',
        family: 'let',
        speed: 4.95,
        strength: 3.0,
        intelligence: 4.1,
        beauty: 4.4,
        scale: 0.9,
        canny: true,
      ),
    ],
    courses: [
      RaceCourse(
        id: 'storm',
        name: 'Storm Track',
        scene: RaceScene.cliffs,
        legs: [
          RaceLeg(_s, 880, level: 3),
          RaceLeg(_g, 300),
          RaceLeg(_s, 760, level: 3),
          RaceLeg(_f, 360, element: 'Air', level: 2),
          RaceLeg(_h, 300, level: 3),
          RaceLeg(_c, 510, level: 3),
          RaceLeg(_s, 880, level: 3),
        ],
      ),
      RaceCourse(
        id: 'hill',
        name: 'Hill Track',
        scene: RaceScene.hills,
        legs: [
          RaceLeg(_s, 600),
          RaceLeg(_h, 360, level: 3),
          RaceLeg(_s, 700, level: 4),
          RaceLeg(_h, 300, level: 4),
          RaceLeg(_f, 360, element: 'Crystal', level: 3),
          RaceLeg(_m, 280),
          RaceLeg(_s, 700, level: 4),
          RaceLeg(_c, 510),
          RaceLeg(_s, 600),
        ],
      ),
      RaceCourse(
        id: 'night',
        name: 'Night Track',
        scene: RaceScene.forest,
        legs: [
          RaceLeg(_s, 820, level: 2),
          RaceLeg(_c, 600, level: 3),
          RaceLeg(_f, 360, element: 'Spirit', level: 3),
          RaceLeg(_p, 400),
          RaceLeg(_s, 820, level: 3),
          RaceLeg(_h, 300, level: 2),
          RaceLeg(_s, 900, level: 2),
        ],
      ),
    ],
  ),
  RaceCup(
    id: 'gold',
    name: 'Gold Cup',
    gold: [4, 4, 5],
    rivalForm: [1, 1.07, 1.05],
    rivals: [
      RaceRival(
        name: 'Lightningwing',
        element: 'Lightning',
        family: 'wing',
        // Glides every gap: a shade slower than he was before there were
        // gaps.
        speed: 6.2,
        strength: 4.2,
        intelligence: 4.75,
        beauty: 5.0,
        boosts: 4,
        canny: true,
      ),
      RaceRival(
        name: 'Earthkin',
        element: 'Earth',
        family: 'kin',
        speed: 5.4,
        strength: 6.35,
        intelligence: 4.75,
        beauty: 4.2,
        scale: 1.15,
        canny: true,
      ),
      RaceRival(
        name: 'Lightmask',
        element: 'Light',
        family: 'mask',
        speed: 5.3,
        strength: 3.95,
        intelligence: 6.45,
        beauty: 6.05,
        canny: true,
      ),
      RaceRival(
        name: 'Steampip',
        element: 'Steam',
        family: 'pip',
        speed: 6.05,
        strength: 3.95,
        intelligence: 5.3,
        beauty: 5.0,
        scale: 0.9,
        boosts: 4,
        canny: true,
      ),
      RaceRival(
        name: 'Darkmane',
        element: 'Dark',
        family: 'mane',
        speed: 5.8,
        strength: 5.8,
        intelligence: 5.0,
        beauty: 5.55,
        canny: true,
      ),
    ],
    courses: [
      RaceCourse(
        id: 'long',
        name: 'Long Track',
        // A bit of everything, across the downs.
        scene: RaceScene.hills,
        legs: [
          RaceLeg(_s, 900, level: 5),
          RaceLeg(_p, 400),
          RaceLeg(_h, 360, level: 5),
          RaceLeg(_g, 260),
          RaceLeg(_f, 420, element: 'Light', level: 4),
          RaceLeg(_m, 300),
          RaceLeg(_s, 760, level: 5),
          RaceLeg(_c, 510, level: 4),
          RaceLeg(_s, 760, level: 5),
        ],
      ),
      RaceCourse(
        id: 'crystal',
        name: 'Crystal Track',
        scene: RaceScene.caves,
        legs: [
          RaceLeg(_s, 820, level: 4),
          RaceLeg(_i, 520),
          RaceLeg(_f, 360, element: 'Lightning', level: 3),
          RaceLeg(_s, 800, level: 3),
          RaceLeg(_f, 360, element: 'Water', level: 4),
          RaceLeg(_h, 300, level: 4),
          RaceLeg(_i, 480),
          RaceLeg(_c, 510, level: 3),
          RaceLeg(_s, 800, level: 4),
        ],
      ),
      RaceCourse(
        id: 'star',
        name: 'Star Track',
        // Out among the stars: the track floats, so does everyone over its
        // gap, and its ice is a comet's.
        scene: RaceScene.space,
        legs: [
          RaceLeg(_s, 960, level: 5),
          RaceLeg(_g, 280),
          RaceLeg(_h, 480, level: 5),
          RaceLeg(_f, 420, element: 'Dark', level: 5),
          RaceLeg(_i, 360),
          RaceLeg(_s, 820, level: 5),
          RaceLeg(_c, 600, level: 5),
          RaceLeg(_s, 860, level: 5),
        ],
      ),
    ],
  ),
];

/// The six lanes for [cup]'s race [race]: the player's racer in [lane], the
/// cup's five rivals round it.
List<Racer> raceField(RaceCup cup, int race, Racer player, {int lane = 2}) {
  final course = cup.courses[race];
  final form = race < cup.rivalForm.length ? cup.rivalForm[race] : 1.0;
  final rivals = [for (final r in cup.rivals) r.racer(course, form: form)];
  final at = lane.clamp(0, rivals.length);
  return [...rivals.take(at), player, ...rivals.skip(at)];
}

/// Races won per cup, kept in prefs as JSON.
class RaceProgress {
  const RaceProgress([this.won = const {}, this.allOpen = false]);

  static const prefsKey = 'stadium_race_progress_v1';

  /// Cup id → how many of its races have been won, in order.
  final Map<String, int> won;

  /// Every cup, race and bout open whatever has been won (the developer
  /// tools; the author, 2026-10-12). Never saved; nothing counts as won by
  /// it, so titles, keepsakes and rewards still take the wins.
  final bool allOpen;

  /// The same wins, with everything open.
  RaceProgress opened() => RaceProgress(won, true);

  int wonIn(RaceCup cup) => (won[cup.id] ?? 0).clamp(0, cup.courses.length);

  bool cupDone(RaceCup cup) => wonIn(cup) >= cup.courses.length;

  /// A cup is open once the one before it is done.
  bool cupOpen(int index) =>
      allOpen || index == 0 || cupDone(kRaceCups[index - 1]);

  /// A race is open once the one before it in its cup is won.
  bool raceOpen(RaceCup cup, int race) => allOpen || race <= wonIn(cup);

  /// After winning [cup]'s [race]: the progress, and whether it was the
  /// first win of that race (the one that pays gold).
  (RaceProgress, bool) afterWin(RaceCup cup, int race) {
    final first = race == wonIn(cup);
    if (!first) return (this, false);
    return (RaceProgress({...won, cup.id: race + 1}, allOpen), true);
  }

  String serialise() => jsonEncode(won);

  static RaceProgress deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return const RaceProgress();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return const RaceProgress();
      return RaceProgress({
        for (final e in m.entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      });
    } catch (_) {
      return const RaceProgress();
    }
  }
}
