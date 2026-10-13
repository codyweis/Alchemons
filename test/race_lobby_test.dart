import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/stadium/race_room.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/stadium/race_lobby_screen.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/race_room_service.dart';
import 'package:alchemons/services/stamina_service.dart';
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
// coming in, START, and both going to the race on the shared gun.
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

  testWidgets('a friend joins, the host starts, both go to the race', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
          ChangeNotifierProvider<RaceRoomService>.value(value: ann),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) =>
              RepaintBoundary(key: shot, child: child!),
          home: RaceLobbyScreen(roomId: roomId),
        ),
      ),
    );
    await settle(12);
    // Ann is in; Bo is asked; the cup's rivals fill four lanes.
    expect(find.text('RACE WITH FRIENDS'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('ASKED · NOT IN YET'), findsOneWidget);
    expect(find.text('WAITING FOR FRIENDS'), findsOneWidget);
    await snap('asked');

    // Bo comes in.
    await tester.runAsync(() async {
      await bo.sit(
        roomId,
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
      );
    });
    await settle(6);
    expect(find.text('ASKED · NOT IN YET'), findsNothing);
    expect(find.text('HOST'), findsNothing);
    expect(find.text('START'), findsOneWidget);
    await snap('joined');

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
    expect(race.racers.length, 6);
    expect(race.racers.where((r) => r.isPlayer).single.id, 'live:a');
    expect(race.racers.map((r) => r.id).skip(4), ['live:a', 'live:b']);
    await snap('race');
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
