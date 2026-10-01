@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/black_market_screen.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The black market on a phone, with real fonts and the real catalogue: the
// buy tab, the sell tab with resources on the table, the trade's
// confirmation, and a vial's details.
//
//   MARKET_OUT=/tmp/market flutter test \
//     test/black_market_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['MARKET_OUT'];

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

  testWidgets('black market preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    late ConstellationEffectsService constellations;
    late BlackMarketService market;
    await tester.runAsync(() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
      await db.constellationDao.unlockSkill('extraction_resource_alchemy', 0);
      await db.currencyDao.addGold(12);
      await db.currencyDao.addSilver(3450);
      await db.currencyDao.addResource('res_volcanic', 1240);
      await db.currencyDao.addResource('res_oceanic', 380);
      await db.currencyDao.addResource('res_verdant', 96);
      constellations = ConstellationEffectsService(db);
      market = BlackMarketService(db, constellations, catalog);
      await Future<void>.delayed(const Duration(milliseconds: 200));
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: constellations,
          ),
          ChangeNotifierProvider<BlackMarketService>.value(value: market),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const BlackMarketScreen(accent: Color(0xFFFFB74D)),
        ),
      ),
    );
    await settle(12);
    await shoot('1_buy');

    await tester.tap(find.text('SELL'));
    await settle();
    await tester.tap(find.text('½').first);
    await settle();
    await shoot('2_sell');

    await tester.tap(find.text('MAKE THE TRADE'));
    await settle();
    await shoot('3_confirm');
    await tester.tap(find.text('CANCEL'));
    await settle();

    await tester.tap(find.text('BUY').first);
    await settle();
    await tester.tap(find.textContaining(' Vial').first);
    await settle(10);
    await shoot('4_vial');

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    market.dispose();
    await tester.runAsync(db.close);
  });
}
