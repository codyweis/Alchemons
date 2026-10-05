@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/tidal/tidal_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Tidal Shelf drawn in code, rendered through the real SceneGame with
// creatures standing on its spawns: through the day, a finger ploughing the
// sand, the sandstorm, the glass after it, panned round the loop and framed
// for an encounter.
//
//   TIDAL_OUT=/tmp/dunes flutter test \
//     test/tidal_field_preview_test.dart --tags preview
//
// TIDAL_OUT is a directory; one PNG per frame, and day.png with the day on
// one sheet. TIDAL_SIZE=751x475 picks the screen (logical px), TIDAL_HOURS
// the hours, TIDAL_ONLY a comma list of frame-name prefixes to render.
void main() {
  final out = Platform.environment['TIDAL_OUT'];

  testWidgets('tidal field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['TIDAL_SIZE'] ?? '751x475')
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
    final only = Platform.environment['TIDAL_ONLY']?.split(',');
    bool wanted(String name) =>
        only == null || only.any((p) => name.startsWith(p));

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in [
        'rare/HOR02_waterhorn',
        'common/LET02_waterlet',
        'uncommon/PIP08_mudpip',
        'legendary/WNG02_waterwing',
        'uncommon/MAN02_watermane',
        'legendary/KIN02_waterkin',
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
      final game = SceneGame(scene: tidalScene)
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

      void stand(
        String spawn,
        String sprite,
        double size, {
        bool flip = false,
      }) {
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

      stand('SP_tidal_01', 'rare/HOR02_waterhorn', 100);
      stand('SP_tidal_02', 'common/LET02_waterlet', 70 * 0.75);
      stand('SP_tidal_03', 'uncommon/PIP08_mudpip', 95 * 0.8, flip: true);
      stand('SP_tidal_04', 'legendary/WNG02_waterwing', 64 * 1.1);
      stand('SP_tidal_05', 'uncommon/MAN02_watermane', 95, flip: true);
      stand('SP_tidal_06', 'rare/HOR02_waterhorn', 70, flip: true);
      stand('SP_tidal_09', 'uncommon/MAN02_watermane', 76 * 0.85);
      stand('SP_tidal_10', 'legendary/KIN02_waterkin', 62);

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
          final y = screen.height * (0.85 + 0.01 * math.sin(f * 3));
          game.debugTouch(x, y, screen.width * 0.3 / 0.75 * dt, 0);
        }
        if (tap && clock < t - 0.3 && clock + dt >= t - 0.3) {
          game.debugTouch(196, screen.height * 0.926, 0, 0);
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
        (Platform.environment['TIDAL_HOURS'] ??
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
    // The tide: low water and high, by day and by night.
    for (final (name, tide, hour) in const [
      ('low_day', 0.0, 13.0),
      ('high_day', 1.0, 13.0),
      ('low_night', 0.0, 23.0),
      ('high_night', 1.0, 23.0),
      ('mid_gold', 0.5, 18.6),
    ]) {
      await add(name, () {
        TidalField.debugTide = tide;
        return shoot(t: 3.0, hour: hour);
      });
    }
    TidalField.debugTide = 0.6;
    await add('wake_night', () => shoot(t: 2.4, hour: 23, stroke: true));
    TidalField.debugTide = 0.0;
    await add('pool_tap', () => shoot(t: 2.0, hour: 13, tap: true));
    for (final h in const [13.0, 22.0]) {
      await add(
        'swell_${h.toStringAsFixed(1).padLeft(4, '0')}',
        () => shoot(t: 4.0, hour: h, weather: WeatherKind.swell),
      );
    }
    TidalField.debugTide = 0.45;
    await add('swim_day', () => shoot(t: 3.0, hour: 13));
    await add('swim_night', () => shoot(t: 3.0, hour: 23));
    await add('swim_far', () => shoot(t: 3.0, hour: 16, pan: 560));
    await add('gust', () => shoot(t: 3.9));
    for (final pan in const [700.0, 1300.0]) {
      await add('loop_${pan.round()}', () => shoot(t: 6.2, pan: pan));
    }
    await add('encounter', () => shoot(t: 3, encounter: 'SP_tidal_01'));
    for (final h in const [12.0, 18.4, 23.0]) {
      await add(
        'fog_${h.toStringAsFixed(1).padLeft(4, '0')}',
        () => shoot(t: 2.0, hour: h, weather: WeatherKind.fog),
      );
    }
    for (final h in const [12.0, 18.4, 23.0]) {
      await add(
        'wrack_${h.toStringAsFixed(1).padLeft(4, '0')}',
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
