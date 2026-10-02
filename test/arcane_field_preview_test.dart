@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/creature_feet.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart' as scene;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Arcane drawn in code, rendered through the real SceneGame with
// creatures on its spawns: through the day, a finger across the ground and
// through the void, panned right round the loop, and an encounter at every
// point with a partner deployed — one that cannot float, so it must land on
// the ground the field built for it.
//
//   ARCANE_OUT=/tmp/arcane flutter test \
//     test/arcane_field_preview_test.dart --tags preview
//
// ARCANE_OUT is a directory; one PNG per frame. ARCANE_SIZE=751x475 picks
// the screen (logical px), ARCANE_SCALE the render scale, ARCANE_HOURS the
// hours of the day sheet. ARCANE_ENCOUNTERS=1 adds the encounters (slower),
// ARCANE_BEFORE=1 the old void (its gradient, its floating creatures and
// the motes drifting over them), ARCANE_ONLY=day,loop,… a subset,
// ARCANE_GROUND=shards|mirror|ruins what the creatures stand on for every
// frame (the options set shows all three, by day, at sunset and by night).
void main() {
  final out = Platform.environment['ARCANE_OUT'];

  testWidgets('arcane field preview', (tester) async {
    if (out == null) return;
    final dims = (Platform.environment['ARCANE_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['ARCANE_SCALE'] ?? '') ?? 2.0;
    final only = Platform.environment['ARCANE_ONLY']?.split(',').toSet();
    bool wants(String set) => only == null || only.contains(set);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final p in _cast.values.map((c) => c.$1).toSet()) {
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
        double.tryParse(Platform.environment['ARCANE_STROKE_Y'] ?? '') ?? 0.74;
    final voidY =
        double.tryParse(Platform.environment['ARCANE_VOID_Y'] ?? '') ?? 0.5;

    Future<ui.Image> shoot(
      SceneDefinition scene, {
      required double t,
      double pan = 0,
      String? encounter,
      String? partner,
      double hour = 11,
      double? stroke,
      bool tap = false,
      bool before = false,
      bool reflect = false,
    }) async {
      final game = SceneGame(scene: scene)..fieldHourOverride = hour;
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
        final who = _cast[p.id];
        final img = who == null ? null : sprites[who.$1];
        if (img == null) continue;
        final size = p.size.x * who!.$2;
        final c = SpriteComponent(
          sprite: Sprite(img),
          size: Vector2.all(size),
          anchor: Anchor.center,
        );
        if (p.normalizedPos.dx > 0.5) c.flipHorizontally();
        // The old void lit its dark creatures from behind so they could be
        // seen at all (WildMonComponent's backlight).
        if (before && who.$3) {
          c.add(
            CircleComponent(
              radius: size * 0.6,
              position: Vector2.all(size / 2),
              anchor: Anchor.center,
              priority: -2,
              paint: Paint()
                ..shader = ui.Gradient.radial(
                  Offset(size * 0.6, size * 0.6),
                  size * 0.6,
                  [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  const [0.0, 0.5, 1.0],
                ),
            ),
          );
        }
        final species = who.$1.split('/').last.split('_').first;
        // On the mirror, its image in the glass under its feet (a stand-in:
        // the game itself does not draw these yet).
        if (reflect) {
          final drop = creatureFeetDrop(species) * size;
          c.add(
            SpriteComponent(
                sprite: Sprite(img),
                size: Vector2.all(size),
                anchor: Anchor.center,
                position: Vector2(size / 2, size / 2 + 2 * drop),
              )
              ..flipVertically()
              ..opacity = 0.3,
          );
        }
        game.debugStandAt(p.id, c, speciesId: species, size: Vector2.all(size));
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
      if (before) _paintOldVoid(c, screen, t);
      game.render(c);
      if (before) _paintOldMotes(c, screen, t);
      final img = rec.endRecording().toImageSync(
        (screen.width * scale).round(),
        (screen.height * scale).round(),
      );
      await tester.pumpWidget(const SizedBox());
      return img;
    }

    final hours =
        (Platform.environment['ARCANE_HOURS'] ??
                '5.3,6.5,11,17.6,18.7,19.4,20.3,23')
            .split(',')
            .where((h) => h.isNotEmpty)
            .map(double.parse);
    final drawn = _arcane.art != null;
    final ground = ArcaneGround.values
        .where((g) => g.name == Platform.environment['ARCANE_GROUND'])
        .firstOrNull;
    final arcaneScene = ground == null
        ? _arcane
        : _arcane.copyWith(art: () => ArcaneField(ground: ground));
    final frames = <(String, ui.Image)>[
      if (drawn && wants('options'))
        for (final g in ArcaneGround.values)
          for (final (h, pan) in const [
            (11.0, 0.0),
            (19.4, 360.0),
            (23.0, 0.0),
            (23.0, 720.0),
          ])
            (
              'option_${g.name}_${h.round()}_${pan.round()}',
              await shoot(
                _arcane.copyWith(art: () => ArcaneField(ground: g)),
                t: 2,
                hour: h,
                pan: pan,
                reflect: g == ArcaneGround.mirror,
              ),
            ),
      if (drawn && wants('day'))
        for (final h in hours)
          (
            'hour_${h.toStringAsFixed(1).padLeft(4, '0')}',
            await shoot(arcaneScene, t: 1.5, hour: h),
          ),
      if (drawn && wants('stroke')) ...[
        ('stroke_day', await shoot(arcaneScene, t: 2.2, stroke: strokeY)),
        (
          'stroke_night',
          await shoot(arcaneScene, t: 2.2, hour: 23, stroke: strokeY),
        ),
        (
          'stroke_void',
          await shoot(arcaneScene, t: 2.2, hour: 23, stroke: voidY),
        ),
        (
          'tap_void',
          await shoot(arcaneScene, t: 1.9, hour: 23, stroke: voidY, tap: true),
        ),
      ],
      // Right round the near layer's loop, a screen at a time.
      if (drawn && wants('loop'))
        for (final pan in const [0.0, 250.0, 500.0, 750.0, 1000.0, 1250.0])
          ('loop_${pan.round()}', await shoot(arcaneScene, t: 3, pan: pan)),
      if (drawn &&
          wants('encounters') &&
          Platform.environment['ARCANE_ENCOUNTERS'] == '1')
        for (final p in arcaneScene.spawnPoints)
          (
            'encounter_${p.id.substring(10)}',
            await shoot(
              arcaneScene,
              t: 3.4,
              hour: 17.6,
              encounter: p.id,
              // Lightlet cannot float: it must land on the ground.
              partner: 'LET16',
            ),
          ),
      if (Platform.environment['ARCANE_BEFORE'] == '1') ...[
        ('before', await shoot(_voidArcane, t: 1.5, before: true)),
        (
          'before_right',
          await shoot(_voidArcane, t: 1.5, pan: 250, before: true),
        ),
      ],
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
        ('befores', 'before'),
        ('options_shards', 'option_shards'),
        ('options_mirror', 'option_mirror'),
        ('options_ruins', 'option_ruins'),
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

/// Who stands where: (sprite, share of the point's size, a dark creature
/// the old void lit from behind).
const _cast = <String, (String, double, bool)>{
  'SP_arcane_01': ('uncommon/LET14_spiritlet', 0.7, true),
  'SP_arcane_02': ('rare/HOR14_spirithorn', 1.0, true),
  'SP_arcane_03': ('rare/PIP15_darkpip', 0.9, true),
  'SP_arcane_04': ('uncommon/LET17_bloodlet', 0.7, true),
  'SP_arcane_05': ('uncommon/LET16_lightlet', 0.7, false),
  'SP_arcane_06': ('legendary/WNG15_darkwing', 1.1, true),
};

/// The old void's backdrop, from scene_page: a dark diagonal gradient.
void _paintOldVoid(Canvas c, Size screen, double t) {
  c.drawRect(
    Offset.zero & screen,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(screen.width, screen.height),
        const [Color(0xFF0A0720), Color(0xFF140028), Color(0xFF020204)],
        const [0.0, 0.5, 1.0],
      ),
  );
}

/// The old void's motes over everything (AlchemicalParticleBackground at
/// the Arcane's palette, opacity 0.9, half density): the same count, sizes
/// and strengths, laid out from a fixed seed.
void _paintOldMotes(Canvas c, Size screen, double t) {
  const palette = [
    Color(0xFF6A1B9A),
    Color(0xFF3949AB),
    Color(0xFF00BCD4),
    Color(0xFF311B92),
  ];
  final r = math.Random(3);
  final n = (screen.width * screen.height * 0.0002 * 0.5).clamp(40, 500);
  for (var i = 0; i < n; i++) {
    final x = r.nextDouble() * screen.width;
    final y = r.nextDouble() * screen.height;
    final colour = palette[r.nextInt(palette.length)];
    final look = r.nextInt(4);
    c.drawCircle(
      Offset(x, y),
      look < 2 ? 0.875 : 1.625,
      Paint()
        ..color = colour.withValues(alpha: (look.isEven ? 0.325 : 0.575) * 0.9),
    );
  }
}

/// The Arcane as it was: no layers at all, three creatures floating in
/// the void.
final _arcane = scene.arcaneScene;

final _voidArcane = SceneDefinition(
  worldWidth: 1000,
  worldHeight: 1000,
  allowVerticalPan: false,
  encounterGroundBias: 0,
  encounterMinZoom: 0.9,
  encounterMaxZoom: 1.3,
  layers: const [
    LayerDefinition(
      id: SceneLayer.layer1,
      imagePath: '',
      parallaxFactor: 0.0,
      widthMul: 1.0,
    ),
  ],
  spawnPoints: [
    SpawnPoint(
      id: 'SP_arcane_01',
      normalizedPos: const Offset(0.30, 0.28),
      anchor: SceneLayer.layer1,
      size: Vector2(80, 80),
      battlePos: const Offset(0.52, 0.28),
    ),
    SpawnPoint(
      id: 'SP_arcane_02',
      normalizedPos: const Offset(0.50, 0.31),
      anchor: SceneLayer.layer1,
      size: Vector2(80, 80),
      battlePos: const Offset(0.32, 0.31),
    ),
    SpawnPoint(
      id: 'SP_arcane_03',
      normalizedPos: const Offset(0.70, 0.34),
      anchor: SceneLayer.layer1,
      size: Vector2(80, 80),
      battlePos: const Offset(0.48, 0.34),
    ),
  ],
);
