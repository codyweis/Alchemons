@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The inside of a rift, the real screen — its Alchemon, the encounter's
// controls over it — at the Fold's two landscape sizes, with real fonts.
//
//   RIFT_OUT=/tmp/rift flutter test \
//     test/rift_interior_preview_test.dart --tags preview
void main() {
  final outDir = Platform.environment['RIFT_OUT'];

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

  testWidgets('rift interior preview', (tester) async {
    if (outDir == null) return;
    Directory(outDir).createSync(recursive: true);

    late AlchemonsDatabase db;
    final catalog = CreatureCatalog();
    await tester.runAsync(() async {
      db = AlchemonsDatabase(NativeDatabase.memory());
      await catalog.load();
      await loadNatures();
    });
    final constellation = ConstellationEffectsService(db);

    for (final (w, h) in const [(860.0, 360.0), (900.0, 680.0)]) {
      for (final faction in const [RiftFaction.volcanic, RiftFaction.arcane]) {
        tester.view.physicalSize = Size(w * 2, h * 2);
        tester.view.devicePixelRatio = 2;
        final key = GlobalKey();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AlchemonsDatabase>.value(value: db),
              Provider<CreatureCatalog>.value(value: catalog),
              ChangeNotifierProvider<ConstellationEffectsService>.value(
                value: constellation,
              ),
              Provider<CatchService>(
                create: (_) => CatchService(db, constellation),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(),
              home: RepaintBoundary(
                key: key,
                child: RiftPortalScreen(faction: faction),
              ),
            ),
          ),
        );
        // Let the Alchemon spawn and its sprite sheet decode.
        for (var i = 0; i < 14; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 90)),
          );
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$outDir/interior_${w.toInt()}_${faction.name}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });
}
