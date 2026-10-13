import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/stadium/bout_screen.dart';
import 'package:alchemons/screens/stadium/race_lobby_screen.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The lobby of a race with friends: the host's lanes, a friend's seat
// coming in and READY, a computer taken out, START, and both going to the
// race on the shared gun; and a friend's side — READY UP, LEAVE.
//
//   LOBBY_OUT=/tmp/lobby flutter test test/race_lobby_test.dart
// also writes frames (LOBBY_SIZE=475x751 for the Fold).

class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}

void main() {
  final out = Platform.environment['LOBBY_OUT'];
  final sizeArg = Platform.environment['LOBBY_SIZE'] ?? '390x844';
  final size = Size(
    double.parse(sizeArg.split('x')[0]),
    double.parse(sizeArg.split('x')[1]),
  );

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
  });

  /// Ann hosts a room with Bo asked; the lobby opens on [viewer]'s phone
  /// (a page that opens it, so it can be left).
  Future<_Lobby> openLobby(
    WidgetTester tester, {
    String viewer = 'a',
    String? progress,
  }) async {
    SharedPreferences.setMockInitialValues({RaceProgress.prefsKey: ?progress});
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final fs = FakeFirebaseFirestore();
    late CreatureCatalog catalog;
    late ConstellationEffectsService constellations;
    await tester.runAsync(() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
      await db.creatureDao.addOrUpdateCreature(
        const PlayerCreaturesCompanion(
          id: Value('WNG05'),
          discovered: Value(true),
        ),
      );
      await db.creatureDao.insertInstance(
        instanceId: 'mine',
        baseId: 'WNG05',
        level: 10,
        staminaBars: 3,
        statSpeed: 5.2,
        statIntelligence: 4,
        statStrength: 3.6,
        statBeauty: 4.4,
        statSpeedPotential: 90,
        statIntelligencePotential: 70,
        statStrengthPotential: 60,
        statBeautyPotential: 80,
      );
      constellations = ConstellationEffectsService(db);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    final ann = RaceRoomService(
      account: _FakeAccount(_FakeUser('a', 'Ann')),
      friends: _FakeFriends(),
      firestore: fs,
    );
    final bo = RaceRoomService(
      account: _FakeAccount(_FakeUser('b', 'Bo')),
      friends: _FakeFriends(),
      firestore: fs,
    );
    addTearDown(ann.dispose);
    addTearDown(bo.dispose);
    late String roomId;
    await tester.runAsync(() async {
      roomId = await ann.host(
        cup: 1,
        race: 0,
        invite: [const FriendCard(uid: 'b', name: 'Bo')],
      );
    });

    final shot = GlobalKey();
    var frame = 0;
    Future<void> snap(String name) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      await tester.runAsync(() async {
        final b =
            shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${(frame++).toString().padLeft(3, '0')}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> settle([int frames = 8]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    final theme = factionThemeFor(null, brightness: Brightness.dark);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: theme),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<StaminaService>.value(value: StaminaService(db)),
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => _PlainFont(db)),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellations,
          ),
          ChangeNotifierProvider<RaceRoomService>.value(
            value: viewer == 'a' ? ann : bo,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) =>
              RepaintBoundary(key: shot, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => RaceLobbyScreen.open(context, roomId),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    return _Lobby(ann, bo, roomId, snap, settle);
  }

  Future<void> boSits(WidgetTester tester, _Lobby l) => tester.runAsync(
    () => l.bo.sit(
      l.roomId,
      RaceSeat(
        uid: 'b',
        player: 'Bo',
        instanceId: 'his',
        entrant: const ContestEntrant(
          name: 'Ember',
          element: 'Fire',
          family: 'mane',
          statRating: 0,
        ),
        ratings: const {
          CosmicContestTrait.speed: 5.1,
          CosmicContestTrait.strength: 4.4,
          CosmicContestTrait.intelligence: 3.8,
          CosmicContestTrait.beauty: 4.0,
        },
        boosts: 3,
        look: const ResidentLook(baseId: 'MAN03'),
      ),
    ),
  );

  Future<RaceRoom> roomOf(WidgetTester tester, _Lobby l) async =>
      (await tester.runAsync(() => l.ann.watch(l.roomId).first))!;

  testWidgets('a friend joins and readies, the host starts, both race', (
    tester,
  ) async {
    final l = await openLobby(tester);
    final settle = l.settle, snap = l.snap;
    await settle(12);
    // Ann is in; Bo is asked; the cup's rivals fill four lanes.
    expect(find.text('WITH FRIENDS'), findsOneWidget);
    expect(find.text('Ann · YOU'), findsOneWidget);
    expect(find.text('HOST'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('ASKED · NOT IN YET'), findsOneWidget);
    expect(find.text('WAITING FOR FRIENDS TO JOIN'), findsOneWidget);
    expect(find.textContaining('COMPUTER ·'), findsNWidgets(4));
    await snap('asked');

    // Bo comes in, not ready: START waits on him.
    await boSits(tester, l);
    await settle(6);
    expect(find.text('ASKED · NOT IN YET'), findsNothing);
    expect(find.text('NOT READY'), findsOneWidget);
    expect(find.text('WAITING FOR BO TO GET READY'), findsOneWidget);
    await tester.tap(find.text('START'));
    await settle(4);
    expect((await roomOf(tester, l)).state, RaceRoomState.lobby);
    await snap('joined');

    // Bo readies.
    await tester.runAsync(
      () async => l.bo.setReady((await l.bo.watch(l.roomId).first)!, true),
    );
    await settle(6);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('EVERYONE IS READY'), findsOneWidget);

    // Ann takes a computer out: its lane stands open, one to put back.
    final cpu = find.ancestor(
      of: find.textContaining('COMPUTER ·').first,
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: cpu.first, matching: find.byType(BracketIconButton)),
    );
    await settle(6);
    expect(find.textContaining('COMPUTER ·'), findsNWidgets(3));
    expect(find.text('OPEN LANE'), findsOneWidget);
    expect(find.text('ADD COMPUTER'), findsOneWidget);
    expect((await roomOf(tester, l)).cpu, 3);
    await snap('lane_open');

    // START: the race comes up sideways, on the shared gun.
    final turns = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          final first = (call.arguments as List).first as String;
          turns.add(first);
          tester.view.physicalSize =
              (first.contains('landscape') ? size.flipped : size) * 2;
        }
        return null;
      },
    );
    const rotation = MethodChannel('alchemons/rotation');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      rotation,
      (call) async => null,
    );
    addTearDown(() {
      final m = tester.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(rotation, null);
    });
    await tester.tap(find.text('START'));
    for (var i = 0; i < 200 && turns.isEmpty; i++) {
      await settle(1);
    }
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(turns.first, contains('landscape'));
    final race = tester.widget<RaceScreen>(find.byType(RaceScreen));
    expect(race.live, isNotNull);
    // Five racers: the open lane stays empty at the back.
    expect(race.racers.length, 5);
    expect(race.racers.where((r) => r.isPlayer).single.id, 'live:a');
    expect(race.racers.map((r) => r.id).skip(3), ['live:a', 'live:b']);
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('race');
  });

  testWidgets('gems: the host turns to the island, both fight it', (
    tester,
  ) async {
    // The Silver Cup won: the Ruby Cup's first bout is open.
    final l = await openLobby(tester, progress: '{"copper":3,"silver":3}');
    await l.settle(12);
    await tester.tap(find.text('GEMS'));
    await l.settle(6);
    final gem = await roomOf(tester, l);
    expect(gem.gem, isTrue);
    expect(gem.placeName, kGemCups[0].bouts[0].name);
    expect(find.text(kGemCups[0].bouts[0].name.toUpperCase()), findsOneWidget);
    // Three to a bout: Ann, Bo asked, one of the bout's rivals.
    expect(find.textContaining('COMPUTER ·'), findsOneWidget);
    await boSits(tester, l);
    await tester.runAsync(
      () async => l.bo.setReady((await l.bo.watch(l.roomId).first)!, true),
    );
    await l.settle(6);
    expect(find.text('EVERYONE IS READY'), findsOneWidget);
    await l.snap('gem_lobby');

    await tester.tap(find.text('START'));
    for (
      var i = 0;
      i < 200 && find.byType(BoutScreen).evaluate().isEmpty;
      i++
    ) {
      await l.settle(1);
    }
    final bout = tester.widget<BoutScreen>(find.byType(BoutScreen));
    expect(bout.live, isNotNull);
    expect(bout.fighters.map((f) => f.id).skip(1), ['live:a', 'live:b']);
    // To the gun (on the wall clock) and into the fight.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 10)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('CHARGE'), findsOneWidget);
    await l.snap('gem_bout');
  });

  testWidgets('a friend readies up, and leaves', (tester) async {
    final l = await openLobby(tester, viewer: 'b');
    await l.settle(12);
    // Bo's phone sits him with his own racer.
    expect(find.text('Bo · YOU'), findsOneWidget);
    expect(find.text('CHANGE'), findsOneWidget);
    expect(find.text('ANN STARTS WHEN EVERYONE IS READY'), findsOneWidget);
    expect(find.text('LEAVE'), findsOneWidget);
    await l.snap('friend');

    await tester.tap(find.text('READY UP'));
    await l.settle(6);
    expect(find.text('NOT READY'), findsOneWidget);
    expect(find.text('READY · ANN STARTS THE RACE'), findsOneWidget);
    expect((await roomOf(tester, l)).isReady('b'), isTrue);
    await l.snap('friend_ready');

    await tester.tap(find.text('LEAVE'));
    await l.settle(12);
    expect(find.byType(RaceLobbyScreen), findsNothing);
    final room = await roomOf(tester, l);
    expect(room.invited, ['a']);
    expect(room.seats, isEmpty);
    expect(room.ready, isEmpty);
  });
}

typedef _Snap = Future<void> Function(String name);
typedef _Settle = Future<void> Function([int frames]);

class _Lobby {
  _Lobby(this.ann, this.bo, this.roomId, this.snap, this.settle);
  final RaceRoomService ann, bo;
  final String roomId;
  final _Snap snap;
  final _Settle settle;
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
