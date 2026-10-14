import 'dart:async';

import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/wilderness.dart' show WildEncounter;
import 'package:alchemons/services/encounter_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A wild that steps aside while another is engaged comes back as itself.
// Closing a won encounter syncs the field twice in one frame (the page's
// _removeTransientSpawn / _exitEncounter / _syncSpawnsFromService), and the
// second sync used to take the just-restored wild — not mounted until the
// next tick — for missing and roll a new creature over it: a prismatic
// beside the one you fused came back plain.
void main() {
  const engaged = 'SP_valley_01';
  const aside = 'SP_valley_02';

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
    game.update(1 / 60);
    return game;
  }

  Future<void> settle(WidgetTester tester, SceneGame game) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      game.update(1 / 60);
    }
  }

  testWidgets('a prismatic beside a won encounter comes back prismatic', (
    tester,
  ) async {
    final game = await openValley(tester);

    // Every roll is a new creature; only the first one at [aside] shines.
    var rolls = 0;
    game.wildVisualResolver = (speciesId, rarity) async {
      rolls++;
      return Creature(
        id: speciesId,
        name: speciesId,
        types: const ['Fire'],
        rarity: 'Common',
        description: '',
        image: '',
        mutationFamily: 'Let',
        isPrismaticSkin: speciesId == 'CR002' && rolls <= 2,
      );
    };

    final encounters = EncounterService(
      scene: valleySceneCorrected,
      party: const [],
      tableBuilder: (_) => throw UnimplementedError(),
    );
    void spawn(Map<String, String> bySpawn) {
      encounters.clearSpawns();
      bySpawn.forEach(
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
    }

    spawn({engaged: 'CR001', aside: 'CR002'});
    await settle(tester, game);
    expect(rolls, 2);
    final shining = game.debugWildAt(aside)!.hydrated!;
    expect(shining.isPrismaticSkin, isTrue);

    // Tap the other one: the prismatic steps off the field.
    game.debugFrameEncounter(engaged);
    expect(game.debugWildAt(aside), isNull);

    // The fusion lands and the encounter closes, as ScenePage closes it.
    game.clearWildAt(engaged);
    spawn({aside: 'CR002'}); // _removeTransientSpawn
    game.exitEncounterMode(); // _exitEncounter
    game.clearWildAt(engaged);
    spawn({aside: 'CR002'}); // _syncSpawnsFromService
    await settle(tester, game);

    expect(rolls, 2, reason: 'nothing on the field should be rolled again');
    final back = game.debugWildAt(aside)!;
    expect(back.isMounted, isTrue);
    expect(back.hydrated, same(shining));
    expect(back.hydrated!.isPrismaticSkin, isTrue);
  });
}
