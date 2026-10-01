@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/screens/shop/alchemon_exchange_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The specimen exchange on a phone, in both themes: nothing chosen, the vial
// picker, the counter with specimens and vials, and the sale's confirmation.
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
        await db.inventoryDao.addVial(
          'Volcanic Vial',
          ElementalGroup.volcanic,
          VialRarity.uncommon,
          qty: 3,
        );
        await db.inventoryDao.addVial(
          'Oceanic Vial',
          ElementalGroup.oceanic,
          VialRarity.rare,
          qty: 1,
        );
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
      await tester.tap(find.text('VIALS'));
      // The sheet slides up over a quarter second.
      await settle(16);
      // Two of the stack, and the single one.
      final plus = find.byIcon(AppIcons.add_rounded).hitTestable();
      await tester.tap(plus.first);
      await settle(2);
      await tester.tap(plus.first);
      await settle(4);
      await shoot('2_vial_picker');
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
