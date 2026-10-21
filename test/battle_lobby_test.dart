// Battling a friend, the lobby on two phones over one fake Firestore: both
// sit with their saved four, the friend readies, the host starts, both
// phones open the fight on the same start time (the guest's a replica of
// the host's), and the friend leaving it gives the host the win, kept in
// both head-to-heads.
//
//   BATTLE_LOBBY_OUT=dir flutter test test/battle_lobby_test.dart
//     pictures of the two lobbies and the fight.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/models/battle_record.dart';
import 'package:alchemons/models/battle_room.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/battle/battle_lobby_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/battle_room_service.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

void main() {
  final out = Platform.environment['BATTLE_LOBBY_OUT'];

  setUpAll(loadLobbyFonts);

  testWidgets(
    'two phones: join, ready, start, fight, the friend leaves',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      tester.view.physicalSize = Size(
        kLobbyPhysical.width * 2,
        kLobbyPhysical.height,
      );
      tester.view.devicePixelRatio = kLobbyDpr;
      addTearDown(tester.view.reset);
      final phone = kLobbyPhysical / kLobbyDpr;
      final annSave = await LobbySave.create(tester);
      final boSave = await LobbySave.create(tester);
      final fs = FakeFirebaseFirestore();
      final ann = BattleRoomService(
        account: _FakeAccount(_FakeUser('a', 'Ann')),
        friends: _FakeFriends(),
        firestore: fs,
      );
      final bo = BattleRoomService(
        account: _FakeAccount(_FakeUser('b', 'Bo')),
        friends: _FakeFriends(),
        firestore: fs,
      );
      final id = (await tester.runAsync(() async {
        await annSave.db.settingsDao.setBattleHowToSeen();
        await boSave.db.settingsDao.setBattleHowToSeen();
        // Made as the screens make it: not waited on.
        return ann.hostNow(
          arena: 'tidal',
          invite: const FriendCard(uid: 'b', name: 'Bo'),
        );
      }))!;
      BattleRoom? room;
      final sub = ann.watch(id).listen((r) => room = r);

      Widget phoneOf(String tag, LobbySave save, BattleRoomService rooms) =>
          SizedBox(
            key: ValueKey('phone.$tag'),
            width: phone.width,
            height: phone.height,
            child: MediaQuery(
              data: MediaQueryData(size: phone, devicePixelRatio: kLobbyDpr),
              child: ChangeNotifierProvider<BattleRoomService>.value(
                value: rooms,
                child: ChangeNotifierProvider<AudioController>.value(
                  value: SilentAudio(),
                  child: save.app(home: BattleLobbyScreen(roomId: id)),
                ),
              ),
            ),
          );

      final shot = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: shot,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [phoneOf('a', annSave, ann), phoneOf('b', boSave, bo)],
            ),
          ),
        ),
      );

      Future<void> shoot(String name) async {
        if (out == null) return;
        Directory(out).createSync(recursive: true);
        await tester.runAsync(() async {
          final boundary =
              shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 0.6);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Finder on(String tag, Finder f) =>
          find.descendant(of: find.byKey(ValueKey('phone.$tag')), matching: f);
      String status(String tag) => tester
          .widget<Text>(
            on(tag, find.byKey(const ValueKey('battle.lobby.status'))),
          )
          .data!;
      // Both sit with their four.
      for (var i = 0; i < 40 && (room?.seats.length ?? 0) < 2; i++) {
        await settleLobby(tester, 1);
      }
      await settleLobby(tester, 4);
      expect(room!.hostSeat!.team, isNotEmpty);
      expect(room!.guestSeat!.team, isNotEmpty);
      expect(status('a'), 'Waiting for Bo to be ready.');
      expect(status('b'), 'Ready up when your four are set.');
      // Each sees the other's four: the team preview.
      expect(on('a', find.text('BO\'S FOUR')), findsOneWidget);
      expect(on('b', find.text('ANN\'S FOUR')), findsOneWidget);
      expect(on('a', find.text('YOUR FIRST BATTLE WITH BO')), findsOneWidget);
      await shoot('lobby_joined');

      // Bo readies; Ann starts.
      await tester.tap(
        on('b', find.byKey(const ValueKey('battle.lobby.ready'))),
      );
      await settleLobby(tester, 4);
      expect(status('a'), 'Bo is ready.');
      expect(status('b'), 'Waiting for Ann to start.');
      await shoot('lobby_ready');
      await tester.tap(
        on('a', find.byKey(const ValueKey('battle.lobby.start'))),
      );
      await settleLobby(tester, 6);
      expect(room!.state, BattleRoomState.fighting);
      // Both open the fight, at the start time.
      List<CosmicGame> games() => [
        for (final w in tester.widgetList<GameWidget>(
          find.byWidgetPredicate((w) => w is GameWidget),
        ))
          w.game! as CosmicGame,
      ];
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        final g = games();
        if (g.length == 2 && g.every((g) => g.battle != null)) break;
      }
      final g = games();
      expect(g.length, 2);
      final host = g.firstWhere((g) => !g.battle!.isReplica).battle!;
      final guest = g.firstWhere((g) => g.battle!.isReplica).battle!;
      // Each phone's own four at the bottom.
      expect(
        host.sides[0].creatures.first.member.instanceId,
        room!.hostSeat!.team.first.id,
      );
      expect(
        guest.sides[0].creatures.first.member.instanceId,
        room!.guestSeat!.team.first.id,
      );
      // The fight runs, and the guest's phone plays it.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        if (i % 5 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
      }
      expect(host.clock, greaterThan(1));
      expect(guest.playback!.started, isTrue);
      await shoot('fight');
      // Bo leaves the fight: Ann wins it.
      await tester.tap(on('b', find.byType(BracketIconButton)).last);
      await tester.pump(const Duration(milliseconds: 400));
      final leave = on('b', find.text('LEAVE'));
      await tester.tap(leave.last);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(host.over, isTrue);
      expect(host.result!.winner, 0);
      expect(host.result!.end, BattleEnd.conceded);
      // Past the stream's last moment: the room is back between fights, with
      // how it ended.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(room!.state, BattleRoomState.lobby);
      expect(room!.result!.winner, 'a');
      final records = (await tester.runAsync(
        () async => (
          await BattleRecord.load(
            annSave.db.settingsDao,
            key: BattleRecord.friendKey('b'),
          ),
          await BattleRecord.load(
            boSave.db.settingsDao,
            key: BattleRecord.friendKey('a'),
          ),
        ),
      ))!;
      expect((records.$1.wins, records.$1.losses), (1, 0));
      expect((records.$2.wins, records.$2.losses), (0, 1));
      await shoot('after');

      // REMATCH on Ann's card: back to the lobby, and the next fight
      // starts as soon as Bo is ready.
      await tester.tap(on('a', find.text('REMATCH')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(
        on('a', find.byKey(const ValueKey('battle.lobby.start'))),
        findsOneWidget,
      );
      expect(status('a'), 'Waiting for Bo to be ready.');
      await tester.tap(
        on('b', find.byKey(const ValueKey('battle.lobby.ready'))),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(room!.state, BattleRoomState.fighting);
      expect(room!.run, 2);
      bool fighting(CosmicGame g) => g.battle != null && !g.battle!.over;
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        if (games().where(fighting).length == 2) break;
      }
      expect(games().where(fighting).length, 2);
      await shoot('rematch');

      unawaited(sub.cancel());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      ann.dispose();
      bo.dispose();
      await annSave.dispose(tester);
      await boSave.dispose(tester);
    },
  );
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
