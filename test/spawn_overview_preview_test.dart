@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/tidal/tidal_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Every spawn point of a wild field at once, each with a creature standing
// on it and its id written over it, panned round the whole loop: for
// placing new points and checking each has something under its feet.
//
//   SPAWNS_OUT=/tmp/spawns SPAWNS_FIELD=valley flutter test \
//     test/spawn_overview_preview_test.dart --tags preview
//
// SPAWNS_FIELD is valley, sky, swamp, volcano, dunes, geode, tidal or
// arcane. SPAWNS_WEATHER names a WeatherKind (dry, storm, …) to show the
// points that are there only in it. SPAWNS_HOUR (default 12), SPAWNS_SIZE
// (default 751x475), SPAWNS_SCALE (default 1.5).
void main() {
  final out = Platform.environment['SPAWNS_OUT'];

  testWidgets('spawn overview preview', (tester) async {
    if (out == null) return;
    final name = Platform.environment['SPAWNS_FIELD'] ?? 'valley';
    final scene = switch (name) {
      'valley' => valleySceneCorrected,
      'sky' => skyScene,
      'swamp' => swampScene,
      'volcano' => volcanoScene,
      'dunes' => dunesScene,
      'geode' => geodeScene,
      'tidal' => tidalScene,
      'arcane' => arcaneScene,
      _ => throw ArgumentError('unknown field $name'),
    };
    final weatherName = Platform.environment['SPAWNS_WEATHER'];
    final weather = weatherName == null
        ? null
        : WeatherKind.values.firstWhere((w) => w.name == weatherName);
    final hour =
        double.tryParse(Platform.environment['SPAWNS_HOUR'] ?? '') ?? 12;
    final dims = (Platform.environment['SPAWNS_SIZE'] ?? '751x475')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final scale =
        double.tryParse(Platform.environment['SPAWNS_SCALE'] ?? '') ?? 1.5;
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    const walker = 'common/LET03_earthlet';
    const big = 'rare/HOR03_earthhorn';
    const flyer = 'legendary/WNG04_airwing';
    const wader = 'common/LET02_waterlet';
    final sprites = <String, ui.Image>{};
    await tester.runAsync(() async {
      // A real face for the point ids (tests draw text in boxes otherwise).
      final font = File('/System/Library/Fonts/Supplemental/Arial Bold.ttf');
      if (font.existsSync()) {
        await (FontLoader('SpawnLabel')..addFont(
              Future.value(ByteData.view(font.readAsBytesSync().buffer)),
            ))
            .load();
      }
      for (final p in [walker, big, flyer, wader]) {
        final file = 'assets/images/creatures/${p}_spritesheet.png';
        final data = await rootBundle.load(file);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final sheet = (await codec.getNextFrame()).image;
        final f = sheet.height.toDouble();
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(
          sheet,
          Rect.fromLTWH(0, 0, f, f),
          const Rect.fromLTWH(0, 0, 400, 400),
          Paint()..filterQuality = FilterQuality.medium,
        );
        sprites[p] = rec.endRecording().toImageSync(400, 400);
      }
    });

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
    game.update(0);
    if (weather != null) game.debugSettleWeather();

    var n = 0;
    for (final p in scene.spawnPoints) {
      if (p.onlyIn != null && p.onlyIn != weather) continue;
      final sprite = switch (p.perch) {
        SpawnPerch.air => flyer,
        SpawnPerch.wade => wader,
        SpawnPerch.ground => n++ % 2 == 0 ? walker : big,
      };
      final size = p.size.x;
      game.debugStandAt(
        p.id,
        SpriteComponent(
          sprite: Sprite(sprites[sprite]!),
          size: Vector2.all(size),
          anchor: Anchor.center,
        ),
        speciesId: sprite.split('/').last.split('_').first,
        size: Vector2.all(size),
      );
      game.debugStandAt(
        p.id,
        TextComponent(
          text: p.id.replaceFirst(RegExp(r'^SP_[a-z]+_'), ''),
          anchor: Anchor.bottomCenter,
          position: Vector2(0, -size * 0.55),
          textRenderer: TextPaint(
            style: TextStyle(
              color: p.aloft ? const Color(0xFF7FD4FF) : const Color(0xFFFFE27A),
              fontFamily: 'SpawnLabel',
              fontSize: 15,
              shadows: const [Shadow(blurRadius: 3)],
            ),
          ),
        ),
      );
    }

    // Round the loop: far enough each step that the fastest layer anything
    // stands on is seen whole.
    final fastest = scene.spawnPoints
        .map(
          (p) => scene.layers.firstWhere((l) => l.id == p.anchor).parallaxFactor,
        )
        .reduce(math.max);
    final step = screen.width * 0.9 / (1 + fastest);
    final shots = (scene.worldWidth / step).ceil();
    for (var s = 0; s < shots; s++) {
      game.debugPanTo(s * step);
      for (var i = 0; i < 8; i++) {
        game.debugPanTo(s * step);
        game.update(1 / 30);
      }
      final rec = ui.PictureRecorder();
      game.render(Canvas(rec)..scale(scale));
      final img = rec.endRecording().toImageSync(
        (screen.width * scale).round(),
        (screen.height * scale).round(),
      );
      await tester.runAsync(() async {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${name}_${s.toString().padLeft(2, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
