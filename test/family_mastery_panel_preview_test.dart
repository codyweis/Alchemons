@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/timed_boost_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders Base Command's Mastery tab with real fonts at a phone and at both
/// faces of a Fold, so the layout can be judged as a picture rather than
/// from widget finders.
///
///   MASTERY_OUT=/tmp flutter test \
///     test/family_mastery_panel_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['MASTERY_OUT'];

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
      '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    ]);
    await loadFont('Roboto', [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ]);
    final home =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    for (final (family, file) in const [
      ('PhosphorBold', 'Phosphor-Bold.ttf'),
      ('PhosphorFill', 'Phosphor-Fill.ttf'),
      ('PhosphorRegular', 'Phosphor.ttf'),
    ]) {
      await loadFont('packages/phosphoricons_flutter/$family', [
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      ]);
    }
  });

  for (final (name, size) in const [
    ('phone', Size(412, 915)),
    ('fold_cover', Size(357, 850)),
    ('fold_inner', Size(716, 800)),
  ]) {
    testWidgets('mastery tab preview ($name)', (tester) async {
      if (outDir == null) return;
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      late AlchemonsDatabase db;
      late FamilyMasteryService mastery;
      await tester.runAsync(() async {
        db = AlchemonsDatabase(NativeDatabase.memory());
        await db.currencyDao.addSilver(100000);
        await db.currencyDao.addGold(100);
        mastery = FamilyMasteryService(db);
        await mastery.load();
        // Each family's mastery: the buys below, and a little over, so some
        // prices read as affordable and some don't.
        await mastery.addPoints(const {
          CreatureFamily.mane: 210,
          CreatureFamily.kin: 700,
          CreatureFamily.mystic: 60,
        });
        for (final id in [
          'mane.assault.honed_pair',
          'mane.assault.crosscut',
          'mane.limitless.far_throw',
        ]) {
          await mastery.purchaseNode(family: CreatureFamily.mane, nodeId: id);
        }
        await mastery.selectPath(
          family: CreatureFamily.mane,
          pathId: 'mane.assault',
        );
        for (final (path, count) in const [
          ('kin.benediction', 4),
          ('kin.longline', 2),
        ]) {
          final nodes = FamilyMasteryCatalog.pathFor(
            CreatureFamily.kin,
            path,
          )!.nodes;
          for (final node in nodes.take(count)) {
            await mastery.purchaseNode(
              family: CreatureFamily.kin,
              nodeId: node.id,
            );
          }
        }
        await mastery.purchaseNode(
          family: CreatureFamily.mystic,
          nodeId: 'mystic.firmament.native_air',
        );
      });

      final boundary = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            ChangeNotifierProvider<FamilyMasteryService>.value(value: mastery),
            ChangeNotifierProvider(create: (_) => SurvivalUpgradeService(db)),
            ChangeNotifierProvider(
              create: (_) => ShopService(
                db,
                ConstellationEffectsService(db),
                FactionService(db),
                TimedBoostService(db.settingsDao),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: RepaintBoundary(
              key: boundary,
              child: const CosmicSurvivalBaseCommandScreen(hideAbilities: true),
            ),
          ),
        ),
      );

      Future<void> settle() async {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          for (final element in find.byType(Image).evaluate()) {
            final image = element.widget as Image;
            await precacheImage(image.image, element, onError: (_, _) {});
          }
        });
        await tester.pump(const Duration(seconds: 2));
      }

      Future<void> capture(String shot) async {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$outDir/mastery_${shot}_$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      await settle();
      await capture('mane');

      // Arm the upgrade (first tap) on the Limitless branch.
      await tester.tap(
        find.byKey(const ValueKey('mastery-node-mane.limitless.overdraw')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('unlock-mane.limitless.overdraw')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await capture('mane_armed');

      for (final family in const ['kin', 'let', 'mystic']) {
        await tester.tap(find.byKey(ValueKey('mastery-family-$family')));
        await settle();
        await capture(family);
      }
      expect(tester.takeException(), isNull);

      await tester.runAsync(() async {
        mastery.dispose();
        await db.close();
      });
    });
  }
}
