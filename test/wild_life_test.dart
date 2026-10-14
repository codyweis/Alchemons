import 'dart:async';

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/wilderness.dart' show WildEncounter;
import 'package:alchemons/services/encounter_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The wild's Alchemons live in their field (wild_life.dart): they stroll
// their own ground, what can fly takes off and comes down again, and the
// one tapped goes back to its place to be met there.
void main() {
  const meadow = 'SP_valley_02'; // a walker in the meadow
  const flyer = 'SP_valley_06'; // a Lightning Alchemon in the meadow
  const boulder = 'SP_valley_04'; // up on the boulder
  const sky = 'SP_valley_01'; // in the open air

  Future<SceneGame> openValley(WidgetTester tester) async {
    tester.view.physicalSize = const Size(751, 475) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final game = SceneGame(scene: valleySceneCorrected)..fieldHourOverride = 12;
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
    game.wildVisualResolver = (speciesId, rarity) async => Creature(
      id: speciesId,
      name: speciesId,
      types: const ['Earth'],
      rarity: 'Common',
      description: '',
      image: '',
      mutationFamily: 'Let',
    );
    final encounters = EncounterService(
      scene: valleySceneCorrected,
      party: const [],
      tableBuilder: (_) => throw UnimplementedError(),
    );
    const at = {
      meadow: 'MAN03',
      flyer: 'LET07',
      boulder: 'HOR03',
      sky: 'WNG04',
    };
    at.forEach(
      (id, species) => encounters.forceSpawnAt(
        id,
        WildEncounter(wildBaseId: species, baseBreedChance: 0.1, rarity: 'common'),
      ),
    );
    game.attachEncounters(encounters);
    unawaited(game.syncWildFromEncounters());
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      game.update(1 / 60);
    }
    for (final id in at.keys) {
      expect(game.debugWildAt(id)?.isLoaded, isTrue, reason: id);
    }
    return game;
  }

  testWidgets('walkers stroll their ground; a rock keeps its own', (
    tester,
  ) async {
    final game = await openValley(tester);
    var walked = 0.0, onRock = 0.0, lifted = 0.0, hovered = 0.0;
    for (var i = 0; i < 30 * 60; i++) {
      game.update(1 / 30);
      walked = [walked, game.debugWildOffset(meadow)?.dx.abs() ?? 0].reduce(
        (a, b) => a > b ? a : b,
      );
      onRock += game.debugWildOffset(boulder)?.dx.abs() ?? 0;
      for (final id in [meadow, boulder]) {
        lifted += game.debugWildAt(id)!.position.y.abs();
      }
      hovered += game.debugWildOffset(sky)?.dy.abs() ?? 0;
    }
    expect(walked, greaterThan(8), reason: 'it should wander off its spot');
    expect(walked, lessThanOrEqualTo(100 * 1.6 + 1));
    expect(onRock, 0, reason: 'on the boulder it stays put');
    expect(lifted, 0, reason: 'what cannot fly never leaves the ground');
    expect(hovered, greaterThan(0), reason: 'what is in the air bobs');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a Lightning Alchemon takes off and comes down again', (
    tester,
  ) async {
    final game = await openValley(tester);
    game.debugWildTakeOff(flyer, seconds: 3);
    var highest = 0.0;
    for (var i = 0; i < 30 * 3; i++) {
      game.update(1 / 30);
      final y = -game.debugWildAt(flyer)!.position.y;
      if (y > highest) highest = y;
    }
    expect(highest, greaterThan(95 * 0.3), reason: 'it should be up in the air');
    for (var i = 0; i < 30 * 5; i++) {
      game.update(1 / 30);
    }
    expect(game.debugWildAt(flyer)!.position.y, 0, reason: 'landed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the one tapped goes back to its place to be met', (
    tester,
  ) async {
    final game = await openValley(tester);
    final home = game.debugAnchorAt(meadow)!.clone();
    // Let it wander until it is well away, then take it up in the air too:
    // it must come back down and home.
    for (var i = 0; i < 30 * 120; i++) {
      game.update(1 / 30);
      if ((game.debugWildOffset(meadow)?.dx.abs() ?? 0) > 20) break;
    }
    final away = game.debugWildOffset(meadow);
    expect(away, isNotNull);
    game.debugWildTakeOff(flyer);
    for (var i = 0; i < 30; i++) {
      game.update(1 / 30);
    }

    game.debugFrameEncounter(meadow);
    for (var i = 0; i < 30 * 2; i++) {
      game.update(1 / 30);
    }
    expect(game.debugWildOffset(meadow), isNull);
    final anchor = game.debugAnchorAt(meadow)!;
    // In a loop the place is shown in whichever loop is nearest; the same
    // spot of it.
    final period = 2800.0;
    final dx = (anchor.x - home.x) % period;
    expect(dx < 0.5 || dx > period - 0.5, isTrue, reason: '${anchor.x} vs ${home.x}');
    expect(anchor.y, closeTo(home.y, 0.5));

    // Back from the encounter, it lives again.
    game.exitEncounterMode();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    var moved = false;
    for (var i = 0; i < 30 * 60 && !moved; i++) {
      game.update(1 / 30);
      moved = game.debugWildOffset(meadow) != null;
    }
    expect(moved, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
