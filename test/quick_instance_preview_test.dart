@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The quick look on a phone, with real fonts and the Fire Horn: at rest in
// the middle of a list, and mid-swipe to the next.
//
//   QUICK_OUT=/tmp/quick flutter test \
//     test/quick_instance_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['QUICK_OUT'];

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

  Creature horn(String id, String name, String type, String sheet) => Creature(
    id: id,
    name: name,
    types: [type],
    rarity: 'Rare',
    description: 'preview',
    image: 'test.png',
    mutationFamily: 'Horn',
    spriteData: SpriteData(
      frameWidth: 1200,
      frameHeight: 1200,
      totalFrames: 4,
      frameDurationMs: 90,
      rows: 1,
      spriteSheetPath: 'creatures/rare/$sheet',
    ),
  );

  testWidgets('quick look preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final catalog = CreatureCatalog.fromList([
      horn('HOR01', 'Firehorn', 'Fire', 'HOR01_firehorn_spritesheet.png'),
      horn('HOR02', 'Waterhorn', 'Water', 'HOR02_waterhorn_spritesheet.png'),
    ]);
    late List<CreatureInstance> roster;
    await tester.runAsync(() async {
      for (final (id, base) in const [
        ('a', 'HOR02'),
        ('b', 'HOR01'),
        ('c', 'HOR02'),
      ]) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: base,
          level: 9,
        );
      }
      roster = [
        for (final id in const ['a', 'b', 'c'])
          (await db.creatureDao.getInstance(id))!,
      ];
      await saveCreatureBgForInstance(
        db,
        instanceId: 'c',
        option: creatureBgById('white'),
      );
    });
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final theme = FactionTheme.scorchForge();

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

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: theme),
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<StaminaService>.value(value: StaminaService(db)),
          ChangeNotifierProvider<ConstellationEffectsService>.value(
            value: ConstellationEffectsService(db),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: const Color(0xFF0B0A10),
              body: Center(
                child: TextButton(
                  onPressed: () => showQuickInstanceDialog(
                    context: context,
                    theme: theme,
                    creature: catalog.getCreatureById('HOR01')!,
                    instance: roster[1],
                    siblings: roster,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle();
    await shoot('0_revealing');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await shoot('1_rest');

    final drag = await tester.startGesture(const Offset(330, 400));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(-25, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle();
    await shoot('2_mid_swipe');
    await drag.moveBy(const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await drag.up();
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await settle();
    await shoot('3_next_white');

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
