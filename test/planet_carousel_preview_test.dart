@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/mini_map_overlay.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The star map's planet carousel, every planet discovered, as a picture.
//
//   CAROUSEL_OUT=/tmp/carousel.png flutter test \
//     test/planet_carousel_preview_test.dart --tags preview
//
// CAROUSEL_SCROLL=<px> scrolls the strip, to see the cards past the first
// few.
void main() {
  final out = Platform.environment['CAROUSEL_OUT'];

  testWidgets('planet carousel preview', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(915 * 2, 412 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final world = CosmicWorld.generate(seed: 1);
    for (final p in world.planets) {
      p.discovered = true;
    }
    final game = CosmicGame(world_: world, onMeterChanged: () {});
    await tester.runAsync(game.onLoad);
    final key = GlobalKey();
    final overlayKey = GlobalKey<MiniMapOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: MiniMapOverlay(
            key: overlayKey,
            world: world,
            game: game,
            theme: FactionTheme.scorchForge(),
            markers: const [],
            onTeleport: (_) {},
            onNavigatePlanet: (_) {},
            onGoHome: () {},
            onClose: () {},
            onMarkersChanged: (_) {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final scroll = double.tryParse(
      Platform.environment['CAROUSEL_SCROLL'] ?? '',
    );
    if (scroll != null) {
      final list = find.byType(ListView).last;
      tester.widget<ListView>(list).controller!.jumpTo(scroll);
      await tester.pump(const Duration(milliseconds: 50));
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
