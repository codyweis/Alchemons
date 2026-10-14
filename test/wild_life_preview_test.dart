@Tags(['preview'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/wilderness.dart' show WildEncounter;
import 'package:alchemons/services/encounter_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The wild's Alchemons living in the Valley (wild_life.dart), filmed: they
// stroll, a Lightning one takes off and lands, a finger draws their eyes,
// and the one tapped walks back to its place as the camera comes in.
//
//   WILDLIFE_OUT=/tmp/wildlife flutter test \
//     test/wild_life_preview_test.dart --tags preview
//
// One PNG per frame (WILDLIFE_FPS, default 20) for WILDLIFE_SECONDS
// (default 16); join them with ffmpeg.
void main() {
  final out = Platform.environment['WILDLIFE_OUT'];

  testWidgets('wild life film', (tester) async {
    if (out == null) return;
    final fps = int.tryParse(Platform.environment['WILDLIFE_FPS'] ?? '') ?? 20;
    final seconds =
        double.tryParse(Platform.environment['WILDLIFE_SECONDS'] ?? '') ?? 16;
    const screen = Size(751, 475);
    const scale = 1.5;
    tester.view.physicalSize = screen * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final byId = {
      for (final c in (json['creatures'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: c,
    };

    final game = SceneGame(scene: valleySceneCorrected)
      ..fieldHourOverride = 17.6;
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
    game.wildVisualResolver = (speciesId, rarity) async =>
        Creature.fromJson(byId[speciesId]!);
    final encounters = EncounterService(
      scene: valleySceneCorrected,
      party: const [],
      tableBuilder: (_) => throw UnimplementedError(),
    );
    const cast = {
      'SP_valley_02': 'MAN03',
      'SP_valley_09': 'LET07',
      'SP_valley_12': 'LET03',
      'SP_valley_01': 'WNG04',
    };
    cast.forEach(
      (id, species) => encounters.forceSpawnAt(
        id,
        WildEncounter(
          wildBaseId: species,
          baseBreedChance: 0.1,
          rarity: 'common',
        ),
      ),
    );
    game.attachEncounters(encounters);
    unawaited(game.syncWildFromEncounters());
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      game.update(1 / 60);
    }

    final dt = 1 / fps;
    final frames = (seconds * fps).round();
    for (var f = 0; f < frames; f++) {
      final t = f * dt;
      if (f == (1.0 * fps).round()) {
        game.debugWildTakeOff('SP_valley_09', seconds: 4.5);
      }
      // A finger across the meadow at 7 s: heads turn to it.
      if (t > 7 && t < 7.6) {
        final k = (t - 7) / 0.6;
        game.debugTouch(screen.width * (0.25 + 0.3 * k), screen.height * 0.88,
            screen.width * 0.3 * dt / 0.6, 0);
      }
      // Tapped at 12 s: it goes back to its place as the camera comes in.
      if (f == (12.0 * fps).round()) game.debugFrameEncounter('SP_valley_02');
      if (t < 12) game.debugPanTo(110);
      game.update(dt);
      final rec = ui.PictureRecorder();
      game.render(Canvas(rec)..scale(scale));
      final img = rec.endRecording().toImageSync(
        (screen.width * scale).round(),
        (screen.height * scale).round(),
      );
      await tester.runAsync(() async {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/f_${f.toString().padLeft(4, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      img.dispose();
    }
    await tester.pumpWidget(const SizedBox());
  });
}
