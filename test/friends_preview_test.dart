@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/screens/friends/friend_home_screen.dart';
import 'package:alchemons/screens/friends/friend_planet_screen.dart';
import 'package:alchemons/screens/friends/friends_panel.dart';
import 'package:alchemons/services/account_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/avatar_widget.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/home_planet_view.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Friends, drawn: a sheet of home planets as the FRIENDS list shows them,
// the panel itself, a friend's page with the circle drawn round their planet
// (shut, opening, open onto their live home), and the visit down there.
//
//   FRIENDS_OUT=/tmp/friends flutter test test/friends_preview_test.dart \
//     --tags preview
//
// FRIENDS_ONLY=planets,panel,page,visit picks sets.
void main() {
  final out = Platform.environment['FRIENDS_OUT'];
  final only = Platform.environment['FRIENDS_ONLY']?.split(',').toSet();
  bool wants(String set) => only == null || only.contains(set);

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
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

  const looks = <(String, PlanetLook?)>[
    ('none', null),
    ('tiny_fire', PlanetLook(color: 'Fire')),
    (
      'small_water_mist',
      PlanetLook(color: 'Water', size: 1, wearing: {'ocean_mist'}),
    ),
    (
      'medium_plant_vines',
      PlanetLook(color: 'Plant', size: 2, wearing: {'vine_tendrils'}),
    ),
    (
      'big_crystal_rings',
      PlanetLook(
        color: 'Crystal',
        size: 3,
        wearing: {'planetary_rings', 'orbiting_moon'},
      ),
    ),
    (
      'huge_void_hole',
      PlanetLook(color: 'Void', size: 4, wearing: {'black_hole'}),
    ),
    (
      'big_radiant_halo',
      PlanetLook(
        color: 'Radiant',
        size: 3,
        wearing: {'radiant_halo', 'spirit_wisps'},
      ),
    ),
    (
      'medium_lightning',
      PlanetLook(color: 'Lightning', size: 2, wearing: {'electric_field'}),
    ),
    (
      'huge_lava_flame',
      PlanetLook(
        color: 'Lava',
        size: 4,
        wearing: {'flame_ring', 'steam_vents'},
      ),
    ),
  ];

  testWidgets('friends preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    HttpOverrides.global = null;
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final channel in const [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
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
    final db = AlchemonsDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      GoogleFonts.cinzel(fontWeight: FontWeight.w700);
      // A friend's title.
      GoogleFonts.cinzel(fontWeight: FontWeight.w600);
      await GoogleFonts.pendingFonts();
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
          () => Future<void>.delayed(const Duration(milliseconds: 6)),
        );
        await tester.pump(Duration(milliseconds: ms));
      }
    }

    Widget app(Widget home, {FriendService? friends}) => MultiProvider(
      key: UniqueKey(),
      providers: [
        Provider<AlchemonsDatabase>.value(value: db),
        Provider<CreatureCatalog>.value(value: catalog),
        Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ChangeNotifierProvider<AccountService>(create: (_) => _FakeAccount()),
        if (friends != null)
          ChangeNotifierProvider<FriendService>.value(value: friends),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        builder: (context, child) => RepaintBoundary(key: key, child: child!),
        home: home,
      ),
    );

    void portrait() {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
    }

    addTearDown(tester.view.reset);

    // A household of a friend's: horns, a let, a pip, a mane, a flyer.
    const household = [
      HomeResident(instanceId: 'r1', x: 0.02),
      HomeResident(instanceId: 'r2', x: 0.105, flip: true),
      HomeResident(instanceId: 'r3', x: 0.19),
      HomeResident(instanceId: 'r4', x: 0.035, back: true),
      HomeResident(instanceId: 'r5', x: 0.13, lift: 0.3),
    ];
    final home = FriendHome(
      layout: HomeBiomeLayout(
        realm: HomeRealm.valley,
        hour: 17.5,
        residents: household,
        households: const {'valley': household},
      ),
      looks: const {
        'r1': ResidentLook(baseId: 'HOR01'),
        'r2': ResidentLook(baseId: 'LET12', prismatic: true),
        'r3': ResidentLook(baseId: 'PIP02'),
        'r4': ResidentLook(baseId: 'MAN09', trail: 'gilt_steps'),
        'r5': ResidentLook(baseId: 'WNG04'),
      },
      ambience: 'sun_motes',
    );
    const friend = FriendCard(
      uid: 'f1',
      name: 'Rowan',
      faction: 'oceanic',
      title: 'The Collector',
      featured: ResidentLook(baseId: 'LET02', effect: 'alchemy_glow'),
      planet: PlanetLook(
        color: 'Crystal',
        size: 3,
        wearing: {'planetary_rings'},
      ),
      trials: TrialsCard(
        won: {'copper': 3, 'silver': 3, 'gold': 1, 'ruby': 2},
        best: {
          'open': 37860,
          'rain': 41020,
          'ember': 44310,
          'storm': 46100,
          'hill': 49870,
          'night': 45520,
          'long': 61230,
          'sand_island': 18400,
          'ice_island': 26900,
        },
      ),
    );

    if (wants('planets')) {
      portrait();
      await tester.pumpWidget(
        app(
          Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (name, look) in looks)
                      SizedBox(
                        width: 112,
                        child: Column(
                          children: [
                            SizedBox.square(
                              dimension: 112,
                              child: HomePlanetView(
                                look: look,
                                fill: 0.62,
                                animate: false,
                              ),
                            ),
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settle(4);
      await shoot('planets');
    }

    if (wants('panel')) {
      portrait();
      final friends = _FakeFriends(
        friends: [
          for (final (i, (_, look)) in looks.skip(1).take(5).indexed)
            FriendCard(
              uid: 'u$i',
              name: const ['Rowan', 'Ash', 'Marlowe', 'Wren', 'Juniper'][i],
              faction: 'earthen',
              planet: look,
            ),
        ],
        incoming: const [
          FriendRequest(
            from: 'x1',
            to: 'me',
            fromName: 'Sable',
            fromFaction: 'volcanic',
          ),
        ],
        outgoing: const [
          FriendRequest(
            from: 'me',
            to: 'x2',
            fromName: 'Me',
            toCode: 'QK7MX2PB',
          ),
        ],
        online: const {'u0', 'u3'},
        seen: const {'u1': 'Seen 2 hours ago', 'u2': 'Seen 5 minutes ago'},
      );
      final theme = FactionTheme.scorchForge();
      final palette = BracketPalette.fromTheme(theme);
      await tester.pumpWidget(
        app(
          Scaffold(
            backgroundColor: palette.bg0,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ColoredBox(
                  color: palette.bg1,
                  child: FriendsPanel(
                    palette: palette,
                    accent: bracketReadableAccent(theme),
                    onSignIn: () {},
                  ),
                ),
              ),
            ),
          ),
          friends: friends,
        ),
      );
      await settle(4);
      await shoot('panel');
    }

    if (wants('avatar')) {
      portrait();
      final faction = FactionService(db);
      await tester.runAsync(() => faction.setId(FactionId.oceanic));
      await tester.pumpWidget(
        ChangeNotifierProvider<FactionService>.value(
          value: faction,
          child: app(
            Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AvatarButton(
                      theme: FactionTheme.scorchForge(),
                      onTap: () {},
                    ),
                    const SizedBox(width: 40),
                    ChangeNotifierProvider<FriendService>.value(
                      value: _FakeFriends(
                        incoming: const [
                          FriendRequest(from: 'x', to: 'me', fromName: 'Sable'),
                        ],
                      ),
                      child: AvatarButton(
                        theme: FactionTheme.scorchForge(),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settle(6);
      await shoot('avatar');
    }

    // FRIENDS_ONLY=records: their Trials row, and the records sheet set
    // against the player's own.
    if (wants('records')) {
      portrait();
      await tester.runAsync(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          TrialsRecords.prefsKey,
          const TrialsRecords({
            'open': TrialsRecord(value: 38100, by: 'Firemane'),
            'rain': TrialsRecord(value: 40550, by: 'Firemane'),
            'storm': TrialsRecord(value: 47200, by: 'Airwing'),
            'clear_night': TrialsRecord(value: 88, by: 'Icekin'),
          }).serialise(),
        );
      });
      await tester.pumpWidget(
        app(
          FriendPlanetScreen(friend: friend, loadHome: () async => home),
          friends: _FakeFriends(online: {friend.uid}),
        ),
      );
      await settle(30);
      await shoot('records_0_row');
      await tester.tap(find.text('RECORDS'));
      await settle(30);
      await shoot('records_1_sheet');
      await tester.pumpWidget(const SizedBox());
    }

    if (wants('page')) {
      portrait();
      await tester.pumpWidget(
        app(
          FriendPlanetScreen(friend: friend, loadHome: () async => home),
          friends: _FakeFriends(seen: {friend.uid: 'Seen 2 hours ago'}),
        ),
      );
      await settle(30);
      await shoot('page_0_seen');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(
          FriendPlanetScreen(friend: friend, loadHome: () async => home),
          friends: _FakeFriends(online: {friend.uid}),
        ),
      );
      await settle(30);
      await shoot('page_1_shut');
      // The circle, round the planet.
      final c = tester.getCenter(find.byType(HomePlanetView));
      final g = await tester.startGesture(c + const Offset(130, 0));
      for (var k = 1; k <= 40; k++) {
        final a = math.pi * 2 * k / 40;
        await g.moveTo(c + Offset(130 * math.cos(a), 130 * math.sin(a)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(18, ms: 16);
      await shoot('page_2_opening');
      await settle(60, ms: 33);
      for (
        var i = 0;
        i < 40 && find.byType(GameWidget<SceneGame>).evaluate().isEmpty;
        i++
      ) {
        await settle(1);
      }
      await settle(90, ms: 33);
      await shoot('page_3_open');
    }

    if (wants('noplanet')) {
      portrait();
      await tester.pumpWidget(
        app(
          FriendPlanetScreen(
            friend: const FriendCard(
              uid: 'f2',
              name: 'Wren',
              faction: 'verdant',
            ),
            loadHome: () async => home,
          ),
          friends: _FakeFriends(),
        ),
      );
      await settle(30);
      await shoot('noplanet');
    }

    if (wants('tap')) {
      portrait();
      await tester.pumpWidget(
        app(
          FriendPlanetScreen(friend: friend, loadHome: () async => home),
          friends: _FakeFriends(),
        ),
      );
      await settle(20);
      await tester.tap(find.byType(HomePlanetView));
      for (
        var i = 0;
        i < 150 && find.byType(FriendHomeScreen).evaluate().isEmpty;
        i++
      ) {
        await settle(1, ms: 16);
      }
      expect(find.byType(FriendHomeScreen), findsOneWidget);
      await settle(12, ms: 16);
      await shoot('tap_1_pouring');
      await settle(120, ms: 33);
      await shoot('tap_2_down');
    }

    if (wants('visit')) {
      tester.view.physicalSize = const Size(915 * 2.625, 412 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      tester.view.padding = FakeViewPadding.zero;
      await tester.pumpWidget(app(FriendHomeScreen(home: home, name: 'Rowan')));
      for (
        var i = 0;
        i < 40 && find.byType(GameWidget<SceneGame>).evaluate().isEmpty;
        i++
      ) {
        await settle(1);
      }
      await settle(80, ms: 33);
      await shoot('visit_1');
      final game = tester
          .widget<GameWidget<SceneGame>>(find.byType(GameWidget<SceneGame>))
          .game!;
      game.onResidentTap!('HOME_r3');
      await settle(20, ms: 33);
      await shoot('visit_2_tapped');
    }

    await tester.pumpWidget(const SizedBox());
    await settle(2);
  });
}

class _FakeAccount extends ChangeNotifier implements AccountService {
  @override
  bool get initialized => true;
  @override
  bool get isConfigured => true;
  @override
  bool get isSignedIn => true;
  @override
  String get displayName => 'Alchemist';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeFriends extends ChangeNotifier implements FriendService {
  _FakeFriends({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.online = const {},
    this.seen = const {},
  });

  final Set<String> online;
  final Map<String, String> seen;
  @override
  bool isOnline(String uid) => online.contains(uid);
  @override
  String? seenLabel(String uid) => online.contains(uid) ? null : seen[uid];

  @override
  final List<FriendCard> friends;
  @override
  final List<FriendRequest> incoming;
  @override
  final List<FriendRequest> outgoing;
  @override
  bool get available => true;
  @override
  String? get code => 'HX4N-7QRT';
  @override
  bool get loading => false;
  @override
  bool get loaded => true;
  @override
  String? get error => null;
  @override
  bool get hasRequests => incoming.isNotEmpty;
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
