import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A creature summoned into a wild encounter gathers out of grains and then
// stands still. It used to throb to twice its size: it was hidden by scale
// while its grains were read, and the tap-me pulse (a scale effect, which
// measures from the scale it starts at) began from nothing.
void main() {
  testWidgets('a summoned partner settles at its own size', (tester) async {
    tester.view.physicalSize = const Size(751, 475) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

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
    final game = SceneGame(scene: valleySceneCorrected)..fieldHourOverride = 12;
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 751, height: 475, child: GameWidget(game: game)),
      ),
    );
    for (var i = 0; i < 40 && !game.isLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    game.debugFrameEncounter('SP_valley_02');
    game.update(1 / 30);
    game.spawnPartyCreature(party);

    final scales = <double>[];
    for (var i = 0; i < 150; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      game.update(1 / 30);
      final c = game.debugPartyCreature!;
      if (i > 60) scales.add(c.scale.x);
      expect(c.veiled, i > 60 ? isFalse : anything);
    }
    final lo = scales.reduce((a, b) => a < b ? a : b);
    final hi = scales.reduce((a, b) => a > b ? a : b);
    expect(lo, closeTo(1, 1e-6));
    expect(hi, closeTo(1, 1e-6));
    await tester.pumpWidget(const SizedBox());
  });
}
