@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/new_discovery_reveal_controller.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Creatures tab on a phone, in both themes, a few weeks into a save:
// the specimen cases it opens on, the species table (top, scrolled, and
// searched), and the specimens searched.
//
//   CREATURES_OUT=/tmp/creatures flutter test \
//     test/creatures_screen_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['CREATURES_OUT'];

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

  // (species, level, prismatic, effect, favourite)
  const owned = <(String, int, bool, String?, bool)>[
    ('LET01', 14, false, null, true),
    ('LET01', 6, false, null, false),
    ('LET02', 9, false, null, false),
    ('LET03', 11, false, 'alchemy_glow', false),
    ('LET04', 3, false, null, false),
    ('PIP01', 18, true, null, true),
    ('PIP02', 7, false, null, false),
    ('PIP04', 12, false, 'elemental_aura', false),
    ('HOR01', 22, false, null, true),
    ('HOR07', 10, false, null, false),
    ('MAN03', 8, false, null, false),
    ('MAN09', 16, false, 'prismatic_cascade', false),
    ('MSK04', 5, false, null, false),
    ('WNG05', 25, false, null, true),
    ('KIN02', 4, false, null, false),
    ('MYS06', 30, false, null, true),
    ('LET07', 2, false, null, false),
    ('PIP10', 6, false, null, false),
  ];

  for (final dark in [true, false]) {
    testWidgets('creatures tab preview (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final tag = dark ? 'dark' : 'light';

      final db = AlchemonsDatabase(NativeDatabase.memory());
      late CreatureCatalog catalog;
      late ConstellationEffectsService constellations;
      late List<CreatureEntry> entries;
      await tester.runAsync(() async {
        final json =
            jsonDecode(
                  File(
                    'assets/data/alchemons_creatures.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        catalog = CreatureCatalog.fromList([
          for (final c in json['creatures'] as List)
            Creature.fromJson(c as Map<String, dynamic>),
        ]);
        await db.settingsDao.setCreaturesTutorialSeen();
        for (final id in {for (final o in owned) o.$1}) {
          await db.creatureDao.addOrUpdateCreature(
            PlayerCreaturesCompanion(
              id: Value(id),
              discovered: const Value(true),
            ),
          );
        }
        var n = 0;
        for (final (base, level, prismatic, effect, fav) in owned) {
          final id = 'i${n++}';
          await db.creatureDao.insertInstance(
            instanceId: id,
            baseId: base,
            level: level,
            isPrismaticSkin: prismatic,
            alchemyEffect: effect,
            statSpeedPotential: 2.0 + (n % 3),
            statIntelligencePotential: 3.0 + (n % 2),
            statStrengthPotential: 2.5 + (n % 4) * 0.5,
            statBeautyPotential: 3.5,
          );
          if (fav) await db.creatureDao.setFavorite(id, true);
        }
        entries = await GameDataService(
          db: db,
          catalog: catalog,
        ).watchAllEntries().first;
        constellations = ConstellationEffectsService(db);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      final key = GlobalKey();
      Future<void> shoot(String name) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/${tag}_$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> settle([int frames = 8]) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 33));
        }
      }

      final theme = dark
          ? FactionTheme.scorchForge()
          : factionThemeFor(null, brightness: Brightness.light);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            Provider<CreatureCatalog>.value(value: catalog),
            Provider<StaminaService>.value(value: StaminaService(db)),
            ChangeNotifierProvider<ThemeNotifier>(
              create: (_) => _PlainFont(db),
            ),
            ChangeNotifierProvider<FactionService>.value(
              value: FactionService(db),
            ),
            Provider<CatalogData?>.value(
              value: CatalogData(
                elementRecipes: ElementRecipeConfig(recipes: const {}),
                familyRecipes: const FamilyRecipeConfig(recipes: {}),
                naturesLoaded: true,
                geneticsLoaded: true,
              ),
            ),
            Provider<List<CreatureEntry>?>.value(value: entries),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellations,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: const CreaturesScreen(),
          ),
        ),
      );
      await settle(30);
      await shoot('1_specimens');

      await tester.tap(find.textContaining('CATALOG').first);
      await settle(40);
      await shoot('2_catalog');

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -900),
      );
      await settle(30);
      await shoot('3_catalog_scrolled');

      await tester.enterText(find.byType(TextField).first, 'fire');
      await settle(20);
      await shoot('4_catalog_search');

      await tester.tap(find.textContaining('SPECIMENS').first);
      await settle(20);
      await shoot('5_specimens_search');

      // A new species files itself away: the catalog opens on its cell, which
      // pops in a gilt frame.
      await tester.enterText(find.byType(TextField).first, '');
      await settle(10);
      NewDiscoveryReveal.instance.pendingRevealCreatureId.value = 'LET13';
      await settle(5);
      await shoot('6_reveal');
      await settle(80);
      expect(NewDiscoveryReveal.instance.pendingRevealCreatureId.value, isNull);

      await tester.pumpWidget(const SizedBox());
      await settle(4);
      await tester.runAsync(db.close);
    });
  }
}

/// The app's font is fetched from Google at run time; a test has no network.
class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}
