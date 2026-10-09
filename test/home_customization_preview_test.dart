@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The home planet wearing each visual customization on its own, rendered
// through the game's real home painter (via the encounter backdrop), so the
// sheet is what the player sees.
//
//   HOME_OUT=/tmp/home.png HOME_T=4 flutter test \
//     test/home_customization_preview_test.dart --tags preview
//
// HOME_ONLY=id,id limits it to those customizations; HOME_COLOR picks the
// planet's color (an element name); HOME_CELL sets each picture's size.
void main() {
  final out = Platform.environment['HOME_OUT'];

  testWidgets('home customization previews', (tester) async {
    if (out == null) return;
    final only = Platform.environment['HOME_ONLY']?.split(',');
    final ids = [
      for (final r in kHomeRecipes)
        if (r.category == HomeRecipeCategory.visual &&
            (only == null || only.contains(r.id)))
          r.id,
    ];
    final t = double.tryParse(Platform.environment['HOME_T'] ?? '') ?? 4;
    final color = Platform.environment['HOME_COLOR'] ?? 'Water';
    // HOME_WORLD=1 draws the real game frame (camera on the ship, the
    // planet beside it) instead of the encounter backdrop, which fades out
    // everything past about 1.8 radii.
    final world = Platform.environment['HOME_WORLD'] == '1';
    final shift = world ? const Offset(60, 30) : Offset.zero;
    // HOME_OPTS="black_hole.density=Maximum,black_hole.color=Solar" sets
    // the customizations' options.
    final options = <String, String>{
      for (final kv in (Platform.environment['HOME_OPTS'] ?? '').split(','))
        if (kv.contains('=')) kv.split('=')[0]: kv.split('=')[1],
    };
    final images = <(String, ui.Image)>[];
    for (final id in ids) {
      final game = CosmicGame(
        world_: CosmicWorld.generate(seed: 1),
        onMeterChanged: () {},
      );
      await tester.runAsync(game.onLoad);
      game.onGameResize(Vector2(915, 412));
      if (world) {
        // The widest zoom, the player's view on the way anywhere.
        game.cycleZoomLevel();
        game.update(t);
      }
      game.restoreHomePlanet(
        HomePlanet(
          position: game.ship.pos + shift,
          activeColor: color,
          sizeTierLevel: 3,
          activeSizeTier: 3,
        ),
      );
      game.activeCustomizations = {id};
      game.customizationOptions = {...options};
      if (world) {
        game.update(1 / 60);
      } else {
        game.update(t);
      }
      if (world) {
        final rec = ui.PictureRecorder();
        game.render(Canvas(rec));
        images.add((id, rec.endRecording().toImageSync(915, 412)));
      } else {
        images.add((id, game.captureEncounterBackdrop().image!));
      }
    }
    await tester.runAsync(() async {
      final cell =
          double.tryParse(Platform.environment['HOME_CELL'] ?? '') ?? 380.0;
      final cols = min(5, images.length);
      final rows = (images.length / cols).ceil();
      final cellH = world ? cell * 0.45 : cell;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, cell * cols, cellH * rows),
        Paint()..color = const Color(0xFF020010),
      );
      final rng = Random(3);
      for (var i = 0; i < 1200; i++) {
        c.drawCircle(
          Offset(
            rng.nextDouble() * cell * cols,
            rng.nextDouble() * cellH * rows,
          ),
          0.6 + rng.nextDouble(),
          Paint()
            ..color = Colors.white.withValues(
              alpha: 0.15 + rng.nextDouble() * 0.4,
            ),
        );
      }
      for (var i = 0; i < images.length; i++) {
        final (_, img) = images[i];
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          world
              ? Rect.fromLTWH(
                  (i % cols) * cell,
                  (i ~/ cols) * cell * 0.45,
                  cell,
                  cell * 0.45,
                )
              : Rect.fromLTWH(
                  (i % cols) * cell,
                  (i ~/ cols) * cell,
                  cell,
                  cell,
                ),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final pic = rec.endRecording();
      final img = pic.toImageSync(
        (cell * cols).round(),
        (cellH * rows).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
