@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/fx/codex_stage.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The Fusion Codex on a phone, in both themes, part-way through a save: the
// element table, the species table, an element opened (at rest and playing
// a formula), a locked one, and a species opened.
//
//   CODEX_SCREEN_OUT=/tmp/codex flutter test \
//     test/codex_screen_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['CODEX_SCREEN_OUT'];

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
    // Arial Unicode, for the formulas' ⊕ and ⟶.
    await loadFont(
      'Roboto',
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    );
  });

  for (final dark in [true, false]) {
    testWidgets('codex preview (${dark ? 'dark' : 'light'})', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final tag = dark ? 'dark' : 'light';

      final db = AlchemonsDatabase(NativeDatabase.memory());
      late CreatureCatalog catalog;
      late ConstellationEffectsService constellations;
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
        // Found: the four primal lets and pips, a fire horn, an ice mane.
        for (final id in const [
          'LET01',
          'LET02',
          'LET03',
          'LET04',
          'PIP01',
          'PIP02',
          'HOR01',
          'MAN09',
        ]) {
          await db.creatureDao.addOrUpdateCreature(
            PlayerCreaturesCompanion(
              id: Value(id),
              discovered: const Value(true),
            ),
          );
        }
        var n = 0;
        for (final base in const [
          'LET01',
          'LET01',
          'LET02',
          'PIP01',
          'HOR01',
        ]) {
          await db.creatureDao.insertInstance(
            instanceId: 'i${n++}',
            baseId: base,
            level: 5,
          );
        }
        await db.settingsDao.setSetting(
          'enc.element.outcomes.v2',
          jsonEncode([
            'Air+Water::Ice',
            'Fire+Water::Steam',
            'Air+Fire::Lightning',
            'Earth+Lightning::Crystal',
          ]),
        );
        await db.settingsDao.setSetting(
          'enc.family.outcomes.v2',
          jsonEncode(['Let+Pip::Mask', 'Let+Let::Mane']),
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
      await tester.pumpWidget(
        MultiProvider(
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
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: const AlchemicalEncyclopediaScreen(),
          ),
        ),
      );
      await settle(14);
      await shoot('1_elements');

      await tester.tap(find.text('SPECIES'));
      await settle(10);
      await shoot('2_species');

      await tester.tap(find.text('ELEMENTS'));
      await settle(4);
      await tester.tap(find.text('ICE'));
      // The sheet slides up, and Ice gathers into its orb.
      await settle(50);
      await shoot('3_ice');

      await tester.tap(find.byIcon(AppIcons.play_arrow_rounded).first);
      await settle(36);
      await shoot('4_ice_formula_playing');
      await settle(60);
      await shoot('5_ice_formula_done');

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(16);
      await tester.tap(find.text('BLOOD'));
      await settle(30);
      await shoot('6_blood_locked');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(16);

      await tester.tap(find.text('SPECIES'));
      await settle(6);
      await tester.tap(find.text('LET'));
      await settle(50);
      await shoot('7_let');
      await tester.tap(find.byIcon(AppIcons.play_arrow_rounded).last);
      await settle(30);
      await shoot('8_let_formula_merging');
      await settle(40);
      await shoot('9_let_formula_made');
      await settle(40);
      await tester.tap(find.byType(CodexStage));
      await settle(26);
      await shoot('10_essence');

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
