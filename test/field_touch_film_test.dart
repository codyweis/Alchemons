@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A finger on a field drawn in code, as a filmstrip: the drag (panning the
// camera with it, as a real drag does), then the release and what settles.
// One contact sheet per gesture, a frame every FILM_STEP seconds, cropped to
// the part of the screen the gesture is in.
//
//   FILM_OUT=/tmp/film FILM_SCENE=sky flutter test \
//     test/field_touch_film_test.dart --tags preview
//
// FILM_SCENE is valley, sky, swamp or volcano; FILM_GESTURES picks gestures by name
// (comma separated) from the scene's list below; FILM_WEATHER=dry (or rain,
// snow, storm) films it in that weather.
void main() {
  final out = Platform.environment['FILM_OUT'];

  testWidgets('field touch film', (tester) async {
    if (out == null) return;
    const screen = Size(751, 475);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);
    final step =
        double.tryParse(Platform.environment['FILM_STEP'] ?? '') ?? 0.1;

    final sceneName = Platform.environment['FILM_SCENE'] ?? 'sky';
    final SceneDefinition scene = switch (sceneName) {
      'valley' => valleySceneCorrected,
      'swamp' => swampScene,
      'volcano' => volcanoScene,
      _ => skyScene,
    };
    // name → (camera x, path of the finger as screen fractions over its
    // duration, seconds, pans the camera, crop as screen fractions, hour)
    final gestures =
        <String, (double, List<Offset>, double, bool, Rect, double)>{
          if (sceneName == 'valley') ...{
            'drag': (
              0,
              const [Offset(0.25, 0.87), Offset(0.6, 0.89)],
              0.6,
              true,
              const Rect.fromLTRB(0.1, 0.62, 0.9, 1),
              11,
            ),
            'tap': (
              0,
              const [Offset(0.45, 0.88)],
              0,
              false,
              const Rect.fromLTRB(0.2, 0.62, 0.7, 1),
              11,
            ),
          } else if (sceneName == 'volcano') ...{
            // Through the dry grass on the tutorial's basalt shelf.
            'drag': (
              0,
              const [Offset(0.4, 0.765), Offset(0.58, 0.77)],
              0.55,
              true,
              const Rect.fromLTRB(0.25, 0.5, 0.85, 0.95),
              11,
            ),
            'tap': (
              0,
              const [Offset(0.5, 0.765)],
              0,
              false,
              const Rect.fromLTRB(0.3, 0.5, 0.75, 0.95),
              11,
            ),
            // Across the crust in front of the shelves, and a tap on the
            // river at the right, at night.
            'lava': (
              0,
              const [Offset(0.15, 0.93), Offset(0.4, 0.94)],
              0.6,
              true,
              const Rect.fromLTRB(0, 0.68, 0.6, 1),
              11,
            ),
            'lavatap': (
              0,
              const [Offset(0.69, 0.9)],
              0,
              false,
              const Rect.fromLTRB(0.45, 0.66, 0.95, 1),
              23,
            ),
            // Over the cinder bank the partner stands on.
            'cinder': (
              0,
              const [Offset(0.76, 0.78), Offset(0.92, 0.78)],
              0.45,
              true,
              const Rect.fromLTRB(0.55, 0.55, 1, 0.95),
              17.6,
            ),
          } else if (sceneName == 'swamp') ...{
            // Through the sedge on the peat bank by the first great tree.
            'drag': (
              0,
              const [Offset(0.62, 0.745), Offset(0.84, 0.75)],
              0.55,
              true,
              const Rect.fromLTRB(0.45, 0.55, 1, 0.95),
              11,
            ),
            'tap': (
              0,
              const [Offset(0.74, 0.75)],
              0,
              false,
              const Rect.fromLTRB(0.5, 0.55, 0.98, 0.95),
              11,
            ),
            // Across the duckweed in front of the stone.
            'water': (
              0,
              const [Offset(0.24, 0.875), Offset(0.48, 0.885)],
              0.6,
              true,
              const Rect.fromLTRB(0.1, 0.7, 0.7, 1),
              11,
            ),
            'watertap': (
              0,
              const [Offset(0.4, 0.9)],
              0,
              false,
              const Rect.fromLTRB(0.15, 0.7, 0.65, 1),
              11,
            ),
            // Open water, at golden hour.
            'opentap': (
              0,
              const [Offset(0.12, 0.86)],
              0,
              false,
              const Rect.fromLTRB(0, 0.68, 0.4, 1),
              18.7,
            ),
            // Gone dry (FILM_WEATHER=dry): across the cracked floor, a tap
            // on it, and a tap in the last pool at the left.
            'mud': (
              0,
              const [Offset(0.3, 0.93), Offset(0.6, 0.94)],
              0.6,
              true,
              const Rect.fromLTRB(0.15, 0.62, 0.85, 1),
              17.6,
            ),
            'mudtap': (
              0,
              const [Offset(0.62, 0.93)],
              0,
              false,
              const Rect.fromLTRB(0.4, 0.66, 0.85, 1),
              17.6,
            ),
            'pooltap': (
              0,
              const [Offset(0.08, 0.875)],
              0,
              false,
              const Rect.fromLTRB(0, 0.66, 0.4, 1),
              11,
            ),
            // Through the reeds at the front.
            'reeds': (
              0,
              const [Offset(0.3, 0.93), Offset(0.42, 0.93)],
              0.4,
              true,
              const Rect.fromLTRB(0.15, 0.6, 0.6, 1),
              11,
            ),
          } else ...{
            'drag': (
              0,
              const [Offset(0.27, 0.655), Offset(0.52, 0.66)],
              0.55,
              true,
              const Rect.fromLTRB(0.15, 0.45, 0.75, 0.8),
              11,
            ),
            'tap': (
              0,
              const [Offset(0.4, 0.655)],
              0,
              false,
              const Rect.fromLTRB(0.2, 0.45, 0.6, 0.8),
              11,
            ),
            'falls': (
              950,
              const [Offset(0.42, 0.62), Offset(0.58, 0.68)],
              0.5,
              true,
              const Rect.fromLTRB(0.25, 0.4, 0.85, 1),
              18.7,
            ),
            'falltap': (
              950,
              const [Offset(0.495, 0.66)],
              0,
              false,
              const Rect.fromLTRB(0.25, 0.4, 0.85, 1),
              18.7,
            ),
            'sea': (
              0,
              const [Offset(0.62, 0.86), Offset(0.92, 0.84)],
              0.6,
              true,
              const Rect.fromLTRB(0.45, 0.6, 1, 1),
              11,
            ),
            'tower': (
              0,
              const [Offset(0.2, 0.42), Offset(0.32, 0.36)],
              0.5,
              true,
              const Rect.fromLTRB(0.05, 0.15, 0.5, 0.65),
              11,
            ),
            'cloudtap': (
              0,
              const [Offset(0.75, 0.84)],
              0,
              false,
              const Rect.fromLTRB(0.5, 0.6, 1, 1),
              17.6,
            ),
          },
        };
    final only = Platform.environment['FILM_GESTURES']?.split(',');

    for (final MapEntry(key: name, value: g) in gestures.entries) {
      if (only != null && !only.contains(name)) continue;
      final (cam, path, duration, pans, authoredCrop, hour) = g;
      final cropEnv = Platform.environment['FILM_CROP']
          ?.split(',')
          .map(double.parse)
          .toList();
      final crop = cropEnv == null
          ? authoredCrop
          : Rect.fromLTRB(cropEnv[0], cropEnv[1], cropEnv[2], cropEnv[3]);
      final weather = WeatherKind.values
          .where((k) => k.name == Platform.environment['FILM_WEATHER'])
          .firstOrNull;
      final game = SceneGame(scene: scene)
        ..fieldHourOverride = hour
        ..fieldWeather = weather;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: screen.width,
              height: screen.height,
              child: GameWidget(game: game),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40 && !game.isLoaded; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      game.debugPanTo(cam);
      const dt = 1 / 60;
      for (var i = 0; i < 60; i++) {
        game.update(dt);
      }

      final shots = <ui.Image>[];
      final scale =
          double.tryParse(Platform.environment['FILM_SCALE'] ?? '') ?? 1.5;
      void shoot() {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)
          ..scale(scale)
          ..translate(-crop.left * screen.width, -crop.top * screen.height);
        game.render(c);
        shots.add(
          rec.endRecording().toImageSync(
            (crop.width * screen.width * scale).round(),
            (crop.height * screen.height * scale).round(),
          ),
        );
      }

      // The gesture, then a second and a half of what follows it.
      var clock = 0.0, next = 0.0, camX = cam;
      final total = duration + 1.6;
      var last = Offset(
        path.first.dx * screen.width,
        path.first.dy * screen.height,
      );
      while (clock <= total + 1e-9) {
        if (clock <= duration + 1e-9) {
          final f = duration <= 0 ? 0.0 : (clock / duration).clamp(0.0, 1.0);
          final a = path.first, b = path.last;
          final at = Offset(
            (a.dx + (b.dx - a.dx) * f) * screen.width,
            (a.dy + (b.dy - a.dy) * f) * screen.height,
          );
          final moved = at - last;
          game.debugTouch(at.dx, at.dy, moved.dx, moved.dy);
          // A drag pans the camera the way the game's own drag does.
          if (pans) {
            camX -= moved.dx * 0.5;
            game.debugPanTo(camX);
          }
          last = at;
        }
        game.update(dt);
        clock += dt;
        final most =
            int.tryParse(Platform.environment['FILM_FRAMES'] ?? '') ?? 1000;
        if (clock >= next - 1e-9 && shots.length < most) {
          shoot();
          next += step;
        }
      }
      await tester.pumpWidget(const SizedBox());

      await tester.runAsync(() async {
        final w = shots.first.width.toDouble(),
            h = shots.first.height.toDouble();
        final cols = int.tryParse(Platform.environment['FILM_COLS'] ?? '') ?? 4;
        final rows = (shots.length / cols).ceil();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var i = 0; i < shots.length; i++) {
          c.drawImage(
            shots[i],
            Offset((i % cols) * w, (i ~/ cols) * h),
            Paint(),
          );
        }
        final sheet = rec.endRecording().toImageSync(
          (w * cols).round(),
          (h * rows).round(),
        );
        final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
        final suffix = weather == null ? '' : '_${weather.name}';
        File(
          '$out/$sceneName${suffix}_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
  });
}
