@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The wilderness Items button on a phone, with real fonts and a well-stocked
// pack: the panel, and one item's details.
//
//   FIELD_INV_OUT=/tmp/field_inv flutter test \
//     test/field_inventory_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['FIELD_INV_OUT'];

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

  testWidgets('field inventory preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AlchemonsDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final pack = <String, int>{
        InvKeys.wildlifeLure: 3,
        InvKeys.wildFusion: 6,
        InvKeys.harvesterStdVolcanic: 2,
        InvKeys.harvesterStdOceanic: 1,
        InvKeys.harvesterGuaranteed: 1,
        InvKeys.staminaPotion: 4,
        InvKeys.portalKeyVolcanic: 1,
        InvKeys.instantHatch: 2,
        InvKeys.powerupSpeed: 3,
        InvKeys.potentialSoul: 1,
        InvKeys.alchemyGlow: 1,
        InvKeys.bossSummon: 1,
        InvKeys.raidBeacon: 2,
        InvKeys.homePlanetSlots: 2,
        BossLootKeys.traitKeyForElement('fire'): 1,
        BossLootKeys.traitKeyForElement('water'): 1,
        BossLootKeys.traitKeyForElement('earth'): 1,
        BossLootKeys.lootBoxKeyForElement('fire'): 2,
      };
      for (final e in pack.entries) {
        await db.inventoryDao.addItemQty(e.key, e.value);
      }
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
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: Scaffold(
            backgroundColor: const Color(0xFF2D4A33),
            body: WildernessControls(onLeave: () {}, party: const []),
          ),
        ),
      ),
    );
    await settle();
    await tester.tap(find.byTooltip('Inventory'));
    await settle(12);
    await shoot('1_panel');

    final first = find.byKey(const ValueKey('field-item-0'));
    if (first.evaluate().isNotEmpty) {
      await tester.tap(first);
      await settle(10);
      await shoot('2_detail');
    }

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
