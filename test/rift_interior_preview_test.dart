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
import 'package:alchemons/widgets/app_icons.dart';
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

  // The Alchemon pouring out of the disk into the core, and the rift going
  // black as it is left, then the black it is left through opening.
  testWidgets('rift pour preview', (tester) async {
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
    tester.view.physicalSize = const Size(860, 360) * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
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
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            navigatorKey: nav,
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            home: const ColoredBox(color: Color(0xFF26313F)),
          ),
        ),
      ),
    );
    final exit = RiftExitSheet();
    nav.currentState!.push(
      PageRouteBuilder<bool>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => RiftPortalScreen(
          faction: RiftFaction.volcanic,
          species: catalog.getCreatureById('HOR01'),
          exit: exit,
        ),
      ),
    );

    var shot = 0;
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$outDir/pour_${(shot++).toString().padLeft(2, '0')}_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    // Real time for the sprite to decode and be read; the pour runs on the
    // fake clock.
    Future<void> step(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 1000 ~/ 30));
      }
    }

    for (var k = 0; k < 14; k++) {
      await step(8);
      await shoot('t${((k + 1) * 8 / 30).toStringAsFixed(1)}');
    }

    // Leaving: the way out asks, then the rift draws in and goes black.
    await tester.tap(find.byIcon(AppIcons.close_rounded));
    await step(12);
    await tester.tap(find.text('LEAVE'));
    for (final n in const [5, 5, 5, 6]) {
      await step(n);
      await shoot('leave');
    }
    expect(exit.covering, isTrue);
    exit.open(at: const Offset(430, 180));
    for (final n in const [8, 8, 8]) {
      await step(n);
      await shoot('back');
    }
    await step(20);
    expect(exit.covering, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
    await tester.runAsync(db.close);
  });
}
