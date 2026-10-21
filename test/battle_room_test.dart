// Live battles with a friend, the room: a four as numbers, two players on
// one fake Firestore from the invitation to the fight's end, the stream's
// eight documents, the guest's inputs, leaving, and a game too old to
// battle. Then a fight carried by the room's own stream, end to end.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/battle_link.dart';
import 'package:alchemons/games/cosmic/battle_wire.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/battle_record.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/battle_room_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battle_test.dart' show battleArena, battleMember;

BattleSeat _seat(String uid, List<String> four, {int? version}) => BattleSeat(
  uid: uid,
  player: 'Player $uid',
  team: [
    for (final (i, s) in four.indexed)
      BattleSeatMember.of(
        battleMember(s.split(':')[0], s.split(':')[1], stat: 4, id: '$uid$i'),
        const ResidentLook(baseId: 'HOR01', prismatic: true),
      ),
  ],
  version: version ?? kBattleLinkVersion,
);

const _hostFour = ['Horn:Fire', 'Wing:Air', 'Kin:Water', 'Pip:Earth'];
const _guestFour = ['Mane:Lava', 'Mask:Plant', 'Let:Ice', 'Wing:Light'];

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a seat', () {
    test('travels as numbers and comes back the same four', () {
      final seat = _seat('a', _hostFour);
      final back = BattleSeat.fromJson('a', seat.toJson())!;
      expect(back.player, 'Player a');
      expect(back.current, isTrue);
      final a = seat.members(null), b = back.members(null);
      expect(b.length, 4);
      for (var i = 0; i < 4; i++) {
        expect(
          [
            b[i].family,
            b[i].element,
            b[i].level,
            b[i].statStrength,
            b[i].statBeautyPotential,
            b[i].slotIndex,
          ],
          [
            a[i].family,
            a[i].element,
            a[i].level,
            a[i].statStrength,
            a[i].statBeautyPotential,
            i,
          ],
        );
      }
      expect(back.team.first.look.prismatic, isTrue);
      expect(BattleSeat.fromJson('a', {'player': 'x'}), isNull);
      expect(
        BattleSeat.fromJson('a', {...seat.toJson(), 'v': 0})!.current,
        isFalse,
      );
    });
  });

  group('a room', () {
    late FakeFirebaseFirestore fs;
    BattleRoomService player(String uid, String name) => BattleRoomService(
      account: _FakeAccount(_FakeUser(uid, name)),
      friends: _FakeFriends(),
      firestore: fs,
    );
    setUp(() => fs = FakeFirebaseFirestore());

    test('invite, join, ready, start, the fight, the end, and again', () async {
      final ann = player('a', 'Ann');
      final bo = player('b', 'Bo');
      await _settle();
      final id = await ann.host(
        arena: 'orrery',
        invite: const FriendCard(uid: 'b', name: 'Bo'),
      );
      await _settle();
      // Bo is asked.
      expect(bo.invites.single.id, id);
      expect(bo.invites.single.nameOf('a'), 'Ann');
      expect(ann.invites, isEmpty);
      BattleRoom? room;
      final sub = ann.watch(id).listen((r) => room = r);
      await ann.sit(id, _seat('a', _hostFour));
      await bo.sit(id, _seat('b', _guestFour));
      await _settle();
      // Joined: no longer an invitation.
      expect(bo.invites, isEmpty);
      expect(room!.hostSeat!.team.length, 4);
      expect(room!.guestSeat!.player, 'Player b');
      expect(room!.arena, 'orrery');
      // Not ready: no start.
      expect(room!.canStart, isFalse);
      await ann.start(room!);
      await _settle();
      expect(room!.state, BattleRoomState.lobby);
      await bo.setReady(room!, true);
      await _settle();
      expect(room!.canStart, isTrue);
      await ann.start(room!);
      await _settle();
      expect(room!.state, BattleRoomState.fighting);
      expect(room!.run, 1);
      expect(room!.startAt, isNotNull);
      // The READY was for the fight before: not ready for the next.
      expect(room!.isReady('b'), isFalse);
      // The stream: packets into eight documents in turn.
      final got = <int>[];
      final packets = bo.packets(id, 1).listen((p) => got.add(p.$1));
      for (var seq = 0; seq < 11; seq++) {
        ann.sendPacket(id, 1, seq, [kBattleLinkVersion, 0, 0, seq]);
        await _settle();
      }
      expect(got, [for (var i = 0; i < 11; i++) i]);
      final docs = await fs
          .collection('battle_rooms')
          .doc(id)
          .collection('stream')
          .get();
      expect(docs.docs.length, kBattleStreamSlots);
      // Another fight's packets are not this one's.
      ann.sendPacket(id, 2, 99, [kBattleLinkVersion]);
      await _settle();
      expect(got.last, 10);
      // The guest's inputs: the whole list each time.
      bo.sendInputs(id, 1, const [BattleInput.focus(2)], 1);
      await _settle();
      bo.sendInputs(id, 1, const [
        BattleInput.focus(2),
        BattleInput.swap(3, 0),
      ], 2);
      await _settle();
      expect(room!.inputsFor(1), const [
        BattleInput.focus(2),
        BattleInput.swap(3, 0),
      ]);
      expect(room!.beat, 2);
      expect(room!.inputsFor(2), isEmpty);
      // The end: back to the lobby with how it went.
      await ann.finish(
        room!,
        const BattleRoomResult(
          run: 1,
          winner: 'b',
          end: BattleWireEnd.fieldEmpty,
        ),
      );
      await _settle();
      expect(room!.state, BattleRoomState.lobby);
      expect(room!.result!.winner, 'b');
      // Again: ready, start; the old inputs go.
      await bo.setReady(room!, true);
      await _settle();
      await ann.start(room!);
      await _settle();
      expect(room!.run, 2);
      expect(room!.inputsFor(1), isEmpty);
      await packets.cancel();
      await sub.cancel();
    });

    test('a game too old to battle with cannot be readied against', () async {
      final ann = player('a', 'Ann');
      final bo = player('b', 'Bo');
      final id = await ann.host(
        arena: 'obsidian',
        invite: const FriendCard(uid: 'b', name: 'Bo'),
      );
      BattleRoom? room;
      final sub = ann.watch(id).listen((r) => room = r);
      await ann.sit(id, _seat('a', _hostFour));
      await bo.sit(id, _seat('b', _guestFour, version: kBattleLinkVersion - 1));
      await _settle();
      await bo.setReady(room!, true);
      await _settle();
      expect(room!.guestSeat!.current, isFalse);
      expect(room!.canStart, isFalse);
      await sub.cancel();
    });

    test('leaving, declining, taking a friend out, and closing', () async {
      final ann = player('a', 'Ann');
      final bo = player('b', 'Bo');
      final cy = player('c', 'Cy');
      await _settle();
      final id = await ann.host(
        arena: 'obsidian',
        invite: const FriendCard(uid: 'b', name: 'Bo'),
      );
      await _settle();
      BattleRoom? room;
      final sub = ann.watch(id).listen((r) => room = r);
      await _settle();
      // Bo says no: gone from the room, and from Bo's phone at once.
      await bo.decline(bo.invites.single);
      await _settle();
      expect(bo.invites, isEmpty);
      expect(room!.guest, isNull);
      // Cy asked instead, joins, then is taken out.
      await ann.invite(room!, const FriendCard(uid: 'c', name: 'Cy'));
      await _settle();
      expect(cy.invites.single.id, id);
      await cy.sit(id, _seat('c', _guestFour));
      await _settle();
      expect(room!.guestSeat?.uid, 'c');
      await ann.remove(room!);
      await _settle();
      expect(room!.guest, isNull);
      expect(room!.seats.containsKey('c'), isFalse);
      // Closed by the host: gone.
      await ann.leave(room!);
      await _settle();
      expect(room, isNull);
      await sub.cancel();
    });
  });

  test(
    'a fight carried by the room\'s stream: the guest has the host\'s',
    () async {
      final fs = FakeFirebaseFirestore();
      BattleRoomService player(String uid, String name) => BattleRoomService(
        account: _FakeAccount(_FakeUser(uid, name)),
        friends: _FakeFriends(),
        firestore: fs,
      );
      final ann = player('a', 'Ann');
      final bo = player('b', 'Bo');
      final id = await ann.host(
        arena: 'obsidian',
        invite: const FriendCard(uid: 'b', name: 'Bo'),
      );
      final hostSeat = _seat('a', _hostFour),
          guestSeat = _seat('b', _guestFour);
      var wall = 0;
      final (host, hc) = await battleArena();
      final (guest, gc) = await battleArena();
      final hostLink = BattleHostLink(
        game: host,
        now: () => wall,
        send: (seq, p) => ann.sendPacket(id, 1, seq, p),
      );
      final guestLink = BattleGuestLink(
        now: () => wall,
        send: (inputs, beat) => bo.sendInputs(id, 1, inputs, beat),
      );
      final subs = [
        bo.packets(id, 1).listen((p) => guestLink.packet(p.$1, p.$2)),
        ann.watch(id).listen((r) {
          if (r != null) hostLink.heard(r.inputsFor(1), r.beat);
        }),
      ];
      // Both phones build both fours from the seats, their own included.
      host.startBattle(
        home: hostSeat.members(null),
        away: guestSeat.members(null),
        awayAuto: false,
        center: hc,
        tape: hostLink.tape,
      );
      guest.startBattle(
        home: guestSeat.members(null),
        away: hostSeat.members(null),
        center: gc,
        replica: guestLink.playback,
      );
      final hb = host.battle!, gb = guest.battle!;
      var focused = false;
      for (var frame = 0; frame < 60 * 110; frame++) {
        wall = (frame * 1000 / 60).round();
        hostLink.tick();
        host.update(1 / 60);
        guestLink.tick(guest);
        guest.update(1 / 60);
        if (!focused && wall >= 3000) {
          focused = true;
          guest.predictBattleFocus(
            0,
            guestLink.input(const BattleInput.focus(0)),
          );
        }
        if (frame % 4 == 0) await _settle();
        if (hb.over && gb.over && (hb.sinceEnd ?? 0) > 3) break;
      }
      await _settle();
      expect(hb.over, isTrue);
      expect(gb.over, isTrue);
      expect(hb.remoteApplied, 1);
      final w = hb.result!.winner;
      expect(gb.result!.winner, w == null ? null : 1 - w);
      expect(gb.log.length, hb.log.length);
      for (final c in [for (final s in hb.sides) ...s.creatures]) {
        expect(c.member.instanceId, isNotEmpty);
      }
      // The breakdown on the guest's card is the host's.
      for (var s = 0; s < 2; s++) {
        for (var i = 0; i < 4; i++) {
          expect(
            gb.sides[1 - s].creatures[i].damageDealt,
            hb.sides[s].creatures[i].damageDealt.roundToDouble(),
          );
        }
      }
      for (final sub in subs) {
        await sub.cancel();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('the record with a friend is kept per friend', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = db.settingsDao;
    var bo = await BattleRecord.load(store, key: BattleRecord.friendKey('b'));
    bo = bo.after(0).after(0).after(1);
    await bo.save(store, key: BattleRecord.friendKey('b'));
    final again = await BattleRecord.load(
      store,
      key: BattleRecord.friendKey('b'),
    );
    expect((again.wins, again.losses, again.draws), (2, 1, 0));
    final cy = await BattleRecord.load(store, key: BattleRecord.friendKey('c'));
    expect(cy.played, 0);
    final computer = await BattleRecord.load(store);
    expect(computer.played, 0);
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
