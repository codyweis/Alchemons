@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/services/breeding_config.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/instance_widgets/instance_sheet_components.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The specimen picker that slides up over fusion (and harvest, the
// exchange, the home biome): choosing the first of a pair, the second with
// the first already in its chamber, sorted by a stat, and the exchange's
// multi-select with a sale price on every case.
//
//   PICKER_OUT=/tmp/picker flutter test \
//     test/specimen_picker_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['PICKER_OUT'];

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

  // (species, level, prismatic, favourite, stamina)
  const owned = <(String, int, bool, bool, int)>[
    ('LET01', 14, false, true, 3),
    ('LET01', 6, false, false, 2),
    ('LET02', 9, false, false, 3),
    ('LET03', 11, false, false, 0),
    ('LET04', 3, false, false, 3),
    ('PIP01', 18, true, true, 3),
    ('PIP02', 7, false, false, 1),
    ('PIP04', 12, false, false, 3),
    ('HOR01', 22, false, true, 3),
    ('HOR07', 10, false, false, 0),
    ('MAN03', 8, false, false, 3),
    ('MAN09', 16, false, false, 2),
    ('MSK04', 5, false, false, 3),
    ('WNG05', 25, false, true, 3),
    ('KIN02', 4, false, false, 3),
    ('LET07', 2, false, false, 3),
    ('PIP10', 6, false, false, 3),
  ];

  testWidgets('specimen picker preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
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
      for (final id in {for (final o in owned) o.$1}) {
        await db.creatureDao.addOrUpdateCreature(
          PlayerCreaturesCompanion(
            id: Value(id),
            discovered: const Value(true),
          ),
        );
      }
      var n = 0;
      for (final (base, level, prismatic, fav, bars) in owned) {
        final id = 'i${n++}';
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: base,
          level: level,
          isPrismaticSkin: prismatic,
          staminaBars: bars,
          statSpeed: 1.5 + (n % 5) * 0.7,
          statIntelligence: 2.0 + (n % 3) * 0.9,
          statStrength: 1.0 + (n % 4) * 0.8,
          statBeauty: 2.5 + (n % 2) * 1.1,
          statSpeedPotential: 2.0 + (n % 3),
          statIntelligencePotential: 3.0 + (n % 2),
          statStrengthPotential: 2.5 + (n % 4) * 0.5,
          statBeautyPotential: 3.5,
        );
        if (fav) await db.creatureDao.setFavorite(id, true);
      }
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
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
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

    final theme = factionThemeFor(null, brightness: Brightness.dark);
    Future<void> show(Widget page) async {
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
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellations,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: page,
          ),
        ),
      );
      await settle(30);
    }

    // Fusion, the first of the pair.
    await show(
      AllSpecimensPage(
        key: UniqueKey(),
        theme: theme,
        instancePrefsScopeKey: 'preview_fusion_a',
        popOnSelect: true,
        title: 'CHOOSE TO FUSE',
      ),
    );
    await shoot('1_fusion_first');

    // The second, with the first already in its chamber.
    await show(
      AllSpecimensPage(
        key: UniqueKey(),
        theme: theme,
        instancePrefsScopeKey: 'preview_fusion_b',
        popOnSelect: true,
        title: 'FUSE WITH FIRELET',
        selectedInstanceIds: const ['i0'],
      ),
    );
    await shoot('2_fusion_second');

    // Sorted by a stat.
    await tester.tap(find.text('STATS'));
    await settle(10);
    await shoot('3_fusion_stat_sort');

    // Filters open.
    await tester.tap(find.textContaining('FILTER').first);
    await settle(10);
    await shoot('4_fusion_filters');

    // The exchange: several at once, each with its price.
    await show(
      AllSpecimensPage(
        key: UniqueKey(),
        theme: theme,
        instancePrefsScopeKey: 'preview_exchange',
        title: 'SELECT SPECIMENS',
        selectionMode: true,
        closeReturnsSelection: true,
        selectedInstanceIds: const ['i2', 'i6'],
        cardBadgeBuilder: (inst, species) => InstanceCardValueBadge(
          amount: 40 + inst.level * 12,
          kind: CoinKind.silver,
          theme: theme,
        ),
        onConfirmSelection: (_) {},
      ),
    );
    await shoot('5_exchange');

    // Larger text, as the Fold's monospace runs: nothing may overflow.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(
      AllSpecimensPage(
        key: UniqueKey(),
        theme: theme,
        instancePrefsScopeKey: 'preview_fusion_large',
        popOnSelect: true,
        title: 'FUSE WITH LIGHTNINGHORN',
        selectedInstanceIds: const ['i9'],
      ),
    );
    await shoot('6_large_text');

    await tester.pumpWidget(const SizedBox());
    await settle(4);
    await tester.runAsync(db.close);
  });
}

/// The app's font is fetched from Google at run time; a test has no network.
class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}
