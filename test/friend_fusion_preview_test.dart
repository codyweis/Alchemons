@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload.dart' show EggPayloadFactory;
import 'package:alchemons/helpers/breeding_config_loaders.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/screens/friends/trade_screen.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/friend_fusion_lab.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/services/trade_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The table fusing, drawn, as one player sees it while their friend plays
// the other side live: switched to FUSE, both up, the friend confirming,
// the pour into the sigil and the cinematic frame by frame, and the table
// after, both still standing.
//
//   FUSION_OUT=/tmp/fusion flutter test test/friend_fusion_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['FUSION_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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

  testWidgets('fusion preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    HttpOverrides.global = null;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );
    SharedPreferences.setMockInitialValues({});

    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final catalog = CreatureCatalog.fromList([
      for (final c in (json['creatures'] as List).cast<Map<String, dynamic>>())
        Creature.fromJson(c),
    ]);
    final fs = FakeFirebaseFirestore();
    late _Player cody, sam;
    await tester.runAsync(() async {
      GoogleFonts.cinzel(fontWeight: FontWeight.w700);
      await GoogleFonts.pendingFonts();
      await loadNatures();
      await GeneticsCatalog.load();
      final element = await loadElementRecipes();
      final family = await loadFamilyRecipes();
      cody = _Player('aaaa', 'Cody', fs, catalog, element, family);
      sam = _Player('bbbb', 'Sam', fs, catalog, element, family);
      cody.friends.list = [sam.card];
      sam.friends.list = [cody.card];
      cody.friends.ping();
      sam.friends.ping();
      await cody.db.creatureDao.insertInstance(
        instanceId: 'C1',
        baseId: 'HOR01',
        level: 7,
        natureId: 'Brave',
        statSpeedPotential: 64,
        statIntelligencePotential: 58,
        statStrengthPotential: 91,
        statBeautyPotential: 72,
      );
      await cody.db.creatureDao.updateAlchemyEffect(
        instanceId: 'C1',
        effect: 'alchemy_glow',
      );
      await sam.db.creatureDao.insertInstance(
        instanceId: 'S1',
        baseId: 'HOR02',
        level: 9,
        nickname: 'Pebble',
        natureId: 'Calm',
        statSpeedPotential: 88,
        statIntelligencePotential: 77,
        statStrengthPotential: 69,
        statBeautyPotential: 95,
      );
      // Sam's stands in a garnet case.
      await sam.db.settingsDao.setSetting(
        'cosmetics_owned_v1',
        jsonEncode({
          'caseStyle': ['garnet'],
        }),
      );
      await sam.db.settingsDao.setSetting(
        CosmeticWear.caseKey,
        jsonEncode({'S1': 'garnet'}),
      );
    });

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> settle(int frames, {int ms = 33}) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 8)),
        );
        await tester.pump(Duration(milliseconds: ms));
      }
    }

    Future<void> act(Future<void> Function() f) async {
      await tester.runAsync(() async {
        await f();
        for (var i = 0; i < 6; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await cody.trades.idle;
          await sam.trades.idle;
        }
      });
      await settle(4);
    }

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
    addTearDown(tester.view.reset);

    Widget app(Widget home) => MultiProvider(
      providers: [
        Provider<AlchemonsDatabase>.value(value: cody.db),
        Provider<CreatureCatalog>.value(value: catalog),
        Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ChangeNotifierProvider<TradeService>.value(value: cody.trades),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        builder: (context, child) => RepaintBoundary(key: key, child: child!),
        home: home,
      ),
    );

    await tester.pumpWidget(app(TradeScreen(friend: sam.card)));
    await settle(10);
    await act(() => cody.trades.setMode(sam.card, TradeMode.fuse));
    await settle(12);
    await shoot('1_fuse_empty');

    await act(() => cody.trades.put(sam.card, 'C1'));
    await act(() => sam.trades.put(cody.card, 'S1'));
    await settle(20);
    await shoot('2_both_up');

    await act(() => sam.trades.confirm(cody.card));
    await settle(30);
    await shoot('3_they_confirmed');

    // Cody confirms: fused. The table plays it.
    await act(() => cody.trades.confirm(sam.card));
    await settle(30, ms: 33); // the screen's wait before reading the sprites
    for (final (name, ms) in const [
      ('4_pour_a', 300),
      ('4_pour_b', 500),
      ('4_pour_c', 500),
      ('4_pour_d', 500),
      ('4_pour_e', 500),
      ('4_pour_f', 500),
      ('5_cinematic_a', 600),
      ('5_cinematic_b', 900),
      ('5_cinematic_c', 900),
    ]) {
      await settle(1, ms: ms);
      await shoot(name);
    }
    await settle(140);
    await shoot('6_fused');

    final exceptions = <Object>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      exceptions.add(e!);
    }
    File('$out/exceptions.txt').writeAsStringSync(exceptions.join('\n\n'));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await cody.close();
      await sam.close();
    });
  });
}

class _Player {
  _Player(
    this.uid,
    this.name,
    FakeFirebaseFirestore fs,
    CreatureCatalog catalog,
    ElementRecipeConfig elementRecipes,
    FamilyRecipeConfig familyRecipes,
  ) : db = AlchemonsDatabase(NativeDatabase.memory()) {
    friends = _FakeFriends();
    trades = TradeService(
      account: _FakeAccount(_FakeUser(uid, name)),
      db: db,
      catalog: catalog,
      friends: friends,
      firestore: fs,
    );
    final breeding = BreedingServiceV2(
      gameData: GameDataService(db: db, catalog: catalog),
      db: db,
      engine: BreedingEngine(
        catalog,
        elementRecipes: elementRecipes,
        familyRecipes: familyRecipes,
        tuning: const BreedingTuning(),
      ),
      payloadFactory: EggPayloadFactory(catalog),
      wildRandomizer: WildCreatureRandomizer(),
      constellation: ConstellationEffectsService(db),
      factions: FactionService(db),
      boosts: TimedBoostService(db.settingsDao),
    );
    trades.attachLab(
      FriendFusionLab(breeding: breeding, stamina: StaminaService(db)),
    );
  }

  final String uid, name;
  final AlchemonsDatabase db;
  late final _FakeFriends friends;
  late final TradeService trades;

  FriendCard get card => FriendCard(uid: uid, name: name);

  Future<void> close() async {
    await trades.idle;
    trades.dispose();
    await db.close();
  }
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
  List<FriendCard> list = const [];
  void ping() => notifyListeners();
  @override
  List<FriendCard> get friends => list;
  @override
  bool get available => true;
  @override
  String? get code => 'HX4N-7QRT';
  @override
  bool get loaded => true;
  @override
  void publishSoon() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
