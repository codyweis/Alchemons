@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/widgets/wilderness/wild_globe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The wilderness map as a grain globe: each biome turned to face you, the
// day on the Valley, the weathers, and night on the Volcano and the Swamp.
//
//   GLOBE_OUT=/tmp/globe flutter test \
//     test/wild_globe_preview_test.dart --tags preview
//
// GLOBE_OUT is a directory; one PNG per frame plus contact sheets.
// GLOBE_SIZE=412x520 picks the map area (logical px), GLOBE_SCALE the
// render scale, GLOBE_ONLY=faces,hours,weather,night,extras a subset.
void main() {
  final out = Platform.environment['GLOBE_OUT'];

  testWidgets('wild globe preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['GLOBE_SIZE'] ?? '412x520')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['GLOBE_SCALE'] ?? '') ?? 2.0;
    final only = Platform.environment['GLOBE_ONLY']?.split(',').toSet();
    bool want(String s) => only == null || only.contains(s);
    Directory(out).createSync(recursive: true);

    final built = Stopwatch()..start();
    final globe = WildGlobe();
    built.stop();
    final centre = Offset(screen.width / 2, screen.height / 2);
    final radius = screen.shortestSide * 0.42;
    const allSpawns = {
      GlobeBiome.valley: 5,
      GlobeBiome.sky: 4,
      GlobeBiome.swamp: 6,
      GlobeBiome.volcano: 3,
    };

    void background(Canvas c) {
      c.drawRect(
        Offset.zero & screen,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            screen.longestSide * 0.7,
            const [Color(0xFF16141E), Color(0xFF0B0A10)],
          ),
      );
    }

    ui.Image shoot({
      GlobeBiome? face,
      double? yaw,
      double? lean,
      double hour = 11,
      Map<GlobeBiome, WeatherKind> weather = const {},
      Map<GlobeBiome, int> spawns = allSpawns,
      bool arcane = false,
      double t = 6,
    }) {
      globe
        ..conditions = GlobeConditions(
          hour: hour,
          weather: weather,
          spawns: spawns,
          arcane: arcane,
          moon: 0.8,
        )
        ..time = 0;
      if (face != null) globe.face(face);
      if (yaw != null) globe.yaw = yaw;
      if (lean != null) globe.lean = lean;
      globe.settle();
      const dt = 1 / 30;
      for (var clock = 0.0; clock < t; clock += dt) {
        globe.step(dt);
      }
      globe.time = t;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      background(c);
      globe.paint(c, centre, radius);
      return rec.endRecording().toImageSync(
        (screen.width * scale).round(),
        (screen.height * scale).round(),
      );
    }

    final frames = <(String, String, ui.Image)>[];
    void add(String sheet, String name, ui.Image img) =>
        frames.add((sheet, name, img));

    if (want('faces')) {
      for (final b in GlobeBiome.values) {
        add('faces', 'face_${b.name}', shoot(face: b));
      }
    }
    if (want('hours')) {
      for (final h in const [5.3, 6.5, 8.5, 11.0, 17.6, 18.7, 19.6, 23.0]) {
        add(
          'hours',
          'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
          shoot(face: GlobeBiome.valley, hour: h),
        );
      }
    }
    if (want('weather')) {
      // The storm at the brightest moment of a strike in its first ten
      // seconds.
      var strike = 6.0, best = 0.0;
      for (var t = 2.0; t < 12; t += 0.05) {
        globe
          ..conditions = const GlobeConditions(
            hour: 14,
            weather: {GlobeBiome.sky: WeatherKind.storm},
          )
          ..face(GlobeBiome.sky)
          ..settle()
          ..time = t;
        final rec = ui.PictureRecorder();
        globe.paint(Canvas(rec), centre, radius);
        rec.endRecording().dispose();
        if (globe.debugFlash > best) {
          best = globe.debugFlash;
          strike = t;
        }
      }
      add(
        'weather',
        'wx_sky_storm',
        shoot(
          face: GlobeBiome.sky,
          hour: 14,
          weather: {GlobeBiome.sky: WeatherKind.storm},
          t: strike,
        ),
      );
      add(
        'weather',
        'wx_valley_rain',
        shoot(
          face: GlobeBiome.valley,
          weather: {GlobeBiome.valley: WeatherKind.rain},
        ),
      );
      add(
        'weather',
        'wx_valley_snow',
        shoot(
          face: GlobeBiome.valley,
          weather: {GlobeBiome.valley: WeatherKind.snow},
        ),
      );
      add(
        'weather',
        'wx_swamp_dry',
        shoot(
          face: GlobeBiome.swamp,
          weather: {GlobeBiome.swamp: WeatherKind.dry},
        ),
      );
    }
    if (want('night')) {
      add('night', 'night_volcano', shoot(face: GlobeBiome.volcano, hour: 23));
      add('night', 'night_swamp', shoot(face: GlobeBiome.swamp, hour: 23));
      add('night', 'night_sky', shoot(face: GlobeBiome.sky, hour: 23));
      add('night', 'dusk_volcano', shoot(face: GlobeBiome.volcano, hour: 19.4));
    }
    if (want('extras')) {
      // Halfway round from one biome to the next, and Arcane's rift.
      final (vy, vl) = globe.facing(GlobeBiome.valley);
      final (sy, sl) = globe.facing(GlobeBiome.sky);
      add(
        'extras',
        'between_valley_sky',
        shoot(yaw: (vy + sy) / 2, lean: (vl + sl) / 2, hour: 16),
      );
      final (wy, wl) = globe.facing(GlobeBiome.swamp);
      final (oy, ol) = globe.facing(GlobeBiome.volcano);
      add(
        'extras',
        'between_swamp_volcano',
        shoot(yaw: (wy + oy) / 2, lean: (wl + ol) / 2, hour: 10),
      );
      for (final t in const [4.0, 30.0]) {
        add(
          'extras',
          'arcane_${t.round()}',
          shoot(face: GlobeBiome.valley, arcane: true, t: t, hour: 15),
        );
      }
    }

    // What a frame costs to record, at rest on the Valley by day and on the
    // Volcano by night.
    final costs = <String>[];
    for (final (name, b, h) in [
      ('valley day', GlobeBiome.valley, 11.0),
      ('volcano night', GlobeBiome.volcano, 23.0),
      ('sky storm', GlobeBiome.sky, 14.0),
    ]) {
      globe
        ..conditions = GlobeConditions(
          hour: h,
          spawns: allSpawns,
          arcane: true,
          weather: b == GlobeBiome.sky
              ? const {GlobeBiome.sky: WeatherKind.storm}
              : const {},
        )
        ..face(b)
        ..settle();
      for (var i = 0; i < 20; i++) {
        final rec = ui.PictureRecorder();
        globe
          ..step(1 / 60)
          ..paint(Canvas(rec), centre, radius);
        rec.endRecording().dispose();
      }
      final sw = Stopwatch()..start();
      const n = 60;
      for (var i = 0; i < n; i++) {
        final rec = ui.PictureRecorder();
        globe
          ..step(1 / 60)
          ..yaw += 0.002
          ..paint(Canvas(rec), centre, radius);
        rec.endRecording().dispose();
      }
      sw.stop();
      costs.add(
        '$name: ${(sw.elapsedMicroseconds / n).round()} µs/frame, '
        '${globe.debugGrains} grains',
      );
    }
    // ignore: avoid_print
    print(
      'globe built in ${built.elapsedMilliseconds} ms\n${costs.join('\n')}',
    );

    await tester.runAsync(() async {
      for (final (_, name, img) in frames) {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      // A contact sheet per group, four to a row.
      final groups = <String, List<ui.Image>>{};
      for (final (sheet, _, img) in frames) {
        (groups[sheet] ??= []).add(img);
      }
      for (final MapEntry(key: sheet, value: imgs) in groups.entries) {
        final cols = imgs.length < 4 ? imgs.length : 4;
        final rows = (imgs.length / cols).ceil();
        final cw = screen.width, ch = screen.height;
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var i = 0; i < imgs.length; i++) {
          final img = imgs[i];
          c.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH((i % cols) * cw, (i ~/ cols) * ch, cw, ch),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
        final img = rec.endRecording().toImageSync(
          (cw * cols).round(),
          (ch * rows).round(),
        );
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$sheet.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}
