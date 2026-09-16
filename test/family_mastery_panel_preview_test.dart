@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic_survival/components/family_mastery_panel.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Renders the Family Mastery panel at phone size with real fonts, so the
/// layout can be judged as a picture rather than from widget finders.
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
    ]) {
      await loadFont('packages/phosphoricons_flutter/$family', [
        '$home/hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts/$file',
      ]);
    }
  });

  testWidgets('family mastery panel preview', (tester) async {
    if (outDir == null) return;
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
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
      for (final id in [
        'mane.assault.honed_pair',
        'mane.assault.crosscut',
        'mane.control.sweeping_claws',
      ]) {
        await mastery.purchaseNode(family: CreatureFamily.mane, nodeId: id);
      }
      for (final path in ['kin.resonance', 'kin.assault']) {
        final nodes = FamilyMasteryCatalog.pathFor(
          CreatureFamily.kin,
          path,
        )!.nodes;
        for (final node in path == 'kin.assault' ? nodes.take(2) : nodes) {
          await mastery.purchaseNode(
            family: CreatureFamily.kin,
            nodeId: node.id,
          );
        }
      }
    });

    final boundary = GlobalKey();
    final compact = ValueNotifier(false);
    await tester.pumpWidget(
      ChangeNotifierProvider<FamilyMasteryService>.value(
        value: mastery,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: SafeArea(
                child: ValueListenableBuilder<bool>(
                  valueListenable: compact,
                  builder: (context, isCompact, _) => Column(
                    children: [
                      // Stand-in for Base Command's header and tab bar, or
                      // its balance bar once scrolled.
                      Container(
                        height: isCompact ? 44 : 118,
                        color: const Color(0xFF0E1117),
                      ),
                      Expanded(
                        child: FamilyMasteryPanel(
                          silverBalance: 12000,
                          goldBalance: 4,
                          onCurrencyChanged: () async {},
                          compact: isCompact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element, onError: (_, _) {});
      }
    });
    await tester.pump(const Duration(seconds: 2));

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await capture('mastery_mane');

    compact.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(
      find.byKey(const ValueKey('family-skill-tree')),
      const Offset(0, -160),
    );
    await tester.pump(const Duration(seconds: 1));
    await capture('mastery_mane_compact');
    compact.value = false;
    await tester.drag(
      find.byKey(const ValueKey('family-skill-tree')),
      const Offset(0, 400),
    );
    await tester.pump(const Duration(seconds: 1));

    final capstone = find.byKey(
      const ValueKey('mastery-node-mane.assault.blade_dance'),
    );
    if (capstone.evaluate().isNotEmpty) {
      await tester.ensureVisible(capstone);
      await tester.tap(capstone, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 2));
      await capture('mastery_mane_capstone');
    }

    // Arm the upgrade button (first tap) on the Tempest Claw path.
    await tester.tap(
      find.byKey(const ValueKey('mastery-node-mane.control.rending_wake')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('unlock-mane.control.rending_wake')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await capture('mastery_mane_armed');

    await tester.tap(find.byKey(const ValueKey('mastery-family-kin')));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element, onError: (_, _) {});
      }
    });
    await tester.pump(const Duration(seconds: 1));
    await capture('mastery_kin');

    await tester.runAsync(() async {
      mastery.dispose();
      await db.close();
    });
  });
}
