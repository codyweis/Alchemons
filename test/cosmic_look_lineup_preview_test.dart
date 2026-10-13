@Tags(['preview'])
library;

// THE LOOK LINEUP. Every point of interest and landmark in open space at the
// closest zoom, and a few of the rebuilt pieces (rift, Nexus, home black
// hole) as the yardstick — for judging what has fallen behind the rest of
// the art.
//
//   LINEUP_OUT=/tmp/lineup flutter test \
//     test/cosmic_look_lineup_preview_test.dart --tags preview

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Space is played in portrait; LINEUP_LANDSCAPE=1 turns the phone.
final bool _landscape = Platform.environment['LINEUP_LANDSCAPE'] != null;
final double _w = _landscape ? 915.0 : 412.0;
final double _h = _landscape ? 412.0 : 915.0;
const double _dpr = 2.0;
final String? _only = Platform.environment['LINEUP_ONLY'];

void main() {
  final out = Platform.environment['LINEUP_OUT'];

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
    final home = Platform.environment['HOME'];
    const ph = 'hosted/pub.dev/phosphoricons_flutter-1.0.0/lib/fonts';
    await loadFont(
      'packages/phosphoricons_flutter/PhosphorBold',
      '$home/.pub-cache/$ph/Phosphor-Bold.ttf',
    );
  });

  testWidgets('cosmic look lineup', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = Size(_w * _dpr, _h * _dpr);
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);

    late CosmicGame game;
    await tester.runAsync(() async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(_w, _h));
      // mid → far → close
      game.cycleZoomLevel();
      game.cycleZoomLevel();
      for (var i = 0; i < 20; i++) {
        game.update(1 / 30);
      }
    });

    void settle(double s) {
      for (var i = 0; i < (s * 30).round(); i++) {
        game.update(1 / 30);
        game.shipHealth = CosmicBalance.shipMaxHealth;
      }
    }

    void flyTo(Offset p, {Offset off = const Offset(-150, 30)}) {
      game.teleportTo(p + off);
      game.enemies.clear();
      game.activeBoss = null;
    }

    ui.Image frame() {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, _w * _dpr, _h * _dpr),
        Paint()..color = const Color(0xFF020010),
      );
      c.scale(_dpr);
      game.render(c);
      final pic = rec.endRecording();
      final img = pic.toImageSync((_w * _dpr).round(), (_h * _dpr).round());
      pic.dispose();
      return img;
    }

    Future<void> save(ui.Image img, String name) async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    Future<void> shoot(String name) async {
      if (_only != null && !name.contains(_only!)) return;
      await tester.runAsync(() async {
        final img = frame();
        await save(img, name);
        img.dispose();
      });
    }

    final world = game.world_;

    // ── points of interest, one of each ──
    final seen = <POIType>{};
    for (final poi in game.spacePOIs) {
      if (!seen.add(poi.type)) continue;
      poi.discovered = true;
      flyTo(poi.position);
      settle(0.8);
      flyTo(poi.position);
      game.update(1 / 30);
      await shoot('poi_${poi.type.name}');
    }

    // ── landmarks ──
    flyTo(world.bloodRing.position, off: const Offset(0, 470));
    settle(1);
    await shoot('landmark_blood_ring');
    flyTo(world.elementalNexus.position, off: const Offset(0, 520));
    settle(1);
    await shoot('ref_elemental_nexus');
    flyTo(world.prismaticField.position, off: const Offset(-60, 40));
    settle(1);
    await shoot('landmark_prismatic');
    flyTo(world.riftPortals.first.position);
    settle(1);
    await shoot('ref_rift_portal');
    flyTo(game.galaxyWhirls.first.position, off: const Offset(0, 300));
    settle(0.5);
    await shoot('landmark_galaxy_whirl');
    flyTo(game.elementalCacheField.caches.first.position);
    settle(1);
    await shoot('landmark_elemental_cache');
    if (game.bossLairs.isNotEmpty) {
      flyTo(game.bossLairs.first.position, off: const Offset(0, -340));
      settle(0.3);
      await shoot('landmark_boss_lair');
    }

    // ── yardstick: the home black hole ──
    flyTo(
      Offset(world.worldSize.width * 0.31, world.worldSize.height * 0.69),
      off: Offset.zero,
    );
    game.restoreHomePlanet(
      HomePlanet(
        position: game.ship.pos + const Offset(230, 10),
        activeColor: 'Water',
        sizeTierLevel: 3,
        activeSizeTier: 3,
      ),
    );
    game.activeCustomizations = {'black_hole'};
    settle(0.5);
    game.homePlanet!.position = game.ship.pos + const Offset(230, 10);
    game.update(1 / 60);
    await shoot('ref_home_black_hole');
  });
}
