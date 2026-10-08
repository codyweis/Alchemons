@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/chart_zoom.dart';
import 'package:alchemons/screens/cosmic/widgets/mini_map_overlay.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// The way from space into the star chart, frame by frame: space shrinking
// round the ship into its patch on the chart as the chart settles out round
// it. Space is a real frame of the game; home leads the carousel.
//
//   CHARTZOOM_OUT=/tmp/chartzoom flutter test \
//     test/star_chart_zoom_preview_test.dart --tags preview
//
// Writes zoom.png (a strip) and zoom_<n>.png.
void main() {
  final out = Platform.environment['CHARTZOOM_OUT'];
  const w = 412.0, h = 915.0;

  testWidgets('space into the star chart', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await tester.runAsync(() => game.onLoad());
    game.onGameResize(Vector2(w, h));
    for (final p in game.world_.planets) {
      p.discovered = true;
    }
    final found = game.world_.planets;
    game.ship.pos = found[2].position + const Offset(900, -700);
    game.homePlanet = HomePlanet(
      position: game.ship.pos + const Offset(-3600, 2600),
      sizeTierLevel: 2,
      activeSizeTier: 2,
      activeColor: 'Water',
    );
    for (var i = 0; i < 60; i++) {
      game.update(1 / 30);
    }
    // Space, as the chart would picture it.
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(2);
    c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF020010),
    );
    game.render(c);
    final space = rec.endRecording().toImageSync((w * 2).round(), (h * 2).round());

    final ctrl = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 750),
    );
    final fade = CurvedAnimation(
      parent: ctrl,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOut),
    ).drive(Tween(begin: 0.004, end: 1.0));
    final zoom = ChartZoom(
      image: space,
      origin: Offset.zero,
      size: const Size(w, h),
      ship: game.worldToView(game.ship.pos),
      spacePxPerUnit: game.cameraZoom,
    );
    final chartKey = GlobalKey<MiniMapOverlayState>();
    final shotKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: shotKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: space, fit: BoxFit.fill),
              FadeTransition(
                opacity: fade,
                child: MiniMapOverlay(
                  key: chartKey,
                  reveal: ctrl,
                  world: game.world_,
                  game: game,
                  theme: FactionTheme.scorchForge(),
                  markers: const [],
                  dungeonStarsFor: (p) => p.element == 'Fire' ? 3 : 1,
                  dungeonStarTotal: 19,
                  dungeonStarMax: 51,
                  onTeleport: (_) {},
                  onNavigatePlanet: (_) {},
                  onGoHome: () {},
                  onClose: () {},
                  onMarkersChanged: (_) {},
                ),
              ),
              IgnorePointer(
                child: CustomPaint(painter: ChartZoomPainter(zoom, ctrl)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    zoom.onChart = chartKey.currentState!.shipOnChart();
    expect(zoom.onChart, isNotNull);

    const shots = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0];
    final images = <ui.Image>[];
    for (final t in shots) {
      ctrl.value = t;
      await tester.pump();
      final b = shotKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final img = await tester.runAsync(() => b.toImage(pixelRatio: 1));
      images.add(img!);
    }
    const gap = 6.0;
    final strip = ui.PictureRecorder();
    final sc = Canvas(strip);
    final sw = (w + gap) * shots.length + gap;
    sc.drawRect(Rect.fromLTWH(0, 0, sw, h + gap * 2), Paint()..color = Colors.black);
    for (var i = 0; i < images.length; i++) {
      sc.drawImage(images[i], Offset(gap + i * (w + gap), gap), Paint());
      await tester.runAsync(() async {
        final bytes = await images[i].toByteData(
          format: ui.ImageByteFormat.png,
        );
        File('$out/zoom_$i.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    final all = strip.endRecording().toImageSync(sw.round(), (h + gap * 2).round());
    await tester.runAsync(() async {
      final bytes = await all.toByteData(format: ui.ImageByteFormat.png);
      File('$out/zoom.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    ctrl.dispose();
  });
}
