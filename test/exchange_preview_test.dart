@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/screens/shop/alchemon_exchange_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/nursery/storage_section_widget.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The specimen exchange on a phone, in both themes: nothing chosen, the cold
// storage picker, the counter with specimens and stored cultivations, and the
// sale's confirmation.
//
//   EXCHANGE_OUT=/tmp/exchange flutter test \
//     test/exchange_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['EXCHANGE_OUT'];

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

  for (final dark in [true, false]) {
    testWidgets('exchange preview (${dark ? 'dark' : 'light'})', (
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
      late List<CreatureInstance> specimens;
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
        await db.currencyDao.addSilver(3450);
        for (final (id, base, level) in const [
          ('a', 'HOR01', 14),
          ('b', 'HOR09', 6),
          ('c', 'HOR16', 22),
        ]) {
          await db.creatureDao.insertInstance(
            instanceId: id,
            baseId: base,
            level: level,
          );
        }
        specimens = [
          for (final id in const ['a', 'b', 'c'])
            (await db.creatureDao.getInstance(id))!,
        ];
        // Cold storage: three cultivations waiting.
        await loadNatures();
        final payloads = EggPayloadFactory(catalog);
        for (final (id, base, hours) in const [
          ('s1', 'HOR01', 30),
          ('s2', 'LET05', 4),
          ('s3', 'HOR16', 90),
          ('s4', 'LET09', 12),
        ]) {
          final creature = catalog.getCreatureById(base)!;
          await db.incubatorDao.enqueueEgg(
            eggId: id,
            resultCreatureId: base,
            rarity: creature.rarity,
            remaining: Duration(hours: hours),
            payloadJson: payloads.createVialPayload(creature).toJsonString(),
          );
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
      Widget app(List<CreatureInstance> initial) => MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: theme),
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
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: AlchemonExchangeScreen(debugInitialSpecimens: initial),
        ),
      );

      await tester.pumpWidget(app(const []));
      await settle();
      await shoot('1_choose');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(specimens));
      await settle(14);
      await tester.tap(find.text('COLD STORAGE'));
      // The sheet slides up over a quarter second.
      await settle(16);
      // Two of the four put on the counter.
      final cells = find.byType(StasisCell);
      await tester.tap(cells.at(0));
      await settle(3);
      await tester.tap(cells.at(2));
      await settle(10);
      await shoot('2_storage_picker');
      await tester.tap(find.textContaining('PUT '));
      await settle(12);
      await shoot('3_counter');

      await tester.tap(find.text('COMPLETE SALE'));
      await settle();
      await shoot('4_confirm');

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.runAsync(db.close);
    });
  }
}
