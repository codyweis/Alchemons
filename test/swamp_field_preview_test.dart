@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Swamp drawn in code, rendered through the real SceneGame with
// creatures on its spawns: through the day, a finger through a bank's grass
// and across the water, panned right round the loop, and an encounter at
// every point with a partner deployed — one that cannot float, so it must
// land on the bank the field built for it.
//
//   SWAMP_OUT=/tmp/swamp flutter test test/swamp_field_preview_test.dart \
//     --tags preview
//
// SWAMP_OUT is a directory; one PNG per frame. SWAMP_SIZE=751x475 picks the
// screen (logical px), SWAMP_SCALE the render scale, SWAMP_HOURS the hours
// of the day sheet. SWAMP_ENCOUNTERS=1 adds the encounters (slower),
// SWAMP_BEFORE=1 the old picture swamp, SWAMP_ONLY=day,loop,… a subset,
// SWAMP_DRY=1 the Swamp gone dry.
void main() {
  final out = Platform.environment['SWAMP_OUT'];

  testWidgets('swamp field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['SWAMP_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['SWAMP_SCALE'] ?? '') ?? 2.0;
    final only = Platform.environment['SWAMP_ONLY']?.split(',').toSet();
    final dry = Platform.environment['SWAMP_DRY'] == '1';
    bool wants(String set) => only == null || only.contains(set);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in [
        'common/LET02_waterlet',
        'common/LET08_mudlet',
        'common/LET04_airlet',
        'rare/HOR08_mudhorn',
        'legendary/WNG08_mudwing',
        'uncommon/MAN08_mudmane',
        'uncommon/PIP13_poisonpip',
        'uncommon/MAN13_poisonmane',
        'uncommon/LET14_spiritlet',
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

    // Who stands where: grounders on the banks, the wing in the open air.
    const cast = <String, (String, double)>{
      'SP_swamp_01': ('common/LET02_waterlet', 0.7),
      'SP_swamp_02': ('uncommon/MAN08_mudmane', 0.95),
      'SP_swamp_03': ('legendary/WNG08_mudwing', 1.1),
      'SP_swamp_04': ('rare/HOR08_mudhorn', 1.0),
      'SP_swamp_05': ('common/LET08_mudlet', 0.7),
      'SP_swamp_06': ('uncommon/PIP13_poisonpip', 0.9),
      'SP_swamp_07': ('uncommon/MAN13_poisonmane', 0.9),
      'SP_swamp_08': ('uncommon/LET14_spiritlet', 0.7),
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

    final strokeY =
        double.tryParse(Platform.environment['SWAMP_STROKE_Y'] ?? '') ?? 0.735;
    final waterY =
        double.tryParse(Platform.environment['SWAMP_WATER_Y'] ?? '') ?? 0.9;

    Future<ui.Image> shoot(
      SceneDefinition scene, {
      required double t,
      double pan = 0,
      String? encounter,
      String? partner,
      double hour = 11,
      double? stroke,
      bool tap = false,
    }) async {
      final game = SceneGame(scene: scene)
        ..fieldHourOverride = hour
        ..fieldWeather = dry && scene == swampScene ? WeatherKind.dry : null;
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
      const dt = 1 / 30;
      var clock = 0.0;
      var deployed = false;
      while (clock < t) {
        if (encounter == null) game.debugPanTo(pan);
        if (partner != null && !deployed && clock > 1.0) {
          deployed = true;
          game.spawnPartyCreature(creature(partner));
        }
        // A finger dragged left to right at [stroke] (a share of the
        // height), ending just before the shot — or a tap there.
        if (stroke != null && clock > t - 0.75) {
          final f = (clock - (t - 0.75)) / 0.75;
          if (!tap) {
            final x = screen.width * (0.3 + 0.26 * f);
            game.debugTouch(
              x,
              screen.height * stroke,
              screen.width * 0.26 / 0.75 * dt,
              0,
            );
          } else if (f < dt / 0.75) {
            game.debugTouch(screen.width * 0.45, screen.height * stroke, 0, 0);
          }
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
        (Platform.environment['SWAMP_HOURS'] ??
                '5.3,6.5,11,17.6,18.7,19.4,20.3,23')
            .split(',')
            .where((h) => h.isNotEmpty)
            .map(double.parse);
    final frames = <(String, ui.Image)>[
      if (wants('day'))
        for (final h in hours)
          (
            'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(swampScene, t: 1.5, hour: h),
          ),
      if (wants('stroke')) ...[
        ('stroke_day', await shoot(swampScene, t: 2.2, stroke: strokeY)),
        (
          'stroke_night',
          await shoot(swampScene, t: 2.2, hour: 23, stroke: strokeY),
        ),
        ('stroke_water', await shoot(swampScene, t: 2.2, stroke: waterY)),
        (
          'tap_water',
          await shoot(swampScene, t: 1.9, stroke: waterY, tap: true),
        ),
      ],
      // Right round the near layer's loop, a screen at a time.
      if (wants('loop'))
        for (final pan in const [0.0, 375.0, 750.0, 1125.0, 1300.0, 1500.0])
          ('loop_${pan.round()}', await shoot(swampScene, t: 3, pan: pan)),
      if (wants('encounters') &&
          Platform.environment['SWAMP_ENCOUNTERS'] == '1')
        for (final p in swampScene.spawnPoints)
          (
            'encounter_${p.id.substring(9)}',
            await shoot(
              swampScene,
              t: 3.4,
              hour: 17.6,
              encounter: p.id,
              // Mudlet cannot float: it must land on its bank.
              partner: 'LET08',
            ),
          ),
      if (Platform.environment['SWAMP_BEFORE'] == '1')
        ('before', await shoot(_imageSwamp, t: 1.5)),
    ];

    await tester.runAsync(() async {
      for (final (name, img) in frames) {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      // Contact sheets, two to a row: the day, the loop, the encounters,
      // the strokes.
      for (final (name, prefix) in const [
        ('day', 'hour_'),
        ('loop', 'loop_'),
        ('encounters', 'encounter_'),
        ('strokes', 'stroke_'),
      ]) {
        final set = [
          for (final f in frames)
            if (f.$1.startsWith(prefix) ||
                (prefix == 'stroke_' && f.$1.startsWith('tap_')))
              f,
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

/// The Swamp as it was: five parallax pictures.
final _imageSwamp = SceneDefinition(
  worldWidth: 1000,
  worldHeight: 1500,
  layers: const [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: 'backgrounds/scenes/swamp/sky.png',
      parallaxFactor: 0.0,
    ),
    LayerDefinition(
      id: SceneLayer.layer2,
      imagePath: 'backgrounds/scenes/swamp/background.png',
      parallaxFactor: 0.1,
    ),
    LayerDefinition(
      id: SceneLayer.layer3,
      imagePath: 'backgrounds/scenes/swamp/backtrees.png',
      parallaxFactor: 0.2,
    ),
    LayerDefinition(
      id: SceneLayer.layer4,
      imagePath: 'backgrounds/scenes/swamp/fronttrees.png',
      parallaxFactor: 0.5,
    ),
    LayerDefinition(
      id: SceneLayer.layer5,
      imagePath: 'backgrounds/scenes/swamp/foreground.png',
      parallaxFactor: 1,
    ),
  ],
);
