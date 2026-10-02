@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/home_planet_menu_overlay.dart';
import 'package:alchemons/screens/cosmic/widgets/ship_menu_overlay.dart';
import 'package:drift/native.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The ship console and the home base window on the Fold (about 475 × 751
// points), mid-game, with the real home planet painter behind them.
//
//   PANELS_OUT=/tmp/panels flutter test \
//     test/cosmic_panels_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PANELS_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
  });

  HomePlanet planet() => HomePlanet(
    position: Offset.zero,
    astralBank: 820,
    sizeTierLevel: 2,
    activeSizeTier: 2,
    activeColor: 'Water',
    unlockedColors: {'Water', 'Fire'},
  );

  final storage = ElementStorage(
    stored: const {
      'Fire': 640,
      'Water': 310,
      'Lightning': 220,
      'Earth': 140,
      'Air': 95,
      'Ice': 60,
      'Dark': 30,
      'Plant': 120,
      'Crystal': 12,
    },
  );

  const stats = HomeBaseStats(
    gold: 1240,
    silver: 18400,
    soft: 36,
    shardsCarried: 140,
    shardCapacity: 400,
    astralBank: 820,
    dustCollected: 37,
    dustTotal: 120,
    garrisonStationed: 1,
    garrisonSlots: 3,
    fuel: 60,
    fuelCapacity: 150,
    cargoTierName: 'Cargo Hold',
  );

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function(CosmicGame game) panel, {
    double height = 751,
  }) async {
    Directory(out!).createSync(recursive: true);
    tester.view.physicalSize = Size(475 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final home = planet();
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await tester.runAsync(game.onLoad);
    game.onGameResize(Vector2(475, 751));
    game.restoreHomePlanet(home);
    game.activeCustomizations = {'planetary_rings'};

    final db = AlchemonsDatabase(NativeDatabase.memory());
    final key = GlobalKey();
    await tester.pumpWidget(
      Provider<AlchemonsDatabase>.value(
        value: db,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFF05060A),
            body: Stack(children: [Positioned.fill(child: panel(game))]),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  }

  Widget ship(CosmicGame game, {bool hasHome = true, bool nearHome = true}) =>
      ShipMenuOverlay(
        hasHomePlanet: hasHome,
        meterFill: 0.34,
        walletShards: 140,
        shipHealth: 82,
        shipMaxHealth: 100,
        fuelFraction: 0.4,
        activeWeaponName: 'PULSE REPEATER',
        orbitalStockpile: 4,
        orbitalActive: 2,
        hasBooster: true,
        hasOrbitals: true,
        hasMissiles: true,
        missileAmmo: 6,
        cargoLevel: 1,
        isNearHome: nearHome,
        hasRefuelStation: true,
        hasSentinelStation: false,
        hasMatterInjector: true,
        matterBoostEnabled: true,
        onToggleMatterBoost: (_) {},
        hasParty: true,
        onParty: () {},
        onClose: () {},
        onBuildHome: () {},
        onRelocateHome: () {},
        onJettisonCargo: () {},
        onDumpWallet: () {},
        onRefuel: () {},
        onCraftMissiles: () {},
        onCraftSentinels: () {},
        onUpgradeCargo: () {},
        shipSkin: 'skin_phantom',
        ammoName: 'Storm Bolts',
        elementStorage: storage,
      );

  testWidgets('ship console', (tester) async {
    if (out == null) return;
    await shoot(tester, 'ship_console', (g) => ship(g));
    await shoot(tester, 'ship_console_away', (g) => ship(g, nearHome: false));
    await shoot(tester, 'ship_console_no_home', (g) => ship(g, hasHome: false));
  });

  testWidgets('home base window', (tester) async {
    if (out == null) return;
    await shoot(
      tester,
      'home_base',
      (g) => HomePlanetMenuOverlay(
        homePlanet: g.homePlanet!,
        elementStorage: storage,
        stats: stats,
        onCustomize: () {},
        onClose: () {},
        paintHome: g.paintHomeShowcase,
        wearing: const {'planetary_rings', 'spirit_wisps'},
      ),
    );
  });
}
