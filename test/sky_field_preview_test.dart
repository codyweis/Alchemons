@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Skyward Reach drawn in code, rendered through the real SceneGame with
// creatures on its spawns: through the day, a finger through an isle's
// grass, panned right round the loop, and an encounter at every point with
// a partner deployed — one that cannot float, so it must land on the isle
// the field built for it.
//
//   SKY_OUT=/tmp/sky flutter test test/sky_field_preview_test.dart \
//     --tags preview
//
// SKY_OUT is a directory; one PNG per frame. SKY_SIZE=751x475 picks the
// screen (logical px), SKY_SCALE the render scale, SKY_HOURS the hours of
// the day sheet. SKY_ENCOUNTERS=1 adds the encounters (slower), SKY_BEFORE=1
// the old picture sky.
void main() {
  final out = Platform.environment['SKY_OUT'];

  testWidgets('sky field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['SKY_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['SKY_SCALE'] ?? '') ?? 2.0;
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in [
        'common/LET04_airlet',
        'uncommon/LET16_lightlet',
        'rare/HOR04_airhorn',
        'legendary/WNG04_airwing',
        'uncommon/MAN04_airmane',
        'uncommon/LET14_spiritlet',
        'uncommon/PIP04_airpip',
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

    // Who stands where: grounders on the isles, floaters in the open air.
    const cast = <String, (String, double)>{
      'SP_sky_01': ('common/LET04_airlet', 0.7),
      'SP_sky_02': ('legendary/WNG04_airwing', 1.1),
      'SP_sky_03': ('uncommon/MAN04_airmane', 0.9),
      'SP_sky_04': ('uncommon/LET16_lightlet', 0.7),
      'SP_sky_05': ('rare/HOR04_airhorn', 1.0),
      'SP_sky_06': ('uncommon/PIP04_airpip', 0.9),
      'SP_sky_07': ('legendary/WNG04_airwing', 1.1),
      'SP_sky_08': ('uncommon/LET14_spiritlet', 0.7),
    };

    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    Creature creature(String id) => Creature.fromJson(
      (json['creatures'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) => c['id'] == id,
      ),
    );

    Future<ui.Image> shoot(
      SceneDefinition scene, {
      required double t,
      double pan = 0,
      String? encounter,
      String? partner,
      double hour = 11,
      bool stroke = false,
      bool? strike,
    }) async {
      final game = SceneGame(scene: scene)
        ..fieldHourOverride = hour
        ..fieldWeather = strike != null ? WeatherKind.storm : null;
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

      for (final p in scene.spawnPoints) {
        final who = cast[p.id];
        final img = who == null ? null : sprites[who.$1];
        if (img == null) continue;
        final size = p.size.x * who!.$2;
        final c = SpriteComponent(
          sprite: Sprite(img),
          size: Vector2.all(size),
          anchor: Anchor.center,
        );
        if (p.normalizedPos.dx > 0.5) c.flipHorizontally();
        game.debugStandAt(
          p.id,
          c,
          speciesId: who.$1.split('/').last.split('_').first,
          size: Vector2.all(size),
        );
      }

      if (encounter != null) game.debugFrameEncounter(encounter);
      if (strike != null) game.debugSettleWeather();
      const dt = 1 / 30;
      var clock = 0.0;
      var deployed = false;
      while (clock < t) {
        if (encounter == null) game.debugPanTo(pan);
        if (partner != null && !deployed && clock > 1.0) {
          deployed = true;
          game.spawnPartyCreature(creature(partner));
        }
        // A finger dragged left to right through the first isle's grass,
        // ending just before the shot.
        if (stroke && clock > t - 0.75) {
          final f = (clock - (t - 0.75)) / 0.75;
          final x = screen.width * (0.28 + 0.26 * f);
          final y = screen.height * 0.655;
          game.debugTouch(x, y, screen.width * 0.26 / 0.75 * dt, 0);
        }
        if (deployed) {
          // The partner's sprite loads off the test clock.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 4)),
          );
        }
        game.update(dt);
        clock += dt;
        // The last half second is drawn as a phone would draw it, frame by
        // frame (the field learns where the camera is from its frames).
        if (clock > t - 0.5) {
          final rec = ui.PictureRecorder();
          game.render(Canvas(rec));
          rec.endRecording().dispose();
        }
        // Lightning a few frames before the shot, so it is at its height.
        if (strike != null && (t - clock - 0.1).abs() < dt / 2) {
          (game.debugField as SkyField).debugStrike(bolt: strike);
        }
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

    // A bolt, frame by frame: the leader striking down, the flash when it
    // lands, the channel crackling with each flicker.
    if (Platform.environment['SKY_BOLTFILM'] == '1') {
      final game = SceneGame(scene: skyScene)
        ..fieldHourOverride = 23
        ..fieldWeather = WeatherKind.storm;
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
      game.debugSettleWeather();
      const dt = 1 / 120;
      const ages = [
        0.0,
        0.02,
        0.04,
        0.06,
        0.08,
        0.1,
        0.13,
        0.17,
        0.22,
        0.28,
        0.34,
        0.42,
      ];
      final shots = <ui.Image>[];
      var clock = 0.0;
      double? struck;
      var next = 0;
      while (next < ages.length) {
        game.update(dt);
        clock += dt;
        if (struck == null && clock >= 1.0) {
          (game.debugField as SkyField).debugStrike(bolt: true);
          struck = clock + dt;
        }
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..scale(0.8);
        game.render(c);
        final pic = rec.endRecording();
        if (struck != null && clock - struck >= ages[next] - 1e-9) {
          shots.add(
            pic.toImageSync(
              (screen.width * 0.8).round(),
              (screen.height * 0.8).round(),
            ),
          );
          next++;
        }
        pic.dispose();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        final w = shots.first.width.toDouble(),
            h = shots.first.height.toDouble();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var i = 0; i < shots.length; i++) {
          c.drawImage(shots[i], Offset((i % 4) * w, (i ~/ 4) * h), Paint());
        }
        final sheet = rec.endRecording().toImageSync(
          (w * 4).round(),
          (h * 3).round(),
        );
        final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/bolt_film.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      return;
    }

    final hours =
        (Platform.environment['SKY_HOURS'] ??
                '5.3,6.5,11,17.6,18.7,19.4,20.3,23')
            .split(',')
            .where((h) => h.isNotEmpty)
            .map(double.parse);
    final frames = <(String, ui.Image)>[
      for (final h in hours)
        (
          'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
          await shoot(skyScene, t: 1.5, hour: h),
        ),
      ('stroke_day', await shoot(skyScene, t: 2.2, stroke: true)),
      ('stroke_night', await shoot(skyScene, t: 2.2, hour: 23, stroke: true)),
      // The isle that water runs off, in the low sun.
      ('falls', await shoot(skyScene, t: 3, pan: 950, hour: 18.7)),
      // Right round the near isles' loop, a screen at a time.
      for (final pan in const [375.0, 750.0, 1125.0, 1500.0])
        ('loop_${pan.round()}', await shoot(skyScene, t: 3, pan: pan)),
      if (Platform.environment['SKY_ENCOUNTERS'] == '1')
        for (final p in skyScene.spawnPoints)
          (
            'encounter_${p.id.substring(7)}',
            await shoot(
              skyScene,
              t: 3.4,
              hour: 17.6,
              encounter: p.id,
              // Lightlet cannot float: it must land on its isle.
              partner: 'LET16',
            ),
          ),
      if (Platform.environment['SKY_STORM'] == '1') ...[
        for (final h in const [11.0, 18.7, 23.0])
          (
            'storm_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(skyScene, t: 2.0, hour: h, strike: true),
          ),
        ('storm_flicker', await shoot(skyScene, t: 2.0, strike: false)),
        ('storm_calm', await shoot(skyScene, t: 1.0, strike: false)),
      ],
      if (Platform.environment['SKY_BEFORE'] == '1')
        ('before', await shoot(_imageSky, t: 1.5)),
    ];

    await tester.runAsync(() async {
      for (final (name, img) in frames) {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      // Contact sheets, two to a row: the day, the loop, the encounters.
      for (final (name, prefix) in const [
        ('day', 'hour_'),
        ('loop', 'loop_'),
        ('encounters', 'encounter_'),
      ]) {
        final set = [
          for (final f in frames)
            if (f.$1.startsWith(prefix)) f,
        ];
        if (set.isEmpty) continue;
        final cw = screen.width, ch = screen.height;
        final rows = (set.length / 2).ceil();
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var i = 0; i < set.length; i++) {
          final img = set[i].$2;
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
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    });
  });
}

/// The Sky as it was: three parallax pictures.
final _imageSky = SceneDefinition(
  worldWidth: 1600,
  worldHeight: 850,
  layers: const [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/sky/sky.png',
      parallaxFactor: 0.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/sky/midground.png',
      parallaxFactor: 0.1,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/sky/foreground.png',
      parallaxFactor: 0.7,
    ),
  ],
);
