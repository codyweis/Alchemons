// The Arcane's sky over time: on an ordinary visit a shooting star comes
// about once a minute — none in the first moments, so only someone who
// stays sees one — and a meteor shower keeps a few in the sky at once.

import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/arcane/arcane_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(751, 475);

  Future<SceneGame> mount(WidgetTester tester, {WeatherKind? weather}) async {
    tester.view.physicalSize = screen * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final game = SceneGame(scene: arcaneScene)
      ..fieldHourOverride = 23
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
    game
      ..update(0)
      ..debugSettleWeather();
    return game;
  }

  // The sky is stepped as it is drawn, as on the phone.
  void frame(SceneGame game, double dt) {
    game.update(dt);
    final rec = ui.PictureRecorder();
    game.render(Canvas(rec));
    rec.endRecording().dispose();
  }

  testWidgets('a shooting star comes about once a minute, and not at once', (
    tester,
  ) async {
    final game = await mount(tester);
    final field = game.debugField! as ArcaneField;
    const dt = 1 / 10;
    final starts = <double>[];
    var was = 0;
    for (var t = 0.0; t < 600; t += dt) {
      frame(game, dt);
      final now = field.debugMeteors;
      if (now > was) starts.add(t);
      was = now;
    }
    // ignore: avoid_print
    print('shooting stars in ten minutes at ${starts.map((t) => t.round())}');
    expect(starts.first, greaterThan(24));
    expect(starts.length, inInclusiveRange(7, 14));
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i] - starts[i - 1], inInclusiveRange(34, 86));
    }
  });

  testWidgets('a meteor shower keeps a few meteors in the sky at once', (
    tester,
  ) async {
    final game = await mount(tester, weather: WeatherKind.meteors);
    final field = game.debugField! as ArcaneField;
    const dt = 1 / 30;
    var t = 0.0, seen = 0, frames = 0;
    for (var i = 0; i < 30 * 20; i++) {
      frame(game, dt);
      t += dt;
      if (t < 2) continue;
      seen += field.debugMeteorsInView(t, screen);
      frames++;
    }
    final mean = seen / frames;
    // ignore: avoid_print
    print('meteor shower: ${mean.toStringAsFixed(2)} in view on average');
    expect(mean, greaterThan(1.5));
    expect(mean, lessThan(8));
  });
}
