@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/inventory_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The inventory on a phone, a few weeks in, something on every shelf.
//
//   INVENTORY_OUT=/tmp/inv flutter test \
//     test/inventory_screen_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['INVENTORY_OUT'];

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
  });

  testWidgets('inventory preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    // The dock's 60 under the home indicator, as the app shell gives it.
    tester.view.padding = const FakeViewPadding(top: 44 * 3, bottom: 90 * 3);
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
      await db.currencyDao.addGold(47);
      await db.currencyDao.addSilver(13850);
      var n = 0;
      for (final key in ElementResources.settingsKeys) {
        await db.currencyDao.addResource(key, n++ == 4 ? 0 : 125 + n * 140);
      }
      final inv = db.inventoryDao;
      for (final (key, qty) in [
        (InvKeys.harvesterStdEarthen, 1),
        (InvKeys.harvesterStdOceanic, 1),
        (InvKeys.harvesterStdVerdant, 2),
        (InvKeys.harvesterStdVolcanic, 1),
        (InvKeys.harvesterGuaranteed, 1),
        (InvKeys.instantHatch, 1),
        (InvKeys.staminaPotion, 3),
        (InvKeys.wildFusion, 10),
        (InvKeys.wildlifeLure, 2),
        (InvKeys.portalKeyArcane, 1),
        (InvKeys.alchemyGlow, 1),
        (InvKeys.alchemyVoidRift, 1),
        (InvKeys.alchemyPrismaticCascade, 1),
        (InvKeys.alchemyCelebration, 1),
        (BossLootKeys.traitKeyForElement('fire'), 1),
        (BossLootKeys.traitKeyForElement('water'), 1),
      ]) {
        await inv.addItemQty(key, qty);
      }
      await inv.addVial('Oceanic Vial', ElementalGroup.oceanic, VialRarity.common);
      await inv.addVial(
        'Tidecaller',
        ElementalGroup.oceanic,
        VialRarity.rare,
        qty: 2,
      );
      await inv.addVial('Cinder Draught', ElementalGroup.volcanic, VialRarity.uncommon);
      await inv.addVial('Verdant Vial', ElementalGroup.verdant, VialRarity.common);
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
      FactionId.volcanic,
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
          ChangeNotifierProvider(create: (_) => InventoryService(db)),
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
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const InventoryScreen(),
        ),
      ),
    );
    await settle(40);
    await shoot('01_top');
    await tester.dragFrom(const Offset(195, 600), const Offset(0, -500));
    await settle(16);
    await shoot('02_scrolled');
    // Along the items' shelf.
    final items = find.text('Stabilized Harvester');
    if (items.evaluate().isNotEmpty) {
      await tester.drag(items.first, const Offset(-300, 0));
      await settle(16);
      await shoot('03_items_shelf_along');
    }

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.runAsync(db.close);
  });
}
