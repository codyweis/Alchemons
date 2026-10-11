@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/shop/shop_screen.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The shop on a phone: the top of each tab and a scroll down the supplies.
//
//   SHOP_OUT=/tmp/shop flutter test \
//     test/shop_screen_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['SHOP_OUT'];

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

  testWidgets('shop preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 30 * 3);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late CreatureCatalog catalog;
    HttpOverrides.global = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.createTempSync('fonts').path,
    );
    await tester.runAsync(() async {
      // Fetched before the first frame, or the first shots are boxes.
      GoogleFonts.imFellEnglishTextTheme();
      GoogleFonts.imFellEnglish(fontStyle: FontStyle.italic);
      await GoogleFonts.pendingFonts();
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
      // A Volcanic player: the shop sells Volcanic's two dock sets.
      await db.settingsDao.setSetting('player_faction_v1', 'volcanic');
      await db.currencyDao.addGold(184);
      await db.currencyDao.addSilver(12450);
      var n = 0;
      for (final key in ElementResources.settingsKeys) {
        await db.currencyDao.addResource(key, n++ == 3 ? 0 : 240 + n * 95);
      }
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

    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    final theme = factionThemeFor(
      FactionId.oceanic,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<FactionTheme>.value(value: theme),
          ChangeNotifierProvider<ThemeNotifier>(
            create: (_) => ThemeNotifier(db),
          ),
          ChangeNotifierProvider<ConstellationEffectsService>(
            create: (_) => ConstellationEffectsService(db),
          ),
          ChangeNotifierProvider<TimedBoostService>(
            create: (_) => TimedBoostService(db.settingsDao)..load(),
          ),
          ChangeNotifierProvider<FactionService>(
            create: (_) => FactionService(db)..loadId(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => BlackMarketService(
              db,
              ctx.read<ConstellationEffectsService>(),
              ctx.read<CreatureCatalog>(),
            ),
          ),
          ChangeNotifierProvider<MobileStoreService>(
            create: (_) => _FakeStore(),
          ),
          ChangeNotifierProvider(
            create: (ctx) => ShopService(
              db,
              ctx.read<ConstellationEffectsService>(),
              ctx.read<FactionService>(),
              ctx.read<TimedBoostService>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme.toMaterialTheme(
            GoogleFonts.imFellEnglishTextTheme(ThemeData.dark().textTheme),
          ),
          navigatorObservers: [routeObserver],
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const ShopScreen(),
        ),
      ),
    );
    await settle(40);
    await shoot('01_supplies');

    Future<void> scrollShot(String name, {double by = 650}) async {
      await tester.dragFrom(const Offset(195, 600), Offset(0, -by));
      await settle(16);
      await shoot(name);
    }

    await scrollShot('02_supplies_scrolled');
    await scrollShot('03_supplies_more');

    // The realms for sale, each its own live field.
    final scenes = find.text('SCENES');
    if (scenes.evaluate().isNotEmpty) {
      await tester.tap(scenes.first, warnIfMissed: false);
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      await shoot('06_scenes');
      // Down to the last of them.
      for (var i = 0; i < 3; i++) {
        await tester.dragFrom(const Offset(195, 600), const Offset(0, -700));
        await settle(10);
      }
      await shoot('07_scenes_last');
    }

    final cosmetics = find.text('COSMETICS');
    if (cosmetics.evaluate().isNotEmpty) {
      await tester.tap(cosmetics.first, warnIfMissed: false);
      await settle(30);
      await shoot('04_cosmetics');
      // A dock set for sale: the whole dock it would make.
      await tester.tap(find.text('Lavalet').first, warnIfMissed: false);
      await settle(20);
      await shoot('04b_dock_set_dialog');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(16);
      // Down to the home decor.
      for (var i = 0; i < 4; i++) {
        await tester.dragFrom(const Offset(195, 600), const Offset(0, -560));
        await settle(16);
        await shoot('05_cosmetics_home_$i');
      }
    }

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.runAsync(db.close);
  });
}

class _FakeStore extends ChangeNotifier implements MobileStoreService {
  @override
  List<GoldPackDefinition> get packDefinitions => const [
    GoldPackDefinition(
      productId: 'alchemons_gold_small',
      title: 'Pouch',
      subtitle: 'A little gold.',
      goldAmount: 20,
      badge: '',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_popular',
      title: 'Coffer',
      subtitle: 'The usual.',
      goldAmount: 120,
      badge: 'POPULAR',
    ),
    GoldPackDefinition(
      productId: 'alchemons_gold_celestial',
      title: 'Celestial',
      subtitle: 'Heavy stockpile.',
      goldAmount: 500,
      badge: 'PREMIUM',
    ),
  ];
  @override
  bool get isSupportedPlatform => true;
  @override
  bool get isLoading => false;
  @override
  bool get requiresSignIn => true;
  @override
  int get pendingRedeemCount => 0;
  @override
  String? get lastError => null;
  @override
  bool isPurchasePending(String productId) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
