@Tags(['preview'])
library;

// A raid-overrun planet in open space: the crimson storm of grains that turns
// round it (paintRaidStorm), at a few moments, on two planets of different
// size.
//
//   RAID_STORM_OUT=/tmp/raid_storm flutter test \
//     test/cosmic_raid_storm_preview_test.dart --tags preview

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _w = 412, _h = 915, _dpr = 2;

void main() {
  final out = Platform.environment['RAID_STORM_OUT'];

  testWidgets('raid storm round a planet', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    late CosmicGame game;
    await tester.runAsync(() async {
      game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await game.onLoad();
      game.onGameResize(Vector2(_w, _h));
    });

    final planets = [...game.planetComps.map((c) => c.planet)]
      ..sort((a, b) => a.radius.compareTo(b.radius));
    for (final planet in [planets.first, planets.last]) {
      planet.discovered = true;
      game.raidElement = planet.element;
      game.teleportTo(planet.position + Offset(0, planet.radius * 2.4));
      game.enemies.clear();
      game.activeBoss = null;
      for (final t in const [0.5, 3.0]) {
        var s = 0.0;
        while (s < t) {
          game.update(1 / 30);
          s += 1 / 30;
        }
        await tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec)
            ..drawRect(
              const Rect.fromLTWH(0, 0, _w * _dpr, _h * _dpr),
              Paint()..color = const Color(0xFF020010),
            )
            ..scale(_dpr);
          game.render(c);
          final img = rec.endRecording().toImageSync(
            (_w * _dpr).round(),
            (_h * _dpr).round(),
          );
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/raid_storm_${planet.element}_t$t.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
      }
    }
  });
}
