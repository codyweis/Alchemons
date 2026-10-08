@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/screens/cosmic/widgets/mini_map_circle.dart';
import 'package:alchemons/screens/cosmic/widgets/mini_map_overlay.dart';
import 'package:alchemons/screens/cosmic/widgets/raid_badge.dart';
import 'package:alchemons/screens/cosmic/widgets/top_hud.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The star chart and the space HUD (header, radar, raid badge) on a phone,
// mid-game: a dozen planets found, a trail of explored space, a home, the
// stations and landmarks discovered, a raid running.
//
//   CHART_HUD_OUT=/tmp/chart flutter test \
//     test/cosmic_chart_hud_preview_test.dart --tags preview
//
// Writes chart.png, chart_zoom.png, chart_collapsed.png and hud.png.
void main() {
  final out = Platform.environment['CHART_HUD_OUT'];
  const w = 412.0, h = 915.0;

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    if (out == null) return;
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/'
          'phosphoricons_flutter-1.0.0/lib/fonts/Phosphor-Bold.ttf',
    );
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
  });

  Future<CosmicGame> midGame(WidgetTester tester) async {
    final world = CosmicWorld.generate(seed: 1);
    final game = CosmicGame(world_: world, onMeterChanged: () {});
    await tester.runAsync(game.onLoad);
    game.onGameResize(Vector2(w, h));

    // A dozen planets found, and the space flown between them explored.
    final found = world.planets.take(12).toList();
    for (final p in found) {
      p.discovered = true;
    }
    final gw = (world.worldSize.width / CosmicGame.fogCellSize).ceil();
    final gh = (world.worldSize.height / CosmicGame.fogCellSize).ceil();
    void reveal(Offset c, double r) {
      final cr = (r / CosmicGame.fogCellSize).ceil();
      final cx = (c.dx / CosmicGame.fogCellSize).floor();
      final cy = (c.dy / CosmicGame.fogCellSize).floor();
      for (var dy = -cr; dy <= cr; dy++) {
        for (var dx = -cr; dx <= cr; dx++) {
          if (dx * dx + dy * dy > cr * cr) continue;
          final gx = cx + dx, gy = cy + dy;
          if (gx < 0 || gy < 0 || gx >= gw || gy >= gh) continue;
          game.revealedCells.add(gy * gw + gx);
        }
      }
    }

    var prev = found.first.position;
    for (final p in found) {
      final steps = ((p.position - prev).distance / 300).ceil().clamp(1, 400);
      for (var i = 0; i <= steps; i++) {
        reveal(Offset.lerp(prev, p.position, i / steps)!, 900);
      }
      reveal(p.position, 1600);
      prev = p.position;
    }
    for (final poi in game.spacePOIs) {
      final cell =
          (poi.position.dy / CosmicGame.fogCellSize).floor() * gw +
          (poi.position.dx / CosmicGame.fogCellSize).floor();
      if (game.revealedCells.contains(cell)) poi.discovered = true;
    }
    for (final a in world.contestArenas) {
      a.discovered = true;
    }
    world.elementalNexus.discovered = true;
    game.prismaticField.discovered = true;
    for (final c in game.elementalCacheField.caches.take(5)) {
      c.discovered = true;
    }
    game.ship.pos = found[2].position + const Offset(900, -700);
    game.homePlanet = HomePlanet(
      position: game.ship.pos + const Offset(-3600, 2600),
      sizeTierLevel: 2,
      activeSizeTier: 2,
      activeColor: 'Water',
    );
    game.ship.pos = found[2].position + const Offset(900, -700);

    game.meter
      ..add('Fire', 34)
      ..add('Water', 22)
      ..add('Lightning', 11);
    game.shipWallet.shards = 138;
    game.shipWallet.shardCapacity = 400;
    for (var i = 0; i < 60; i++) {
      game.update(1 / 30);
    }
    return game;
  }

  Future<void> shoot(GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Widget chart(CosmicGame game, GlobalKey<MiniMapOverlayState> overlayKey) =>
      MiniMapOverlay(
        key: overlayKey,
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
      );

  testWidgets('star chart', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final game = await midGame(tester);
    final key = GlobalKey();
    final overlayKey = GlobalKey<MiniMapOverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: key, child: chart(game, overlayKey)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() => shoot(key, 'chart'));

    // Zoomed in on the ship, the way a player reads their neighbourhood.
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final ctrl = viewer.transformationController!;
    final box = tester.renderObject<RenderBox>(find.byType(InteractiveViewer));
    final world = game.world_.worldSize;
    final s = (box.size.width / world.width)
        .clamp(box.size.height / world.height, double.infinity)
        .toDouble();
    const zoom = 4.0;
    final ship = game.ship.pos * s * zoom;
    ctrl.value = Matrix4.identity()
      ..translateByDouble(
        box.size.width / 2 - ship.dx,
        box.size.height / 2 - ship.dy,
        0,
        1,
      )
      ..scaleByDouble(zoom, zoom, 1, 1);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() => shoot(key, 'chart_zoom'));
  });

  testWidgets('space hud', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final game = await midGame(tester);
    // The space behind the HUD, as the game draws it.
    late ui.Image backdrop;
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        const Rect.fromLTWH(0, 0, w * 2, h * 2),
        Paint()..color = const Color(0xFF020010),
      );
      c.scale(2);
      game.render(c);
      final pic = rec.endRecording();
      backdrop = await pic.toImage((w * 2).round(), (h * 2).round());
    });

    final pulse = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
    addTearDown(pulse.dispose);
    final now = DateTime.utc(2026, 10, 3, 12);
    final raid = RaidState(
      element: 'Lava',
      startUtc: now.subtract(const Duration(hours: 2, minutes: 13)),
      level: 2,
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(child: RawImage(image: backdrop, scale: 2)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: TopHud(
                      theme: FactionTheme.scorchForge(),
                      meter: game.meter,
                      meterPulse: pulse,
                      discoveryPct: game.discoveryPct,
                      planetsFound: game.world_.discoveredCount,
                      planetsTotal: game.world_.totalCount,
                      wallet: game.shipWallet,
                      onSettings: () {},
                      onMiniMap: () {},
                      onMeterTap: () {},
                      dustCollected: 23,
                      dustTotal: 50,
                      onZoomCycle: () {},
                    ),
                  ),
                ),
                Positioned(
                  top: 120,
                  left: 12,
                  child: CosmicMiniMapCircle(
                    world: game.world_,
                    game: game,
                    onTap: () {},
                    onLongPress: () {},
                  ),
                ),
                Positioned(
                  top: 120 + 84 + 6,
                  left: 12,
                  child: RaidBadge(raid: raid, now: now),
                ),
                Positioned(
                  top: 330,
                  left: 12,
                  child: RaidBadge(
                    raid: RaidState(
                      element: 'Ice',
                      startUtc: now.subtract(const Duration(hours: 5)),
                      duration: const Duration(hours: 5, minutes: 40),
                      level: 3,
                    ),
                    now: now,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => shoot(key, 'hud'));

    // The meter full, and a recipe's targets on it.
    game.meter
      ..reset()
      ..add('Fire', 52)
      ..add('Water', 30)
      ..add('Lightning', 18);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
