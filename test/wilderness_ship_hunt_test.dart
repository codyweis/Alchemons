// The opening walks you round the map one region at a time.
//
// Recovering the ship needs all four core biomes visited, and nothing used to
// push the player out of the two the tutorial already showed them. Opening
// the remaining two together fixed that but left a fork: two unfamiliar
// regions and nothing to choose on. The hunt now points at exactly one, and
// arriving there opens the next.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;

  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Runs the opening the way a player does, ending where the tutorial ends.
  Future<List<String>> finishTutorial(FactionId faction) async {
    final settings = db.settingsDao;
    await OpeningWildernessService.activateForFaction(settings, faction);
    final first = OpeningWildernessService.primarySceneForFaction(faction);
    await OpeningWildernessService.advanceToCaptureTutorial(
      settings,
      firstScene: first,
    );
    await OpeningWildernessService.completeCaptureTutorial(settings);
    return OpeningWildernessService.shipHuntScenes(settings);
  }

  for (final faction in FactionId.values) {
    test('${faction.name}: the hunt is the two the tutorial skipped', () async {
      final hunt = await finishTutorial(faction);
      final walked = OpeningWildernessService.openingScenesForFaction(faction);

      expect(hunt.length, 2, reason: 'four core biomes, two already walked');
      expect(hunt.toSet().intersection(walked), isEmpty);
      expect(
        {...hunt, ...walked},
        OpeningWildernessService.coreScenes,
        reason: 'between them they must cover the map',
      );
    });

    test('${faction.name}: exactly one is open, and it is the head', () async {
      final hunt = await finishTutorial(faction);
      final settings = db.settingsDao;

      expect(
        await OpeningWildernessService.openShipHuntScene(settings),
        hunt.first,
      );
      expect(
        await OpeningWildernessService.isSceneAllowed(settings, hunt.first),
        isTrue,
      );
      expect(
        await OpeningWildernessService.isSceneAllowed(settings, hunt.last),
        isFalse,
        reason: 'the second one waits its turn',
      );
      expect(
        await OpeningWildernessService.isHeldForShipHunt(settings, hunt.last),
        isTrue,
        reason: 'held, not empty — a lure must not be offered for it',
      );
    });

    test('${faction.name}: arriving opens the next, then the map', () async {
      final hunt = await finishTutorial(faction);
      final settings = db.settingsDao;

      await OpeningWildernessService.markSceneVisited(settings, hunt.first);
      expect(
        await OpeningWildernessService.openShipHuntScene(settings),
        hunt.last,
      );
      expect(
        await OpeningWildernessService.isSceneAllowed(settings, hunt.first),
        isFalse,
        reason: 'the hunt has moved on; it reopens when the hunt ends',
      );

      await OpeningWildernessService.markSceneVisited(settings, hunt.last);
      expect(await OpeningWildernessService.openShipHuntScene(settings), isNull);
      for (final scene in OpeningWildernessService.coreScenes) {
        expect(
          await OpeningWildernessService.isSceneAllowed(settings, scene),
          isTrue,
          reason: '$scene should be open once all four have been walked',
        );
        expect(
          await OpeningWildernessService.isHeldForShipHunt(settings, scene),
          isFalse,
        );
      }
    });
  }

  test('visiting the wrong biome does not advance the hunt', () async {
    final hunt = await finishTutorial(FactionId.volcanic);
    final settings = db.settingsDao;

    await OpeningWildernessService.markSceneVisited(settings, hunt.last);
    await OpeningWildernessService.markSceneVisited(settings, 'arcane');
    expect(
      await OpeningWildernessService.openShipHuntScene(settings),
      hunt.first,
      reason: 'only the region the hunt points at moves it along',
    );
  });

  test('finding the ship ends the hunt outright', () async {
    await finishTutorial(FactionId.earthen);
    final settings = db.settingsDao;

    await settings.setSetting(OpeningWildernessService.shipUnlockedKey, '1');
    expect(await OpeningWildernessService.shipHuntScenes(settings), isEmpty);
    for (final scene in OpeningWildernessService.coreScenes) {
      expect(
        await OpeningWildernessService.isSceneAllowed(settings, scene),
        isTrue,
      );
    }
  });

  test('a save with no marker is never gated', () async {
    final settings = db.settingsDao;
    for (final scene in OpeningWildernessService.coreScenes) {
      expect(
        await OpeningWildernessService.isSceneAllowed(settings, scene),
        isTrue,
      );
      expect(
        await OpeningWildernessService.isHeldForShipHunt(settings, scene),
        isFalse,
      );
    }
  });
}
