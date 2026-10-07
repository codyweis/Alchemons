@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/alchemy_effect_apply.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/show_quick_instance_dialog.dart';
import 'package:alchemons/widgets/creature_detail/worn_strip.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// What it wears, on both details views: the strip in its states, the quick
// look wearing some, and the effect sheet.
//
//   WORN_OUT=/tmp/worn flutter test test/worn_strip_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['WORN_OUT'];

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

  testWidgets('worn strip preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final db = AlchemonsDatabase(NativeDatabase.memory());
    final catalog = CreatureCatalog.fromList([
      horn('HOR01', 'Firehorn', 'Fire', 'HOR01_firehorn_spritesheet.png'),
    ]);
    late CreatureInstance bare, dressed, empty;
    await tester.runAsync(() async {
      for (final id in const ['bare', 'dressed', 'empty']) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: 'HOR01',
          level: 9,
        );
      }
      empty = (await db.creatureDao.getInstance('empty'))!;
      await db.inventoryDao.addItemQty(InvKeys.alchemyVolcanicAura, 2);
      await db.inventoryDao.addItemQty(InvKeys.alchemyGlow, 1);
      await db.inventoryDao.addItemQty(InvKeys.alchemyDustRing, 1);
      await db.inventoryDao.addItemQty(InvKeys.alchemySunglasses, 2);
      await db.inventoryDao.addItemQty(InvKeys.alchemyCelebration, 3);
      await applyAlchemyEffect(
        db,
        instanceId: 'dressed',
        itemKey: InvKeys.alchemyVolcanicAura,
      );
      await wearCostume(
        db,
        instanceId: 'dressed',
        costume: FamilyCostume.sunglasses,
        color: const Color(0xFF8A1C2B),
      );
      await wearCostume(
        db,
        instanceId: 'dressed',
        costume: FamilyCostume.partyHat,
      );
      bare = (await db.creatureDao.getInstance('bare'))!;
      dressed = (await db.creatureDao.getInstance('dressed'))!;
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

    Future<void> settle([int n = 8]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    Widget host(Widget home) => MultiProvider(
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
        home: home,
      ),
    );

    // 1. The strip alone, at the full details' width, in its three states.
    await tester.pumpWidget(
      host(
        Scaffold(
          backgroundColor: const Color(0xFF0A0806),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(14, 60, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WornStrip(instance: dressed, creatureName: 'Firehorn'),
                const SizedBox(height: 16),
                WornStrip(instance: bare, creatureName: 'Firehorn'),
                const SizedBox(height: 16),
                WornStrip(instance: empty, creatureName: 'Firehorn'),
              ],
            ),
          ),
        ),
      ),
    );
    await settle();
    await shoot('0_strips');

    // 2. The effect sheet.
    await tester.tap(find.text('Volcanic Aura').first);
    await settle(10);
    await shoot('1_effect_sheet');
    Navigator.of(tester.element(find.text('TAKE OFF'))).pop();
    await settle();

    // 3. The costumes sheet.
    await tester.tapAt(
      tester.getTopRight(find.byType(WornStrip).first) + const Offset(-20, 20),
    );
    await settle(10);
    await shoot('2_costume_sheet');
    Navigator.of(tester.element(find.text('COLOUR').first)).pop();
    await settle();

    // 4. The quick look, wearing them.
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            backgroundColor: const Color(0xFF0B0A10),
            body: Center(
              child: TextButton(
                onPressed: () => showQuickInstanceDialog(
                  context: context,
                  theme: theme,
                  creature: catalog.getCreatureById('HOR01')!,
                  instance: dressed,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle();
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await settle();
    await shoot('3_quick_look');

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
