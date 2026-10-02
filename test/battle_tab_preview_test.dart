@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The Battle tab at phone width with its live stage running: the creature
/// fighting in the practice arena, then a stat, the auto attack and the
/// special picked.
///
///   BATTLE_TAB_OUT=/tmp/tab flutter test \
///     test/battle_tab_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['BATTLE_TAB_OUT'];

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

  for (final (family, element, s, i, b, sp, dark) in [
    ('Pip', 'Fire', 4.4, 3.85, 1.6, 2.1, true),
    ('Horn', 'Earth', 5.1, 2.2, 2.0, 3.0, true),
    ('Mystic', 'Water', 3.2, 4.8, 5.6, 2.4, false),
  ]) {
    testWidgets('battle tab $family', (tester) async {
      if (out == null) return;
      Directory(out).createSync(recursive: true);
      tester.view.physicalSize = const Size(390 * 2, 1500 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final database = db.AlchemonsDatabase(NativeDatabase.memory());
      final key = GlobalKey();
      final theme = factionThemeFor(
        FactionId.volcanic,
        brightness: dark ? Brightness.dark : Brightness.light,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<db.AlchemonsDatabase>.value(value: database),
            Provider<FactionTheme>.value(value: theme),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: ConstellationEffectsService(database),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: Scaffold(
              backgroundColor: dark
                  ? const Color(0xFF0E1117)
                  : const Color(0xFFFFFBF4),
              body: ImprovedBattleScrollArea(
                theme: theme,
                creature: Creature(
                  id: 'T',
                  name: '$element $family',
                  types: [element],
                  rarity: 'common',
                  description: 't',
                  image: 'creatures/common/preview.png',
                  mutationFamily: family,
                ),
                instance: db.CreatureInstance(
                  instanceId: 'i1',
                  baseId: 'TST01',
                  level: 9,
                  xp: 0,
                  locked: false,
                  isPrismaticSkin: false,
                  source: 'test',
                  staminaMax: 3,
                  staminaBars: 3,
                  staminaLastUtcMs: 0,
                  createdAtUtcMs: 0,
                  statSpeed: sp,
                  statIntelligence: i,
                  statStrength: s,
                  statBeauty: b,
                  statSpeedPotential: 40,
                  statIntelligencePotential: 72,
                  statStrengthPotential: 88,
                  statBeautyPotential: 30,
                  statSpeedEnhancement: 0,
                  statIntelligenceEnhancement: 0,
                  statStrengthEnhancement: 0,
                  statBeautyEnhancement: 0,
                  generationDepth: 0,
                  isPure: true,
                  isFavorite: false,
                ),
              ),
            ),
          ),
        ),
      );

      Future<void> settle(int frames) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        for (var k = 0; k < frames; k++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
      }

      Future<void> shoot(String name) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await settle(90);
      expect(tester.takeException(), isNull);
      await shoot('${family}_1_stat');
      await tester.tap(find.text('AUTO ATTACK'));
      await settle(20);
      await shoot('${family}_2_auto');
      await tester.tap(find.text('SPECIAL').first);
      await settle(60);
      await shoot('${family}_3_special');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => database.close());
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
