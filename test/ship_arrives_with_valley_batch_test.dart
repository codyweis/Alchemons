// The ship comes down with the Valley's wild, not ahead of them.
//
// Entering the fourth realm used to land the ship in the Valley at once and
// say so, while the Valley's own wild were still a minute out. The map lit
// the Valley for the ship, and tapping it answered "No creatures detected".
// The fourth visit now only arms the ship; the Valley's next batch brings
// it, so the Valley lights up once, with both in it.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Scene = ({
  SceneDefinition scene,
  EncounterPool sceneWide,
  Map<String, EncounterPool> perSpawn,
});

_Scene _valley() {
  final pools = valleyEncounterPools(valleySceneCorrected);
  return (
    scene: valleySceneCorrected,
    sceneWide: pools.sceneWide,
    perSpawn: pools.perSpawn,
  );
}

_Scene _sky() {
  final pools = skyEncounterPools(skyScene);
  return (
    scene: skyScene,
    sceneWide: pools.sceneWide,
    perSpawn: pools.perSpawn,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Notifications are a platform plugin; here they go nowhere.
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    for (final name in [
      'dexterous.com/flutter/local_notifications',
      'flutter_timezone',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(name),
            (call) async => switch (call.method) {
              'initialize' => true,
              'getActiveNotifications' ||
              'pendingNotificationRequests' => <Object?>[],
              _ => null,
            },
          );
    }
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  late AlchemonsDatabase db;
  late WildernessSpawnService spawns;

  setUp(() async {
    db = AlchemonsDatabase(NativeDatabase.memory());
    final scenes = {'valley': _valley(), 'sky': _sky()};
    spawns = WildernessSpawnService(db);
    await spawns.initializeActiveSpawns(
      scenes: scenes,
      suppressSummaryNotifications: true,
    );
    spawns.startTick(scenes: scenes, interval: const Duration(days: 1));
    await spawns.clearSceneSpawns('valley');
    await spawns.clearSceneSpawns('sky');
  });
  tearDown(() async {
    spawns.dispose();
    await db.close();
  });

  Future<String?> shipScene() =>
      db.settingsDao.getSetting('cosmic_ship_scene');

  test('an armed ship lands with the Valley batch, unannounced', () async {
    await db.settingsDao.setSetting(OpeningWildernessService.shipArmedKey, '1');
    expect(await shipScene(), isNull);

    await spawns.ensureSpawnsForScene('valley');

    expect(spawns.getSceneSpawnCount('valley'), greaterThan(0));
    expect(await shipScene(), 'valley');
    expect(
      await db.settingsDao.getSetting('cosmic_ship_arrival_pending'),
      '1',
    );
    expect(
      await db.settingsDao.getSetting(OpeningWildernessService.shipArmedKey),
      isNull,
    );
  });

  test('another realm\'s batch does not bring it', () async {
    await db.settingsDao.setSetting(OpeningWildernessService.shipArmedKey, '1');

    await spawns.ensureSpawnsForScene('sky');

    expect(await shipScene(), isNull);
    expect(
      await db.settingsDao.getSetting(OpeningWildernessService.shipArmedKey),
      '1',
    );
  });

  test('a Valley batch with no ship owed brings nothing', () async {
    await spawns.ensureSpawnsForScene('valley');
    expect(await shipScene(), isNull);
  });

  test('a claimed ship never comes back', () async {
    await db.settingsDao.setSetting(OpeningWildernessService.shipArmedKey, '1');
    await db.settingsDao.setSetting('cosmic_ship_claimed', '1');

    await spawns.ensureSpawnsForScene('valley');

    expect(await shipScene(), isNull);
  });
}
