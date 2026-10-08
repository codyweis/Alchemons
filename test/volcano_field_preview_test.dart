@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Volcano drawn in code, rendered through the real SceneGame with
// creatures on its spawns: through the day, a finger across a shelf and
// over the lava, panned right round the loop, and an encounter at every
// point with a partner deployed — one that cannot float, so it must land on
// the shelf the field built for it.
//
//   VOLCANO_OUT=/tmp/volcano flutter test \
//     test/volcano_field_preview_test.dart --tags preview
//
// VOLCANO_OUT is a directory; one PNG per frame. VOLCANO_SIZE=751x475 picks
// the screen (logical px), VOLCANO_SCALE the render scale, VOLCANO_HOURS the
// hours of the day sheet. VOLCANO_ENCOUNTERS=1 adds the encounters (slower),
// VOLCANO_ONLY=day,loop,… a subset,
// VOLCANO_STAGE=0|1|2 the cone still, smoking or erupting for every frame
// (the stages set shows all three anyway, and an eruption through a surge).
void main() {
  final out = Platform.environment['VOLCANO_OUT'];

  testWidgets('volcano field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['VOLCANO_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['VOLCANO_SCALE'] ?? '') ?? 2.0;
    final only = Platform.environment['VOLCANO_ONLY']?.split(',').toSet();
    final stage =
        int.tryParse(Platform.environment['VOLCANO_STAGE'] ?? '') ?? 1;
    bool wants(String set) => only == null || only.contains(set);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in [
        'common/LET01_firelet',
        'common/LET05_steamlet',
        'common/LET06_lavalet',
        'common/LET10_dustlet',
        'uncommon/LET14_spiritlet',
        'rare/HOR01_firehorn',
        'uncommon/MAN01_firemane',
        'uncommon/PIP06_lavapip',
        'legendary/WNG01_firewing',
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

    // Who stands where: grounders on the shelves, the floaters in the air.
    const cast = <String, (String, double)>{
      'SP_volcano_01': ('common/LET01_firelet', 0.7),
      'SP_volcano_02': ('common/LET06_lavalet', 0.75),
      'SP_volcano_03': ('common/LET05_steamlet', 0.75),
      'SP_volcano_04': ('rare/HOR01_firehorn', 1.0),
      'SP_volcano_05': ('common/LET10_dustlet', 0.7),
      'SP_volcano_06': ('uncommon/MAN01_firemane', 0.95),
      'SP_volcano_07': ('uncommon/PIP06_lavapip', 0.85),
      'SP_volcano_08': ('uncommon/LET14_spiritlet', 0.7),
      'SP_volcano_09': ('legendary/WNG01_firewing', 1.0),
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
        double.tryParse(Platform.environment['VOLCANO_STROKE_Y'] ?? '') ??
        0.735;
    final lavaY =
        double.tryParse(Platform.environment['VOLCANO_LAVA_Y'] ?? '') ?? 0.92;

    Future<ui.Image> shoot(
      SceneDefinition scene, {
      required double t,
      double pan = 0,
      String? encounter,
      String? partner,
      double hour = 11,
      double? stroke,
      bool tap = false,
      int? stageOf,
    }) async {
      final game = SceneGame(scene: scene)
        ..fieldHourOverride = hour
        ..fieldStage = stageOf ?? stage;
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
        (Platform.environment['VOLCANO_HOURS'] ??
                '5.3,6.5,11,17.6,18.7,19.4,20.3,23')
            .split(',')
            .where((h) => h.isNotEmpty)
            .map(double.parse);
    final drawn = volcanoScene.art != null;
    final frames = <(String, ui.Image)>[
      if (drawn && wants('day'))
        for (final h in hours)
          (
            'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(volcanoScene, t: 1.5, hour: h),
          ),
      // The cone's three moods, by day and by night, and an eruption
      // across a surge (one comes every 4.6 s, peaking 0.3 s in).
      if (drawn && wants('stages')) ...[
        for (final st in const [0, 1, 2])
          for (final h in const [11.0, 23.0])
            (
              'stage_${st}_${h.round()}',
              await shoot(volcanoScene, t: 3.4, hour: h, stageOf: st),
            ),
        for (final at in const [4.65, 4.95, 5.6, 6.9])
          (
            'surge_${(at * 100).round()}',
            await shoot(volcanoScene, t: at, hour: 19.4, stageOf: 2),
          ),
      ],
      // An eruption's flow, coming down off the cone, over the hills and
      // across the lake, and onto the near field toward the viewer.
      if (drawn && wants('flow'))
        for (final at in const [4.0, 14.0, 24.0, 32.0, 44.0, 56.0, 66.0, 80.0])
          (
            'flow_${at.round().toString().padLeft(2, '0')}',
            await shoot(volcanoScene, t: at, hour: 19.4, stageOf: 2),
          ),
      if (drawn && wants('stroke')) ...[
        ('stroke_day', await shoot(volcanoScene, t: 2.2, stroke: strokeY)),
        (
          'stroke_night',
          await shoot(volcanoScene, t: 2.2, hour: 23, stroke: strokeY),
        ),
        ('stroke_lava', await shoot(volcanoScene, t: 2.2, stroke: lavaY)),
        (
          'tap_lava',
          await shoot(volcanoScene, t: 1.9, stroke: lavaY, tap: true),
        ),
      ],
      // Right round the near layer's loop, a screen at a time.
      if (drawn && wants('loop'))
        for (final pan in const [0.0, 375.0, 750.0, 1125.0, 1400.0, 1600.0])
          ('loop_${pan.round()}', await shoot(volcanoScene, t: 3, pan: pan)),
      if (drawn &&
          wants('encounters') &&
          Platform.environment['VOLCANO_ENCOUNTERS'] == '1')
        for (final p in volcanoScene.spawnPoints)
          (
            'encounter_${p.id.substring(11)}',
            await shoot(
              volcanoScene,
              t: 3.4,
              hour: 17.6,
              encounter: p.id,
              // Firelet cannot float: it must land on its shelf.
              partner: 'LET01',
            ),
          ),
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
        ('stages', 'stage_'),
        ('surge', 'surge_'),
        ('flow', 'flow_'),
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
