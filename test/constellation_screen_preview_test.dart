@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_screen.dart';
import 'package:alchemons/screens/upgrade_tree/constellation_skill_dialog.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/services/constellation_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The whole constellation screen — chart and chrome — as a mid-game player
// opens it on the Fold's cover screen.
//
//   CONST_OUT=/tmp/constellation flutter test \
//     test/constellation_screen_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['CONST_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
    ]) {
      await loadFont(
        'packages/phosphoricons_flutter/$family',
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      );
    }
  });

  testWidgets('constellation screen preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    late AlchemonsDatabase db;
    late ConstellationService service;
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await db.settingsDao.setConstellationTutorialSeen();
      await db.constellationDao.addPoints(
        amount: 45,
        transactionType: 'preview',
      );
      for (final s in ConstellationCatalog.allSkills) {
        if (s.tier <= 3) await db.constellationDao.unlockSkill(s.id, 0);
      }
      service = ConstellationService(db);
    });

    for (final tree in const ['breeder', 'combat', 'sheet']) {
      tester.view.physicalSize = const Size(1248, 1972);
      tester.view.devicePixelRatio = 1248 / 412;
      final key = GlobalKey();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(
              value: factionThemeFor(null, brightness: Brightness.dark),
            ),
            ChangeNotifierProvider<FactionService>(
              create: (_) => FactionService(db),
            ),
            ChangeNotifierProvider<ThemeNotifier>(
              create: (_) => ThemeNotifier(db),
            ),
            ChangeNotifierProvider<ConstellationService>.value(value: service),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            // Round the navigator, so sheets and dialogs are captured too.
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child),
            home: const ConstellationScreen(),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
      if (tree == 'sheet') {
        await tester.tap(find.byIcon(AppIcons.grid_view_rounded));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
      }
      if (tree == 'combat') {
        await tester.tap(find.text('COMBAT'));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1248 / 412 / 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/screen_$tree.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    // The skill dialog in each of its states.
    final breeder = ConstellationCatalog.forTree(ConstellationTree.breeder);
    final cases = [
      ('owned', breeder.firstWhere((s) => s.tier == 2), SkillDialogMode.owned),
      (
        'available',
        breeder.firstWhere((s) => s.tier == 4),
        SkillDialogMode.available,
      ),
      (
        'locked',
        breeder.firstWhere((s) => s.tier == 6),
        SkillDialogMode.locked,
      ),
    ];
    for (final (name, skill, mode) in cases) {
      final key = GlobalKey();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF05070A),
              child: ConstellationSkillDialog(
                skill: skill,
                mode: mode,
                pointsAvailable: 45,
                prerequisiteStates: {
                  for (final id in skill.prerequisites) id: false,
                },
                onUnlock: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1248 / 412 / 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/dialog_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });
}
