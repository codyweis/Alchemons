@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Valley drawn in code, rendered through the real SceneGame with
// creatures standing on its spawns: at rest, under a gust, panned to the far
// end, framed for an encounter, and the old image valley for comparison.
//
//   VALLEY_OUT=/tmp/valley flutter test \
//     test/valley_field_preview_test.dart --tags preview
//
// VALLEY_OUT is a directory; one PNG per frame. VALLEY_SIZE=751x475 picks
// the screen (logical px), VALLEY_SCALE the render scale.
void main() {
  final out = Platform.environment['VALLEY_OUT'];

  testWidgets('valley field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['VALLEY_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['VALLEY_SCALE'] ?? '') ?? 2.0;
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in [
        'rare/HOR03_earthhorn',
        'rare/HOR01_firehorn',
        'common/LET03_earthlet',
        'legendary/WNG04_airwing',
      ]) {
        // The first frame of its spritesheet, which is what the scene draws.
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

    Future<ui.Image> shoot(
      SceneDefinition scene, {
      required double t,
      double pan = 0,
      String? encounter,
      double hour = 18.7,
      bool stroke = false,
      WeatherKind? weather,
      bool rainbow = false,
    }) async {
      final game = SceneGame(scene: scene)
        ..fieldHourOverride = hour
        ..fieldWeather = weather
        ..fieldAftermath = rainbow;
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

      stand('SP_valley_02', 'rare/HOR03_earthhorn', 100);
      stand('SP_valley_06', 'common/LET03_earthlet', 95 * 0.7, flip: true);
      stand('SP_valley_07', 'rare/HOR01_firehorn', 70);
      stand('SP_valley_08', 'legendary/WNG04_airwing', 60 * 1.1);
      stand('SP_valley_04', 'rare/HOR01_firehorn', 100, flip: true);

      if (encounter != null) game.debugFrameEncounter(encounter);
      if (weather != null || rainbow) game.debugSettleWeather();
      // Step the clock to t, so the camera eases where it would.
      const dt = 1 / 30;
      var clock = 0.0;
      while (clock < t) {
        if (encounter == null) game.debugPanTo(pan);
        // A finger dragged left to right through the meadow, ending just
        // before the shot.
        if (stroke && clock > t - 0.75) {
          final f = (clock - (t - 0.75)) / 0.75;
          final x = screen.width * (0.3 + 0.32 * f);
          final y = screen.height * (0.87 + 0.04 * (f - 0.5) * (f - 0.5));
          game.debugTouch(x, y, screen.width * 0.32 / 0.75 * dt, 0);
        }
        game.update(dt);
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

    // A party creature summoned in: grains gathering into it.
    Future<List<(String, ui.Image)>> summon() async {
      final json =
          jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final party = Creature.fromJson(
        (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
          (c) => c['id'] == 'MAN03',
        ),
      );
      final game = SceneGame(scene: valleySceneCorrected)
        ..fieldHourOverride = 18.7;
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
      game.debugFrameEncounter('SP_valley_02');
      for (var i = 0; i < 60; i++) {
        game.update(1 / 30);
      }
      game.spawnPartyCreature(party);
      final shots = <(String, ui.Image)>[];
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        game.update(1 / 30);
        if (i == 12 || i == 20 || i == 28 || i == 39) {
          final rec = ui.PictureRecorder();
          game.render(Canvas(rec)..scale(scale));
          shots.add((
            'summon_$i',
            rec.endRecording().toImageSync(
              (screen.width * scale).round(),
              (screen.height * scale).round(),
            ),
          ));
        }
      }
      await tester.pumpWidget(const SizedBox());
      return shots;
    }

    if (Platform.environment['VALLEY_SUMMON'] == '1') {
      final shots = await summon();
      await tester.runAsync(() async {
        for (final (name, img) in shots) {
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      });
      return;
    }

    final hours =
        (Platform.environment['VALLEY_HOURS'] ??
                '5.3,6.5,11,17.6,18.7,19.4,20.3,23')
            .split(',')
            .where((h) => h.isNotEmpty)
            .map(double.parse);
    final frames = <(String, ui.Image)>[
      for (final h in hours)
        (
          'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
          await shoot(valleySceneCorrected, t: 1.5, hour: h),
        ),
      (
        'stroke_day',
        await shoot(valleySceneCorrected, t: 2.2, hour: 11, stroke: true),
      ),
      (
        'stroke_night',
        await shoot(valleySceneCorrected, t: 2.2, hour: 23, stroke: true),
      ),
      ('rest', await shoot(valleySceneCorrected, t: 1.5)),
      ('gust', await shoot(valleySceneCorrected, t: 3.9)),
      // Panned round the loop: at 1300 the screen straddles every layer's
      // seam at once.
      for (final pan in const [700.0, 1300.0])
        (
          'loop_${pan.round()}',
          await shoot(valleySceneCorrected, t: 6.2, pan: pan),
        ),
      (
        'encounter',
        await shoot(valleySceneCorrected, t: 3, encounter: 'SP_valley_02'),
      ),
      // Rain, and the rainbow after it (a moonbow by night).
      if (Platform.environment['VALLEY_RAIN'] == '1') ...[
        for (final h in const [11.0, 18.7, 23.0])
          (
            'rain_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(
              valleySceneCorrected,
              t: 2.0,
              hour: h,
              weather: WeatherKind.rain,
            ),
          ),
        for (final h in const [8.5, 11.0, 17.6, 18.7, 23.0])
          (
            'bow_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(valleySceneCorrected, t: 2.0, hour: h, rainbow: true),
          ),
      ],
      if (Platform.environment['VALLEY_SNOW'] == '1')
        for (final h in const [8.5, 11.0, 18.7, 23.0])
          (
            'snow_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(
              valleySceneCorrected,
              t: 2.0,
              hour: h,
              weather: WeatherKind.snow,
            ),
          ),
      if (Platform.environment['VALLEY_BEFORE'] == '1')
        ('before', await shoot(_imageValley, t: 1.5)),
    ];

    await tester.runAsync(() async {
      for (final (name, img) in frames) {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      // The day on one sheet, two to a row.
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

/// The Valley as it was: five parallax pictures.
final _imageValley = SceneDefinition(
  worldWidth: 1000,
  worldHeight: 1000,
  layers: const [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/valley/sky.png',
      parallaxFactor: 0.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/valley/clouds.png',
      parallaxFactor: 0.1,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/valley/backhills.png',
      parallaxFactor: 0.35,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/valley/hills.png',
      parallaxFactor: 1.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer5,
      imagePath: 'backgrounds/scenes/valley/foreground.png',
      parallaxFactor: 0.3,
    ),
  ],
  spawnPoints: valleySceneCorrected.spawnPoints,
);
