@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/creature_background_pref.dart';
import 'package:alchemons/widgets/creature_detail/creature_display_view.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The backdrop viewer on a phone, with real fonts: on space, on white, on
// the light theme, and with the Fire Horn mid-essence.
//
//   DISPLAY_OUT=/tmp/display flutter test \
//     test/creature_display_view_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['DISPLAY_OUT'];

  Future<void> loadFont(String family, List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader(family)..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      return;
    }
  }

  setUpAll(() async {
    await loadFont('monospace', [
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    ]);
    await loadFont('Roboto', ['/System/Library/Fonts/Supplemental/Arial.ttf']);
  });

  final horn = Creature(
    id: 'HOR01',
    name: 'Firehorn',
    types: const ['Fire'],
    rarity: 'Rare',
    description: 'preview',
    image: 'creatures/rare/HOR01_firehorn.png',
    mutationFamily: 'Horn',
    spriteData: SpriteData(
      frameWidth: 1200,
      frameHeight: 1200,
      totalFrames: 4,
      frameDurationMs: 90,
      rows: 1,
      spriteSheetPath: 'creatures/rare/HOR01_firehorn_spritesheet.png',
    ),
  );

  const instance = CreatureInstance(
    instanceId: 'i1',
    baseId: 'HOR01',
    level: 12,
    xp: 0,
    locked: false,
    isPrismaticSkin: false,
    source: 'preview',
    staminaMax: 3,
    staminaBars: 3,
    staminaLastUtcMs: 0,
    createdAtUtcMs: 0,
    statSpeed: 2,
    statIntelligence: 2,
    statStrength: 2,
    statBeauty: 2,
    statSpeedPotential: 40,
    statIntelligencePotential: 40,
    statStrengthPotential: 40,
    statBeautyPotential: 40,
    statSpeedEnhancement: 0,
    statIntelligenceEnhancement: 0,
    statStrengthEnhancement: 0,
    statBeautyEnhancement: 0,
    generationDepth: 0,
    isPure: false,
    isFavorite: false,
    nickname: 'Cinder',
  );

  testWidgets('display view preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

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

    Future<void> mount({
      required FactionTheme theme,
      CreatureBgOption bg = defaultCreatureBg,
      bool withInstance = true,
    }) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<FactionTheme>.value(value: theme),
            Provider<AlchemonsDatabase>.value(value: db),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.isDark ? ThemeData.dark() : ThemeData.light(),
            home: RepaintBoundary(
              key: key,
              child: CreatureDisplayView(
                creature: horn,
                instance: withInstance ? instance : null,
                initialBg: bg,
              ),
            ),
          ),
        ),
      );
      // The sprite sheet loads off the test clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    final dark = FactionTheme.scorchForge();
    await mount(theme: dark);
    await shoot('1_space');
    await tester.tap(find.text('EVERY FIREHORN'));
    await tester.pump();
    await shoot('2_scope_species');

    await mount(theme: dark, bg: creatureBgById('white'));
    await shoot('3_white');

    await mount(theme: dark, withInstance: false, bg: creatureBgById('ocean'));
    await shoot('4_species_only');

    await mount(theme: dark);
    await tester.tap(find.byType(ElementalEssence));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await shoot('5_essence');
    await tester.pump(const Duration(seconds: 3));
  });
}
