// The gem cups with friends: the island's own sine, two phones fighting the
// same bout when one hears the other's taps late (the island, the space
// course, the night sky), and a gem room's three, routes and READY.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/flight_rules.dart';
import 'package:alchemons/games/stadium/flight_stage.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/island_rules.dart';
import 'package:alchemons/games/stadium/island_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/sky_rules.dart';
import 'package:alchemons/games/stadium/sky_stage.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:flutter_test/flutter_test.dart';

RaceSeat _seat(String uid, String element, String family, double str) =>
    RaceSeat(
      uid: uid,
      player: 'Player $uid',
      instanceId: 'inst-$uid',
      entrant: ContestEntrant(
        name: 'Mon $uid',
        element: element,
        family: family,
        statRating: 0,
      ),
      ratings: {
        CosmicContestTrait.speed: 4.6,
        CosmicContestTrait.strength: str,
        CosmicContestTrait.intelligence: 4.2,
        CosmicContestTrait.beauty: 4.4,
      },
      boosts: 3,
      look: const ResidentLook(baseId: 'PIP01'),
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

RaceRoom _room({
  int cup = 0,
  int bout = 0,
  List<String> invited = const ['a', 'b'],
  Map<String, int> ready = const {},
  Map<String, Object?> plans = const {},
  int? cpu,
}) => RaceRoom.fromJson('g1', {
  'host': 'a',
  'invited': invited,
  'names': {for (final u in invited) u: u.toUpperCase()},
  'ev': 'gem',
  'cup': cup,
  'race': bout,
  'cpu': ?cpu,
  'state': 'lobby',
  'run': 1,
  'ready': ready,
  'plans': plans,
  'seats': {
    for (final u in invited)
      u: _seat(u, u == 'a' ? 'Earth' : 'Fire', 'horn', 5.0).toJson(),
  },
  'taps': {},
})!;

/// Two phones' stages, the gun at 10 s on a clock both share; [a]'s taps
/// reach [b] a second late, [b]'s reach [a] at once.
void _twoPhones(
  BoutStage a,
  BoutStage b, {
  required void Function(double wall) setWall,
  required bool Function(BoutStage s) over,
}) {
  var wall = 0.0;
  final aLate = <(double, List<int>)>[];
  var aTapped = 0, bTapped = 0;
  while (wall < 150 && !(over(a) && over(b))) {
    wall += 1 / 60;
    setWall(wall);
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
}

void main() {
  group('islandSin', () {
    test('agrees with the platform\'s sine to well under a millionth', () {
      for (var x = -40.0; x <= 40; x += 0.0137) {
        expect((islandSin(x) - math.sin(x)).abs(), lessThan(1e-9));
        expect((islandCos(x) - math.cos(x)).abs(), lessThan(1e-9));
      }
    });
  });

  group('a gem room', () {
    test('three to a bout: the bout\'s rivals, then the players', () {
      final r = _room();
      expect(r.gem, isTrue);
      expect(r.held, kGemBoutSeats);
      expect(r.placeName, kGemCups[0].bouts[0].name);
      final f = r.fighters();
      expect(f.map((x) => x.id), [
        'rival:${kGemCups[0].rivalsOf(0).first.name}',
        'live:a',
        'live:b',
      ]);
      // A player's fighter is driven by taps alone on every phone.
      expect(f.skip(1).every((x) => x.isPlayer), isTrue);
      expect(f.first.isPlayer, isFalse);
      expect(r.lanes(), {'a': 1, 'b': 2});
      expect(_room(cpu: 0).fighters().length, 2);
      expect(_room(invited: ['a', 'b', 'c']).fighters().length, 3);
    });

    test('more than a bout holds cannot start', () {
      final r = _room(
        invited: ['a', 'b', 'c', 'd'],
        ready: {'b': 1, 'c': 1, 'd': 1},
      );
      expect(r.notReady, isEmpty);
      expect(r.canStart, isFalse);
      expect(_room(ready: {'b': 1}).canStart, isTrue);
    });

    test('the space course: READY needs a route planned here', () {
      final key = _room(cup: 2).placeKey;
      final plan = {
        'run': 1,
        'at': key,
        'r': [1, 0],
      };
      expect(_room(cup: 2, ready: {'b': 1}).isReady('b'), isFalse);
      final r = _room(cup: 2, ready: {'b': 1}, plans: {'b': plan});
      expect(r.isReady('b'), isTrue);
      expect(r.planOf('b'), [1, 0]);
      // Planned for another bout, or a race already run: no plan.
      expect(
        _room(
          cup: 2,
          bout: 1,
          ready: {'b': 1},
          plans: {'b': plan},
        ).isReady('b'),
        isFalse,
      );
      expect(
        _room(
          cup: 2,
          ready: {'b': 1},
          plans: {
            'b': {
              'run': 0,
              'at': key,
              'r': [1, 0],
            },
          },
        ).planOf('b'),
        isNull,
      );
      // Each route as every phone flies it: the plan, or the best way.
      final f = r.fighters();
      final routes = r.routes(f);
      final course = flightCourseOf(r.bout);
      expect(routes[0], bestFlightRoute(f[0], course));
      expect(routes[1], bestFlightRoute(f[1], course));
      expect(routes[2], [1, 0]);
    });
  });

  group('two phones, one bout', () {
    test('the island', () {
      final r = _room(invited: ['a', 'b']);
      final fighters = r.fighters();
      final bout = islandBoutOf(kGemCups[0].bouts[0]);
      var wall = 0.0;
      IslandStage stage(int me) => IslandStage(
        bout: bout,
        fighters: fighters,
        bodies: _bodies(3),
        player: me,
        live: BoutLive(gunAt: 10, wall: () => wall),
      );
      final a = stage(1), b = stage(2);
      _twoPhones(
        a,
        b,
        setWall: (w) => wall = w,
        over: (s) => (s as IslandStage).sim.over,
      );
      expect(a.sim.over && b.sim.over, isTrue);
      final whole = IslandSim.run(bout, fighters, {1: a.myTaps, 2: b.myTaps});
      for (final s in [a.sim, b.sim]) {
        expect(s.tick, whole.tick);
        expect(s.standings, whole.standings);
        expect(
          [for (final st in s.states) st.fellAt],
          [for (final st in whole.states) st.fellAt],
        );
      }
      // Each phone sees its own fighter set down at the front.
      expect(stage(1).y[1], closeTo(kIslandRadius * 0.55, 1e-6));
      expect(stage(2).y[2], closeTo(kIslandRadius * 0.55, 1e-6));
      expect(stage(2).x[2], closeTo(0, 1e-6));
    });

    test('the space course', () {
      final r = _room(cup: 2, invited: ['a', 'b']);
      final fighters = r.fighters();
      final course = flightCourseOf(r.bout);
      final routes = [
        bestFlightRoute(fighters[0], course),
        [0, 1],
        [1, 0],
      ];
      var wall = 0.0;
      FlightStage stage(int me) => FlightStage(
        course: course,
        fighters: fighters,
        bodies: _bodies(3),
        player: me,
        choices: routes,
        live: BoutLive(gunAt: 10, wall: () => wall),
      );
      final a = stage(1), b = stage(2);
      _twoPhones(
        a,
        b,
        setWall: (w) => wall = w,
        over: (s) => (s as FlightStage).sim.over,
      );
      final whole = FlightSim.run(course, fighters, routes, {
        1: a.myTaps,
        2: b.myTaps,
      });
      for (final s in [a.sim, b.sim]) {
        expect(s.standings, whole.standings);
        expect(
          [for (final st in s.states) st.finishTime],
          [for (final st in whole.states) st.finishTime],
        );
      }
    });

    test('the night sky', () {
      final r = _room(cup: 1, invited: ['a', 'b']);
      final fighters = r.fighters();
      final bout = skyBoutOf(kGemCups[1].bouts[0]);
      SkyStage stage(int me) => SkyStage(
        bout: bout,
        fighters: fighters,
        bodies: _bodies(3),
        player: me,
        live: BoutLive(gunAt: 10, wall: () => 0),
      );
      final a = stage(1), b = stage(2);
      expect(a.standings, b.standings);
      for (var i = 0; i < 3; i++) {
        expect(a.contest.starsOf(i), b.contest.starsOf(i));
      }
      // Each watches its own cast last.
      expect(a.contest.castOrder.last, 1);
      expect(b.contest.castOrder.last, 2);
    });
  });
}
