@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/games/wilderness/ship_landing.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The cosmic ship coming down in the Valley, as stills over the real field:
// the glide with its wake, the flare, the touchdown, at rest, and the
// lift-off after the claim. One PNG per moment plus a contact sheet.
//
//   SHIP_OUT=/tmp/ship flutter test test/ship_landing_preview_test.dart \
//     --tags preview
//
// SHIP_HOUR sets the hour (default 11; try 18.6 for dusk, 23 for night).
void main() {
  final out = Platform.environment['SHIP_OUT'];

  testWidgets('ship landing preview', (tester) async {
    if (out == null) return;
    const screen = Size(751, 475);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);
    final hour = double.tryParse(Platform.environment['SHIP_HOUR'] ?? '') ?? 11;

    final game = SceneGame(scene: valleySceneCorrected)
      ..fieldHourOverride = hour;
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
    const dt = 1 / 60;
    for (var i = 0; i < 30; i++) {
      game.update(dt);
    }

    game.placeShipBeaconAt('SP_valley_06', onTap: () {}, flyIn: true);

    final shots = <(String, ui.Image)>[];
    void shoot(String name) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      game.render(c);
      shots.add((
        name,
        rec.endRecording().toImageSync(
          screen.width.round(),
          screen.height.round(),
        ),
      ));
    }

    var clock = 0.0;
    void runTo(double t) {
      while (clock < t - 1e-9) {
        game.update(dt);
        clock += dt;
      }
    }

    const lead = ShipLandingComponent.leadIn;
    const fall = ShipLandingComponent.descentTime;
    final moments = <String, double>{
      'a_glide_early': lead + fall * 0.22,
      'b_glide': lead + fall * 0.45,
      'c_flare': lead + fall * 0.72,
      'd_final': lead + fall * 0.92,
      'e_impact': lead + fall + 0.08,
      'f_impact_settle': lead + fall + 0.45,
      'g_settled': lead + fall + 1.4,
      'h_idle': lead + fall + 5.0,
    };
    for (final MapEntry(key: name, value: t) in moments.entries) {
      runTo(t);
      shoot(name);
    }

    final ship = game.debugShipBeacon!;
    expect(ship.landed, isTrue);
    var goneCalled = false;
    game.launchShipBeacon(onGone: () => goneCalled = true);
    final launchAt = clock;
    for (final MapEntry(key: name, value: t) in {
      'i_lift_spool': 0.4,
      'j_lift_rise': 0.95,
      'k_lift_climb': 1.4,
      'l_lift_away': 1.9,
      'm_lift_wake': 2.6,
    }.entries) {
      runTo(launchAt + t);
      shoot(name);
    }
    runTo(launchAt + 5);
    expect(goneCalled, isTrue);
    expect(game.debugShipBeacon, isNull);

    await tester.pumpWidget(const SizedBox());

    await tester.runAsync(() async {
      final suffix = hour == 11 ? '' : '_h${hour.toString()}';
      for (final (name, image) in shots) {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/ship${suffix}_$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      }
      const cols = 3;
      const s = 0.5;
      final w = screen.width * s, h = screen.height * s;
      final rows = (shots.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < shots.length; i++) {
        c.save();
        c.translate((i % cols) * w, (i ~/ cols) * h);
        c.scale(s);
        c.drawImage(shots[i].$2, Offset.zero, Paint());
        c.restore();
      }
      final sheet = rec.endRecording().toImageSync(
        (w * cols).round(),
        (h * rows).round(),
      );
      final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$out/ship${suffix}_sheet.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
