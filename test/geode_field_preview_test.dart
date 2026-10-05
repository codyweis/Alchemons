@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Geode Hollow drawn in code, rendered through the real SceneGame with
// creatures standing on its spawns: through the day, a finger ploughing the
// sand, the sandstorm, the glass after it, panned round the loop and framed
// for an encounter.
//
//   GEODE_OUT=/tmp/dunes flutter test \
//     test/geode_field_preview_test.dart --tags preview
//
// GEODE_OUT is a directory; one PNG per frame, and day.png with the day on
// one sheet. GEODE_SIZE=751x475 picks the screen (logical px), GEODE_HOURS
// the hours, GEODE_ONLY a comma list of frame-name prefixes to render.
void main() {
  final out = Platform.environment['GEODE_OUT'];

  testWidgets('geode field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['GEODE_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    const scale = 2.0;
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);
    final only = Platform.environment['GEODE_ONLY']?.split(',');
    bool wanted(String name) =>
        only == null || only.any((p) => name.startsWith(p));

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in [
        'rare/HOR11_crystalhorn',
        'common/LET11_crystalet',
        'uncommon/PIP09_icepip',
        'legendary/WNG11_crystalwing',
        'uncommon/MAN11_crystalmane',
      ]) {
        final file = 'assets/images/creatures/${p}_spritesheet.png';
        try {
          final data = await rootBundle.load(file);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final sheet = (await codec.getNextFrame()).image;
          final f = sheet.height;
          final rec = ui.PictureRecorder();
          Canvas(rec).drawImageRect(
            sheet,
            Rect.fromLTWH(0, 0, f.toDouble(), f.toDouble()),
            const Rect.fromLTWH(0, 0, 400, 400),
            Paint()..filterQuality = FilterQuality.medium,
          );
          sprites[p] = rec.endRecording().toImageSync(400, 400);
        } catch (_) {}
      }
    });

    Future<ui.Image> shoot({
      required double t,
      double pan = 0,
      String? encounter,
      double hour = 18.4,
      bool stroke = false,
      bool tap = false,
      WeatherKind? weather,
      bool glass = false,
    }) async {
      final game = SceneGame(scene: geodeScene)
        ..fieldHourOverride = hour
        ..fieldWeather = weather
        ..fieldAftermath = glass;
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
      game.update(0);

      void stand(String spawn, String sprite, double size, {bool flip = false}) {
        final img = sprites[sprite];
        if (img == null) return;
        final c = SpriteComponent(
          sprite: Sprite(img),
          size: Vector2.all(size),
          anchor: Anchor.center,
        );
        if (flip) c.flipHorizontally();
        game.debugStandAt(
          spawn,
          c,
          speciesId: sprite.split('/').last.split('_').first,
          size: Vector2.all(size),
        );
      }

      stand('SP_geode_01', 'rare/HOR11_crystalhorn', 100);
      stand('SP_geode_02', 'common/LET11_crystalet', 70 * 0.75);
      stand('SP_geode_03', 'uncommon/PIP09_icepip', 95 * 0.8, flip: true);
      stand('SP_geode_04', 'legendary/WNG11_crystalwing', 64 * 1.1);
      stand('SP_geode_05', 'uncommon/MAN11_crystalmane', 95, flip: true);
      stand('SP_geode_06', 'rare/HOR11_crystalhorn', 70, flip: true);

      if (encounter != null) game.debugFrameEncounter(encounter);
      if (weather != null || glass) game.debugSettleWeather();
      const dt = 1 / 30;
      var clock = 0.0;
      while (clock < t) {
        if (encounter == null) game.debugPanTo(pan);
        // A finger ploughed left to right through the sand, ending a beat
        // before the shot.
        if (stroke && clock > t - 1.1 && clock < t - 0.35) {
          final f = (clock - (t - 1.1)) / 0.75;
          final x = screen.width * (0.38 + 0.3 * f);
          final y = screen.height * (0.48 + 0.035 * math.sin(f * 3));
          game.debugTouch(x, y, screen.width * 0.3 / 0.75 * dt, 0);
        }
        if (tap && clock < t - 0.3 && clock + dt >= t - 0.3) {
          game.debugTouch(screen.width * 0.9, screen.height * 0.72, 0, 0);
        }
        game.update(dt);
        // The sand moves as it is drawn, as on a phone every frame.
        if ((stroke || tap) && clock > t - 1.3) {
          game.render(Canvas(ui.PictureRecorder()));
        }
        clock += dt;
      }

      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      game.render(c);
      final img = rec.endRecording().toImageSync(
        (screen.width * scale).round(),
        (screen.height * scale).round(),
      );
      await tester.pumpWidget(const SizedBox());
      return img;
    }

    final hours =
        (Platform.environment['GEODE_HOURS'] ??
                '5.8,6.6,9,13,18.4,19.3,20.4,23')
            .split(',')
            .where((h) => h.isNotEmpty)
            .map(double.parse);
    final frames = <(String, ui.Image)>[];
    Future<void> add(String name, Future<ui.Image> Function() make) async {
      if (wanted(name)) frames.add((name, await make()));
    }

    for (final h in hours) {
      await add(
        'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
        () => shoot(t: 1.5, hour: h),
      );
    }
    await add('stir_day', () => shoot(t: 2.4, hour: 13, stroke: true));
    await add('ring_night', () => shoot(t: 2.0, hour: 23, tap: true));
    // The prism at noon, and by moonlight.
    await add('prism_noon', () => shoot(t: 2.5, hour: 12.8, pan: 260));
    await add('prism_moon', () => shoot(t: 2.5, hour: 0.5, pan: 260));
    // The pool, its drips and rings.
    await add('pool_day', () => shoot(t: 4.4, hour: 14, pan: 500));
    await add('pool_night', () => shoot(t: 4.4, hour: 23, pan: 500));
    // Glowworms at night.
    await add('worms', () => shoot(t: 3, hour: 23.5, pan: 100));
    for (final h in const [13.0, 23.0]) {
      await add(
        'sing_${h.toStringAsFixed(1).padLeft(4, '0')}',
        () => shoot(t: 4.0, hour: h, weather: WeatherKind.singing),
      );
    }
    await add('gust', () => shoot(t: 3.9));
    for (final pan in const [700.0, 1300.0]) {
      await add('loop_${pan.round()}', () => shoot(t: 6.2, pan: pan));
    }
    await add('encounter', () => shoot(t: 3, encounter: 'SP_geode_01'));
    for (final h in const [12.0, 18.4, 23.0]) {
      await add(
        'frost_${h.toStringAsFixed(1).padLeft(4, '0')}',
        () => shoot(t: 2.0, hour: h, weather: WeatherKind.frostfall),
      );
    }
    for (final h in const [12.0, 18.4, 23.0]) {
      await add(
        'rime_${h.toStringAsFixed(1).padLeft(4, '0')}',
        () => shoot(t: 2.0, hour: h, glass: true),
      );
    }

    await tester.runAsync(() async {
      for (final (name, img) in frames) {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      final day = [
        for (final f in frames)
          if (f.$1.startsWith('hour_')) f,
      ];
      if (day.isEmpty) return;
      final cw = screen.width, ch = screen.height;
      final rows = (day.length / 2).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < day.length; i++) {
        final img = day[i].$2;
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH((i % 2) * cw, (i ~/ 2) * ch, cw, ch),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final sheet = rec.endRecording().toImageSync(
        (cw * 2).round(),
        (ch * rows).round(),
      );
      final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File('$out/day.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
