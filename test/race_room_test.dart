// Racing friends live: a racer as numbers, the six every phone builds, two
// phones' races agreeing when one hears the other's taps late, and a room
// on a fake Firestore from invitation to the gun.

import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_stage.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RaceSeat _seat(String uid, String element, double speed) => RaceSeat(
  uid: uid,
  player: 'Player $uid',
  instanceId: 'inst-$uid',
  entrant: ContestEntrant(
    name: 'Mon $uid',
    element: element,
    family: 'pip',
    statRating: 0,
    scale: 0.93,
    prismatic: true,
    effect: 'prismatic_cascade',
    pureElement: element,
    generations: 3,
    elementKinds: 2,
  ),
  ratings: {
    CosmicContestTrait.speed: speed,
    CosmicContestTrait.strength: 4.137,
    CosmicContestTrait.intelligence: 3.9,
    CosmicContestTrait.beauty: 5.25,
  },
  boosts: 3,
  look: const ResidentLook(baseId: 'PIP01', prismatic: true),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RaceSeat', () {
    test('travels as numbers and comes back the same racer', () {
      final seat = _seat('a', 'Water', 5.4321);
      final back = RaceSeat.fromJson('a', seat.toJson())!;
      expect(back.ratings, seat.ratings);
      expect(back.boosts, 3);
      expect(back.look.baseId, 'PIP01');
      final e = back.entrant, f = seat.entrant;
      expect(
        [e.name, e.element, e.family, e.scale, e.prismatic, e.effect],
        [f.name, f.element, f.family, f.scale, f.prismatic, f.effect],
      );
      expect(
        [e.pureElement, e.generations, e.elementKinds],
        [f.pureElement, f.generations, f.elementKinds],
      );
      // The same verdict on every leg.
      final course = kRaceCups[2].courses[1];
      for (final leg in course.legs) {
        expect(
          back.racer(isPlayer: false).judge(leg).score,
          seat.racer(isPlayer: false).judge(leg).score,
        );
      }
    });

    test('a seat that cannot be read is left out', () {
      expect(RaceSeat.fromJson('a', {'player': 'x'}), isNull);
      expect(RaceSeat.fromJson('a', null), isNull);
    });
  });

  group('RaceRoom', () {
    RaceRoom room({
      List<String> field = const [],
      int? cpu,
      Map<String, int> ready = const {},
    }) => RaceRoom.fromJson('r1', {
      'host': 'a',
      'cpu': ?cpu,
      'ready': ready,
      'invited': ['a', 'b', 'c'],
      'names': {'a': 'Ann', 'b': 'Bo', 'c': 'Cy'},
      'cup': 1,
      'race': 2,
      'state': field.isEmpty ? 'lobby' : 'racing',
      'run': 2,
      'field': field,
      'seats': {
        'b': _seat('b', 'Fire', 5).toJson(),
        'a': _seat('a', 'Water', 5.2).toJson(),
      },
      'taps': {
        'a': {
          'run': 2,
          't': [400, 120],
        },
        'b': {
          'run': 1,
          't': [9],
        },
      },
    })!;

    test('the cup\'s rivals fill the back lanes, the players the front', () {
      final r = room();
      expect(r.course.id, kRaceCups[1].courses[2].id);
      final six = r.racers('b');
      expect(six.length, 6);
      expect(six.take(4).map((x) => x.id), [
        for (final rv in kRaceCups[1].rivals.take(4)) 'rival:${rv.name}',
      ]);
      // The host first, then in the order asked; only b's own is the player.
      expect(six[4].id, 'live:a');
      expect(six[5].id, 'live:b');
      expect(six.where((x) => x.isPlayer).single.id, 'live:b');
      expect(r.lanes(), {'a': 4, 'b': 5});
      // This run's taps only, sorted.
      expect(r.tapsByLane(), {
        4: [120, 400],
      });
      expect(r.nameOf('c'), 'Cy');
    });

    test('the rivals run at the race\'s form', () {
      final r = room();
      final rival = kRaceCups[1].rivals.first;
      expect(
        r.racers('a').first.ratings[CosmicContestTrait.speed],
        rival.speed * kRaceCups[1].rivalForm[2],
      );
    });

    test('once started, the field decides who races', () {
      final r = room(field: ['b']);
      expect(r.lanes(), {'b': 5});
      expect(r.racers('b').length, 6);
    });

    test('the host takes computers out: the players keep the front', () {
      final none = room(cpu: 0);
      expect(none.racers('b').map((x) => x.id), ['live:a', 'live:b']);
      expect(none.lanes(), {'a': 0, 'b': 1});
      expect(none.tapsByLane(), {
        0: [120, 400],
      });
      final two = room(cpu: 2);
      expect(two.racers('b').length, 4);
      expect(two.lanes(), {'a': 2, 'b': 3});
      // More than there is room for fills only the lanes left.
      expect(room(cpu: 5).racers('b').length, 6);
    });

    test('READY holds for the race after this run, and the host waits', () {
      expect(room().isReady('a'), isTrue, reason: 'the host starts it');
      expect(room().isReady('b'), isFalse);
      expect(room().canStart, isFalse);
      expect(room().notReady.map((s) => s.uid), ['b']);
      final ready = room(ready: {'b': 2});
      expect(ready.isReady('b'), isTrue);
      expect(ready.canStart, isTrue);
      // Ready for a race already run is not ready for this one.
      expect(room(ready: {'b': 1}).canStart, isFalse);
      // Mid-race nobody starts another.
      expect(room(field: ['a', 'b'], ready: {'b': 2}).canStart, isFalse);
    });

    test('a seat from an older game is known as one', () {
      final json = _seat('b', 'Fire', 5).toJson()..remove('v');
      expect(RaceSeat.fromJson('b', json)!.current, isFalse);
      expect(
        RaceSeat.fromJson('b', _seat('b', 'Fire', 5).toJson())!.current,
        isTrue,
      );
    });
  });

  group('a live race', () {
    test('two phones agree when one hears the other\'s taps late', () {
      final cup = kRaceCups[1];
      const race = 0;
      final course = cup.courses[race];
      List<Racer> six(int me) => [
        for (final r in cup.rivals.take(4)) r.racer(course),
        _seat('a', 'Water', 5.2).racer(isPlayer: me == 4),
        _seat('b', 'Fire', 5.0).racer(isPlayer: me == 5),
      ];
      List<RaceBody> bodies() => [
        for (var i = 0; i < 6; i++)
          RaceBody(
            CosmicPartyMember(
              instanceId: 'x$i',
              baseId: '',
              displayName: 'Racer $i',
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
      // Both phones' clocks: the gun at 10 s.
      var wall = 0.0;
      RaceStage stage(int me) => RaceStage(
        course: course,
        racers: six(me),
        bodies: bodies(),
        player: me,
        live: RaceLive(gunAt: 10, wall: () => wall),
      );
      final a = stage(4), b = stage(5);
      // Each taps on its own phone; a's taps reach b a second late, b's
      // reach a at once.
      final aTaps = <int>[], bTaps = <int>[];
      final aLate = <(double, List<int>)>[];
      var aTapped = 0, bTapped = 0;
      while (wall < 120 && !(a.sim.over && b.sim.over)) {
        wall += 1 / 60;
        a.advance(1 / 60);
        b.advance(1 / 60);
        if (a.running && aTapped < 3 && a.sim.tick >= 300 + aTapped * 500) {
          if (a.tapBoost()) {
            aTapped++;
            aTaps.add(a.sim.taps[4]!.last);
            aLate.add((wall + 1.0, [...aTaps]));
          }
        }
        if (b.running && bTapped < 3 && b.sim.tick >= 450 + bTapped * 400) {
          if (b.tapBoost()) {
            bTapped++;
            bTaps.add(b.sim.taps[5]!.last);
            a.mergeTaps(5, [...bTaps]);
          }
        }
        while (aLate.isNotEmpty && aLate.first.$1 <= wall) {
          b.mergeTaps(4, aLate.removeAt(0).$2);
        }
      }
      expect(aTapped, 3);
      expect(bTapped, 3);
      expect(a.sim.over && b.sim.over, isTrue);
      // The same race as the whole of it run at once with every tap.
      final whole = RaceSim.run(course, six(4), {4: aTaps, 5: bTaps});
      for (final s in [a.sim, b.sim]) {
        expect(s.standings, whole.standings);
        expect(
          [for (final st in s.states) st.finishTime],
          [for (final st in whole.states) st.finishTime],
        );
      }
    });
  });

  group('RaceRoomService', () {
    late FakeFirebaseFirestore fs;
    RaceRoomService player(String uid, String name) => RaceRoomService(
      account: _FakeAccount(_FakeUser(uid, name)),
      friends: _FakeFriends(),
      firestore: fs,
    );
    setUp(() => fs = FakeFirebaseFirestore());

    test('ask, join, start, tap, leave', () async {
      final ann = player('a', 'Ann'), bo = player('b', 'Bo');
      addTearDown(ann.dispose);
      addTearDown(bo.dispose);
      final id = await ann.host(
        cup: 0,
        race: 1,
        invite: [const FriendCard(uid: 'b', name: 'Bo')],
      );
      await Future<void>.delayed(Duration.zero);
      // Bo is asked; Ann is not asked into her own.
      expect(bo.invites.map((r) => r.id), [id]);
      expect(ann.invites, isEmpty);
      expect(bo.invites.single.nameOf('a'), 'Ann');

      await ann.sit(id, _seat('a', 'Water', 5.1));
      await bo.sit(id, _seat('b', 'Fire', 4.9));
      await Future<void>.delayed(Duration.zero);
      // Joined: no longer an invitation.
      expect(bo.invites, isEmpty);

      final rooms = <RaceRoom?>[];
      final sub = bo.watch(id).listen(rooms.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      final lobby = rooms.last!;
      expect(lobby.racing.map((s) => s.uid), ['a', 'b']);

      // Not until Bo is ready.
      await ann.start(lobby);
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last!.state, RaceRoomState.lobby);
      await bo.setReady(rooms.last!, true);
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last!.isReady('b'), isTrue);
      expect(rooms.last!.canStart, isTrue);

      await ann.start(rooms.last!);
      await Future<void>.delayed(Duration.zero);
      final racing = rooms.last!;
      // Ready for this one, not the next.
      expect(racing.isReady('b'), isFalse);
      expect(racing.state, RaceRoomState.racing);
      expect(racing.run, 1);
      expect(racing.field, ['a', 'b']);
      expect(
        racing.startAt! - ann.serverNowMs(),
        closeTo(kRaceRoomLead.inMilliseconds, 500),
      );

      await bo.sendTaps(racing, [310, 920]);
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last!.tapsByLane(), {
        5: [310, 920],
      });
      // Bo leaving mid-race is off the list at once, but keeps his seat
      // for the phones still loading; the race still has him.
      await bo.leave(rooms.last!);
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last!.invited, ['a']);
      expect(rooms.last!.seats.keys, containsAll(['a', 'b']));
      expect(rooms.last!.lanes(), {'a': 4, 'b': 5});

      // Back between races, the host clears it.
      await ann.backToLobby(rooms.last!);
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last!.state, RaceRoomState.lobby);
      expect(rooms.last!.field, isEmpty);
      expect(rooms.last!.seats.keys, ['a']);
      // The host leaving closes it.
      await ann.leave(rooms.last!);
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last, isNull);
    });

    test('an invitation waved away stays away', () async {
      final ann = player('a', 'Ann'), bo = player('b', 'Bo');
      addTearDown(ann.dispose);
      addTearDown(bo.dispose);
      final id = await ann.host(
        cup: 0,
        race: 0,
        invite: [const FriendCard(uid: 'b', name: 'Bo')],
      );
      await Future<void>.delayed(Duration.zero);
      expect(bo.invites, isNotEmpty);
      await bo.dismiss(id);
      expect(bo.invites, isEmpty);
      // And after the game starts again.
      final again = player('b', 'Bo');
      addTearDown(again.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(again.invites, isEmpty);
    });

    test(
      'DECLINE: gone from this phone, and the host sees the lane free',
      () async {
        final ann = player('a', 'Ann'), bo = player('b', 'Bo');
        addTearDown(ann.dispose);
        addTearDown(bo.dispose);
        final id = await ann.host(
          cup: 0,
          race: 0,
          invite: [const FriendCard(uid: 'b', name: 'Bo')],
        );
        await Future<void>.delayed(Duration.zero);
        await bo.decline(bo.invites.single);
        await Future<void>.delayed(Duration.zero);
        expect(bo.invites, isEmpty);
        final room = await ann.watch(id).first;
        expect(room!.invited, ['a']);
      },
    );

    test(
      'a player leaving between races takes their READY with them',
      () async {
        final ann = player('a', 'Ann'), bo = player('b', 'Bo');
        addTearDown(ann.dispose);
        addTearDown(bo.dispose);
        final id = await ann.host(
          cup: 0,
          race: 0,
          invite: [const FriendCard(uid: 'b', name: 'Bo')],
        );
        await bo.sit(id, _seat('b', 'Fire', 4.9));
        await bo.setReady((await bo.watch(id).first)!, true);
        await bo.leave((await bo.watch(id).first)!);
        final room = (await ann.watch(id).first)!;
        expect(room.invited, ['a']);
        expect(room.seats, isEmpty);
        expect(room.ready, isEmpty);
      },
    );

    test('the host takes lanes out and puts computers back', () async {
      final ann = player('a', 'Ann'), bo = player('b', 'Bo');
      addTearDown(ann.dispose);
      addTearDown(bo.dispose);
      final id = await ann.host(
        cup: 0,
        race: 0,
        invite: [
          const FriendCard(uid: 'b', name: 'Bo'),
          const FriendCard(uid: 'c', name: 'Cy'),
        ],
      );
      await ann.sit(id, _seat('a', 'Water', 5.1));
      await bo.sit(id, _seat('b', 'Fire', 4.9));
      await bo.setReady((await bo.watch(id).first)!, true);
      var room = (await ann.watch(id).first)!;
      expect(room.rivalsBeside(3), 3);

      await ann.setComputers(room, 0);
      room = (await ann.watch(id).first)!;
      expect(room.cpu, 0);
      expect(room.racers('a').length, 2);

      // Cy never came; Bo is taken out too, READY and all.
      await ann.remove(room, 'c');
      await ann.remove((await ann.watch(id).first)!, 'b');
      room = (await ann.watch(id).first)!;
      expect(room.invited, ['a']);
      expect(room.seats.keys, ['a']);
      expect(room.ready, isEmpty);
      // The host is never taken out.
      await ann.remove(room, 'a');
      expect((await ann.watch(id).first)!.invited, ['a']);

      await ann.setComputers(room, 2);
      expect((await ann.watch(id).first)!.racers('a').length, 3);
    });

    test('the host asks more friends in, up to the lanes', () async {
      final ann = player('a', 'Ann');
      addTearDown(ann.dispose);
      final id = await ann.host(cup: 0, race: 0);
      final rooms = <RaceRoom?>[];
      final sub = ann.watch(id).listen(rooms.add);
      addTearDown(sub.cancel);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
        await ann.invite(rooms.last!, FriendCard(uid: 'f$i', name: 'F$i'));
      }
      await Future<void>.delayed(Duration.zero);
      expect(rooms.last!.invited.length, kRaceRoomSeats);
      await expectLater(
        ann.invite(rooms.last!, const FriendCard(uid: 'g', name: 'G')),
        throwsA(isA<RaceRoomException>()),
      );
    });
  });
}

class _FakeUser implements User {
  _FakeUser(this.uid, this.displayName);
  @override
  final String uid;
  @override
  final String? displayName;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAccount extends ChangeNotifier implements AccountService {
  _FakeAccount(this.user);
  @override
  final User? user;
  @override
  bool get initialized => true;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeFriends extends ChangeNotifier implements FriendService {
  @override
  bool get available => true;
  @override
  String? get code => 'HX4N-7QRT';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
