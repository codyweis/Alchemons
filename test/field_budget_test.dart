// The fields drawn in code — the Valley, the Sky, the Swamp, the Volcano
// and the Arcane — draw every frame, under the encounter, the harvest and the
// fusion. Their still parts are baked once; what is left per frame is the
// sky, the baked sheets and the live grass, motes, glints, water and lava. These pin that it stays that
// way for each: no blur passes, a handful of draws, and a ceiling on the
// grains a frame walks.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:alchemons/models/scenes/dunes/dunes_scene.dart';
import 'package:alchemons/models/scenes/geode/geode_scene.dart';
import 'package:alchemons/models/scenes/tidal/tidal_scene.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;
  int points = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
      if (key == 'drawRawPoints' && a is Float32List) points += a.length ~/ 2;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

/// A field and how to exercise it: the spawn an encounter frames, and the
/// height (a share of the screen) a finger strokes its grass at.
typedef _Field = ({
  String name,
  SceneDefinition scene,
  String encounter,
  double strokeY,
});

final _fields = <_Field>[
  (
    name: 'valley',
    scene: valleySceneCorrected,
    encounter: 'SP_valley_02',
    strokeY: 0.88,
  ),
  (name: 'sky', scene: skyScene, encounter: 'SP_sky_01', strokeY: 0.655),
  (name: 'swamp', scene: swampScene, encounter: 'SP_swamp_01', strokeY: 0.745),
  (
    name: 'volcano',
    scene: volcanoScene,
    encounter: 'SP_volcano_02',
    strokeY: 0.765,
  ),
  (
    name: 'arcane',
    scene: arcaneScene,
    encounter: 'SP_arcane_01',
    strokeY: 0.84,
  ),
  (name: 'dunes', scene: dunesScene, encounter: 'SP_dunes_01', strokeY: 0.9),
  (name: 'geode', scene: geodeScene, encounter: 'SP_geode_01', strokeY: 0.5),
  (name: 'tidal', scene: tidalScene, encounter: 'SP_tidal_01', strokeY: 0.85),
];

