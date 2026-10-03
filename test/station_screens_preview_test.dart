@Tags(['preview'])
library;

// The screens the space stations open, on the Fold (about 475 × 751 points),
// over a dark stand-in for the world.
//
//   STATIONS_OUT=/tmp/stations flutter test \
//     test/station_screens_preview_test.dart --tags preview

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/cosmic/cosmic_sell_sheet.dart';
import 'package:alchemons/screens/cosmic/gold_conversion_sheet.dart';
import 'package:alchemons/screens/cosmic/space_market_sheet.dart';
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart';
import 'package:alchemons/screens/cosmic/widgets/station_panel_kit.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final out = Platform.environment['STATIONS_OUT'];

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
    final home = Platform.environment['HOME'];
    const ph = 'hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts';
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
      ('PhosphorRegular', 'Phosphor.ttf'),
    ]) {
      await loadFont(
        'packages/phosphoricons_flutter/$family',
        '$home/.pub-cache/$ph/$file',
      );
    }
  });

  testWidgets('station screens', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(475 * 3, 751 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late CreatureCatalog catalog;
    late ConstellationEffectsService constellations;
    final meter = ElementMeter();
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
      await db.currencyDao.addSilver(3450);
      await db.currencyDao.addGold(42);
      for (final (id, base, level) in const [
        ('a', 'HOR01', 14),
        ('b', 'HOR09', 6),
        ('c', 'HOR16', 22),
        ('d', 'WIN03', 9),
        ('e', 'PIP05', 3),
      ]) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: base,
          level: level,
          source: id == 'e' ? 'discovery' : 'planet_summon',
          isPrismaticSkin: id == 'c',
        );
      }
      meter.add('Fire', 120);
      meter.add('Water', 60);
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

    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
          ChangeNotifierProvider<FactionService>.value(
            value: FactionService(db),
          ),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellations,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFF05040C),
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await settle(4);

    Future<void> sheet(String name, Future<void> Function() open) async {
      // ignore: unawaited_futures
      open();
      await settle(24);
      await shoot(name);
      Navigator.of(ctx).pop();
      await settle(12);
    }

    await sheet(
      'harvester_shop',
      () => SpaceMarketSheet.show(
        ctx,
        marketType: POIType.harvesterMarket,
        meter: meter,
        carriedShards: 140,
        spendShards: (_) => true,
      ),
    );
    await sheet(
      'rift_key_shop',
      () => SpaceMarketSheet.show(
        ctx,
        marketType: POIType.riftKeyMarket,
        meter: meter,
        carriedShards: 140,
        spendShards: (_) => true,
      ),
    );
    await sheet(
      'gold_conversion',
      () => GoldConversionSheet.show(
        ctx,
        carriedShards: 140,
        shardCapacity: 400,
        addShards: (_) {},
      ),
    );
    await sheet(
      'cosmic_market',
      () => CosmicSellSheet.show(
        ctx,
        carriedShards: 140,
        shardCapacity: 400,
        addShards: (_) {},
      ),
    );

    // The prompts that show when the ship comes alongside.
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFF05040C),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StationPrompt(
                      title: StationKind.harvester.title,
                      line: 'Harvesters for all five groups.',
                      action: 'ENTER SHOP',
                      accent: StationKind.harvester.accent,
                      onTap: () {},
                    ),
                    const SizedBox(height: 18),
                    StationPrompt(
                      title: StationKind.starDustScanner.title,
                      line: 'Points the radar at the nearest star dust.',
                      action: 'SCAN',
                      accent: StationKind.starDustScanner.accent,
                      trailing: const ShardAmount(50, size: 10.5),
                      onTap: () {},
                    ),
                    const SizedBox(height: 18),
                    StationPrompt(
                      title: StationKind.planetScanner.title,
                      line: 'Locked on. The radar points the way.',
                      action: 'TRACKING',
                      enabled: false,
                      accent: StationKind.planetScanner.accent,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(4);
    await shoot('prompts');

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.runAsync(db.close);
  });
}