void main() {
  Future<SceneGame> mount(
    WidgetTester tester,
    SceneDefinition scene,
    Size screen,
  ) async {
    tester.view.physicalSize = screen * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final game = SceneGame(scene: scene)..fieldHourOverride = 18.7;
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
    return game;
  }

  _CensusCanvas census(SceneGame game) {
    final c = _CensusCanvas();
    game.render(c);
    return c;
  }

  for (final f in _fields) {
    for (final screen in const [
      Size(751, 475),
      Size(915, 412),
      Size(840, 700),
    ]) {
      testWidgets('${f.name} frame budget at $screen', (tester) async {
        final game = await mount(tester, f.scene, screen);
        var worst = _CensusCanvas();
        // Rest, a gust crossing, panned to the far end, and zoomed in.
        for (final (t, pan) in [(1.5, 0.0), (3.9, 0.0), (6.2, 1e9)]) {
          if (pan > 0) game.debugPanTo(1000 - screen.width);
          for (var i = 0; i < (t * 30).round(); i++) {
            game.update(1 / 30);
          }
          final c = census(game);
          expect(c.blurredDraws, 0);
          if (c.points > worst.points) worst = c;
        }
        // A finger dragged through the grass: it parts, grains fly.
        for (var i = 0; i < 30; i++) {
          game.debugTouch(
            screen.width * (0.3 + i * 0.012),
            screen.height * f.strokeY,
            9,
            0,
          );
          game.update(1 / 60);
        }
        final stirred = census(game);
        expect(stirred.blurredDraws, 0);
        if (stirred.points > worst.points) worst = stirred;
        game.debugFrameEncounter(f.encounter);
        for (var i = 0; i < 90; i++) {
          game.update(1 / 30);
        }
        final zoomed = census(game);
        expect(zoomed.blurredDraws, 0);
        if (zoomed.points > worst.points) worst = zoomed;

        // ignore: avoid_print
        print(
          '${f.name} $screen worst: ${worst.draws} draws, '
          '${worst.points} grains ${worst.counts}',
        );
        expect(worst.draws, lessThan(120));
        expect(worst.points, lessThan(18000));
      });
    }

    testWidgets('${f.name} still parts bake once, not per frame', (
      tester,
    ) async {
      final game = await mount(tester, f.scene, const Size(751, 475));
      final before = census(game).counts['drawImageRect'] ?? 0;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 30);
      }
      final after = census(game);
      // The same sheets, no path drawing of hills or trees per frame.
      expect(after.counts['drawImageRect'] ?? 0, before);
      expect(after.counts['drawPath'] ?? 0, 0);
      // Sanity on raw recording cost (JIT; a ceiling, not a target).
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
        final rec = ui.PictureRecorder();
        game.render(Canvas(rec));
        rec.endRecording().dispose();
      }
      // ignore: avoid_print
      print(
        '${f.name} record: ${(sw.elapsedMicroseconds / 60).round()} '
        'µs/frame (JIT)',
      );
    });
  }

  // The Sky at its busiest: a storm in, lightning at its height, and fingers
  // through the cloud sea, a tower and a fall all at once.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    testWidgets('sky storm and touch budget at $screen', (tester) async {
      final game = await mount(tester, skyScene, screen);
      game
        ..fieldWeather = WeatherKind.storm
        ..debugSettleWeather()
        ..debugPanTo(950);
      for (var i = 0; i < 20; i++) {
        game.update(1 / 30);
        census(game);
      }
      final sky = game.debugField! as SkyField;
      var worst = _CensusCanvas();
      for (final bolt in [true, false]) {
        sky.debugStrike(bolt: bolt);
        for (var i = 0; i < 24; i++) {
          // Taps on the fall, drags through the sea and the tower.
          game
            ..debugTouch(screen.width * 0.495, screen.height * 0.66, 0, 0)
            ..debugTouch(
              screen.width * (0.6 + i * 0.01),
              screen.height * 0.86,
              8,
              0,
            )
            ..debugTouch(
              screen.width * (0.2 + i * 0.005),
              screen.height * 0.4,
              5,
              -2,
            );
          game.update(1 / 30);
          final c = census(game);
          expect(c.blurredDraws, 0);
          if (c.draws > worst.draws) worst = c;
        }
      }
      // ignore: avoid_print
      print(
        'sky storm $screen worst: ${worst.draws} draws, '
        '${worst.points} grains ${worst.counts}',
      );
      expect(worst.draws, lessThan(140));
      expect(worst.points, lessThan(18000));
    });
  }

  // The Swamp gone dry, with a finger raising dust off its floor.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    testWidgets('swamp dry budget at $screen', (tester) async {
      final game = await mount(tester, swampScene, screen);
      game
        ..fieldWeather = WeatherKind.dry
        ..debugSettleWeather();
      var worst = _CensusCanvas();
      for (var i = 0; i < 45; i++) {
        game
          ..debugTouch(
            screen.width * (0.3 + i * 0.008),
            screen.height * 0.92,
            7,
            0,
          )
          ..debugTouch(screen.width * 0.7, screen.height * 0.94, 0, 0);
        game.update(1 / 30);
        final c = census(game);
        expect(c.blurredDraws, 0);
        if (c.draws > worst.draws) worst = c;
      }
      // ignore: avoid_print
      print(
        'swamp dry $screen worst: ${worst.draws} draws, '
        '${worst.points} grains ${worst.counts}',
      );
      expect(worst.draws, lessThan(120));
      expect(worst.points, lessThan(18000));
    });
  }

  // The Volcano at night, with fingers breaking its crust and tapping a
  // river: every break glows and throws sparks.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    testWidgets('volcano lava touch budget at $screen', (tester) async {
      final game = await mount(tester, volcanoScene, screen)
        ..fieldHourOverride = 23;
      var worst = _CensusCanvas();
      for (var i = 0; i < 60; i++) {
        game
          ..debugTouch(
            screen.width * (0.1 + i * 0.006),
            screen.height * 0.93,
            6,
            0,
          )
          ..debugTouch(screen.width * 0.69, screen.height * 0.9, 0, 0);
        game.update(1 / 30);
        final c = census(game);
        expect(c.blurredDraws, 0);
        if (c.draws > worst.draws) worst = c;
      }
      // ignore: avoid_print
      print(
        'volcano lava $screen worst: ${worst.draws} draws, '
        '${worst.points} grains ${worst.counts}',
      );
      expect(worst.draws, lessThan(120));
      expect(worst.points, lessThan(18000));
    });
  }

  // The Volcano smoking, and erupting with its flow all the way across the
  // near field, at night, with fingers on the lava.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    for (final (name, stage, settle) in const [
      ('smoking', 1, 6.0),
      ('erupting', 2, 70.0),
    ]) {
      testWidgets('volcano $name budget at $screen', (tester) async {
        final game = await mount(tester, volcanoScene, screen)
          ..fieldHourOverride = 23
          ..fieldStage = stage;
        // Let the eruption run until its flow has come all the way; the
        // field learns where the camera is from its frames.
        for (var i = 0; i < (settle * 30).round(); i++) {
          game.update(1 / 30);
          if (i % 15 == 0) census(game);
        }
        var worst = _CensusCanvas();
        for (var i = 0; i < 60; i++) {
          game
            ..debugTouch(
              screen.width * (0.1 + i * 0.006),
              screen.height * 0.93,
              6,
              0,
            )
            ..debugTouch(screen.width * 0.69, screen.height * 0.9, 0, 0);
          game.update(1 / 30);
          final c = census(game);
          expect(c.blurredDraws, 0);
          if (c.draws > worst.draws) worst = c;
        }
        // ignore: avoid_print
        print(
          'volcano $name $screen worst: ${worst.draws} draws, '
          '${worst.points} grains ${worst.counts}',
        );
        expect(worst.draws, lessThan(120));
        expect(worst.points, lessThan(18000));
        // Sanity on raw recording cost (JIT; a ceiling, not a target).
        final sw = Stopwatch()..start();
        for (var i = 0; i < 60; i++) {
          game.update(1 / 60);
          final rec = ui.PictureRecorder();
          game.render(Canvas(rec));
          rec.endRecording().dispose();
        }
        // ignore: avoid_print
        print(
          'volcano $name record: ${(sw.elapsedMicroseconds / 60).round()} '
          'µs/frame (JIT)',
        );
      });
    }
  }

  // The Arcane at night — the black hole up, and given back by the glass —
  // with fingers waking the glass and stirring the void's dust.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    testWidgets('arcane glass touch budget at $screen', (tester) async {
      final game = await mount(tester, arcaneScene, screen)
        ..fieldHourOverride = 23;
      var worst = _CensusCanvas();
      for (var i = 0; i < 60; i++) {
        game
          ..debugTouch(
            screen.width * (0.2 + i * 0.008),
            screen.height * 0.86,
            7,
            0,
          )
          ..debugTouch(screen.width * 0.7, screen.height * 0.8, 0, 0)
          ..debugTouch(screen.width * 0.4, screen.height * 0.3, 0, 0);
        game.update(1 / 30);
        final c = census(game);
        expect(c.blurredDraws, 0);
        if (c.draws > worst.draws) worst = c;
      }
      // ignore: avoid_print
      print(
        'arcane glass $screen worst: ${worst.draws} draws, '
        '${worst.points} grains ${worst.counts}',
      );
      expect(worst.draws, lessThan(120));
      expect(worst.points, lessThan(18000));
    });
  }

  // The Arcane under a meteor shower and under the northern lights, at
  // night, with a lone shooting star across it too and fingers on the glass.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    for (final weather in const [WeatherKind.meteors, WeatherKind.aurora]) {
      testWidgets('arcane ${weather.name} budget at $screen', (tester) async {
        final game = await mount(tester, arcaneScene, screen)
          ..fieldHourOverride = 23
          ..fieldWeather = weather
          ..debugSettleWeather();
        // The shower comes as it is drawn: let it get going.
        for (var i = 0; i < 90; i++) {
          game.update(1 / 30);
          census(game);
        }
        (game.debugField! as ArcaneField).debugShootingStar();
        var worst = _CensusCanvas();
        for (var i = 0; i < 90; i++) {
          game
            ..debugTouch(
              screen.width * (0.2 + i * 0.006),
              screen.height * 0.86,
              7,
              0,
            )
            ..debugTouch(screen.width * 0.7, screen.height * 0.8, 0, 0);
          game.update(1 / 30);
          final c = census(game);
          expect(c.blurredDraws, 0);
          if (c.draws > worst.draws) worst = c;
        }
        // ignore: avoid_print
        print(
          'arcane ${weather.name} $screen worst: ${worst.draws} draws, '
          '${worst.points} grains ${worst.counts}',
        );
        expect(worst.draws, lessThan(120));
        expect(worst.points, lessThan(18000));
        // Sanity on raw recording cost (JIT; a ceiling, not a target).
        final sw = Stopwatch()..start();
        for (var i = 0; i < 60; i++) {
          game.update(1 / 60);
          final rec = ui.PictureRecorder();
          game.render(Canvas(rec));
          rec.endRecording().dispose();
        }
        // ignore: avoid_print
        print(
          'arcane ${weather.name} record: '
          '${(sw.elapsedMicroseconds / 60).round()} µs/frame (JIT)',
        );
      });
    }
  }

  // The Valley in rain, and under its rainbow, with a finger in the grass.
  for (final screen in const [Size(751, 475), Size(915, 412)]) {
    for (final (name, weather) in const [
      ('rain', WeatherKind.rain),
      ('snow', WeatherKind.snow),
      ('rainbow', null),
    ]) {
      testWidgets('valley $name budget at $screen', (tester) async {
        final game = await mount(tester, valleySceneCorrected, screen);
        game
          ..fieldWeather = weather
          ..fieldAftermath = weather == null
          ..debugSettleWeather();
        var worst = _CensusCanvas();
        for (var i = 0; i < 45; i++) {
          game.debugTouch(
            screen.width * (0.3 + i * 0.008),
            screen.height * 0.88,
            7,
            0,
          );
          game.update(1 / 30);
          final c = census(game);
          expect(c.blurredDraws, 0);
          if (c.draws > worst.draws) worst = c;
        }
        // ignore: avoid_print
        print(
          'valley $name $screen worst: ${worst.draws} draws, '
          '${worst.points} grains ${worst.counts}',
        );
        expect(worst.draws, lessThan(120));
        expect(worst.points, lessThan(18000));
      });
    }
  }
}
