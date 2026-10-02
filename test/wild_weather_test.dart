// Weather that comes with a scene's spawns: the Sky's lightning storm, the
// Valley's rain and snow, the Swamp gone dry. A batch that comes with it
// always holds that weather's creatures, standing where they can stand; the
// weather lives and dies with its batch; and the first clear visit after
// the Valley's rain is owed a rainbow.

import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

String _element(String id) => id.substring(3, 5);

typedef _Scene = ({
  SceneDefinition scene,
  EncounterPool sceneWide,
  Map<String, EncounterPool> perSpawn,
});

_Scene _sky() {
  final pools = skyEncounterPools(skyScene);
  return (
    scene: skyScene,
    sceneWide: pools.sceneWide,
    perSpawn: pools.perSpawn,
  );
}

_Scene _valley() {
  final pools = valleyEncounterPools(valleySceneCorrected);
  return (
    scene: valleySceneCorrected,
    sceneWide: pools.sceneWide,
    perSpawn: pools.perSpawn,
  );
}

_Scene _swamp() {
  final pools = swampEncounterPools(swampScene);
  return (
    scene: swampScene,
    sceneWide: pools.sceneWide,
    perSpawn: pools.perSpawn,
  );
}

/// Each weather: its scene, the element it brings, and the scene's tables.
final _weathers = <(String, WildWeather, String, _Scene Function())>[
  ('sky', skyStorm, '07', _sky),
  ('valley', valleyRain, '02', _valley),
  ('valley', valleySnow, '09', _valley),
];

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

  Future<WildernessSpawnService> service(
    AlchemonsDatabase db,
    Map<String, _Scene> scenes,
  ) async {
    final s = WildernessSpawnService(db);
    await s.initializeActiveSpawns(
      scenes: scenes,
      suppressSummaryNotifications: true,
    );
    s.startTick(scenes: scenes, interval: const Duration(days: 1));
    addTearDown(s.dispose);
    return s;
  }

  test('the storm and the rain bring their own family, by name', () {
    expect(skyStorm.pool.entries.map((e) => e.speciesId).toSet(), {
      'LET07',
      'PIP07',
      'MAN07',
      'HOR07',
      'WNG07',
    });
    expect(valleyRain.pool.entries.map((e) => e.speciesId).toSet(), {
      'LET02',
      'PIP02',
      'MAN02',
      'HOR02',
      'WNG02',
    });
    for (final e in skyStorm.pool.entries) {
      expect(speciesCanFloat(e.speciesId), isTrue, reason: e.speciesId);
    }
    // Only the Waterwing can take the Valley's open air.
    expect(
      valleyRain.pool.entries
          .where((e) => speciesCanFloat(e.speciesId))
          .map((e) => e.speciesId),
      ['WNG02'],
    );
    expect(valleyRain.aftermath, isTrue);
    expect(valleySnow.aftermath, isFalse);
    expect(skyStorm.aftermath, isFalse);
  });

  test('a batch with weather always takes at least its guarantee', () {
    var i = 0;
    for (final n in [1, 2, 3, 5]) {
      final picks = skyStorm.pick(n, () => (i++ % 7) / 7);
      expect(picks.length, n);
      expect(
        picks.where((p) => p).length,
        greaterThanOrEqualTo(skyStorm.guaranteed.clamp(0, n)),
      );
    }
  });

  for (final (sceneId, weather, element, tables) in _weathers) {
    final name = '$sceneId ${weather.label.toLowerCase()}';
    test(
      '$name comes with its batch, brings its family, and goes with it',
      () async {
        final db = AlchemonsDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final scenes = {sceneId: tables()};
        final s = await service(db, scenes);
        final scene = scenes[sceneId]!.scene;

        var family = 0, creatures = 0;
        const rounds = 40;
        for (var round = 0; round < rounds; round++) {
          expect(await s.debugBringWeather(sceneId, weather.kind), isTrue);
          expect(s.weatherIn(sceneId), same(weather));
          final ids = s.getActiveSpawnPoints(sceneId);
          final species = [
            for (final id in ids) s.getSpawnAt(sceneId, id)!.speciesId,
          ];
          final ours = species.where((id) => _element(id) == element).length;
          family += ours;
          creatures += species.length;
          // A weather that guarantees its creatures always has one; one that
          // only makes them likelier is checked across the rounds below.
          if (weather.guaranteed > 0) {
            expect(ours, greaterThan(0), reason: '$species');
          }
          // Nothing that cannot float is put in the open air.
          for (final id in ids) {
            final point = scene.spawnPoints.firstWhere((p) => p.id == id);
            if (!point.aloft) continue;
            expect(
              speciesCanFloat(s.getSpawnAt(sceneId, id)!.speciesId),
              isTrue,
              reason: '$id: ${s.getSpawnAt(sceneId, id)!.speciesId}',
            );
          }
          expect(
            await db.settingsDao.getSetting('wild_weather_$sceneId'),
            weather.kind.name,
          );
        }
        // Most of what comes in it is its own: the snow, which guarantees
        // none, makes six creatures in ten its own where they can stand.
        // ignore: avoid_print
        print('$name: $family of $creatures creatures are its own');
        expect(family / creatures, greaterThan(0.4));

        // Survives a restart while its batch does.
        final again = await service(db, scenes);
        expect(again.weatherIn(sceneId), same(weather));

        // Ends once the batch is gone.
        for (final id in again.getActiveSpawnPoints(sceneId)) {
          await again.removeSpawn(sceneId, id);
        }
        expect(again.hasWeather(sceneId), isFalse);
        expect(
          await db.settingsDao.getSetting('wild_weather_$sceneId'),
          isNull,
        );
      },
    );

    test(
      '$name comes with ${(weather.chance * 100).round()}% of batches',
      () async {
        final db = AlchemonsDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final s = await service(db, {sceneId: tables()});
        var times = 0;
        const tries = 400;
        for (var i = 0; i < tries; i++) {
          await s.clearSceneSpawns(sceneId);
          // What a lure does.
          await s.ensureSpawnsForScene(sceneId);
          if (identical(s.weatherIn(sceneId), weather)) times++;
        }
        // ignore: avoid_print
        print('$name: $times / $tries');
        // Seven standard deviations either side: no honest run of luck
        // falls outside it.
        final mean = tries * weather.chance;
        final spread = 7 * math.sqrt(mean * (1 - weather.chance));
        expect(times, inInclusiveRange(mean - spread, mean + spread));
      },
    );
  }

  test('the first clear Valley visit after a rainy one finds a rainbow, '
      'once', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = await service(db, {'valley': _valley()});

    // A clear visit with nothing owed: no rainbow.
    expect(await s.takeAftermath('valley'), isNull);
    expect(s.owesAftermath('valley'), isFalse);

    // A rainy visit: no rainbow yet — it is still raining.
    await s.debugBringWeather('valley');
    await s.noteWeatherVisit('valley');
    expect(s.owesAftermath('valley'), isFalse, reason: 'still raining');
    expect(await s.takeAftermath('valley'), isNull);
    await s.clearSceneSpawns('valley');
    // The rain gone, the map shows the rainbow waiting — after a restart
    // too.
    expect(s.owesAftermath('valley'), isTrue);
    final again = await service(db, {'valley': _valley()});
    expect(again.owesAftermath('valley'), isTrue);

    // Rain again before any clear visit: still owed, not spent.
    await s.debugBringWeather('valley');
    await s.noteWeatherVisit('valley');
    expect(await s.takeAftermath('valley'), isNull);
    await s.clearSceneSpawns('valley');

    // The first clear visit takes it, and only that one.
    await s.ensureSpawnsForScene('valley');
    if (s.hasWeather('valley')) {
      await s.clearSceneSpawns('valley');
      s.debugForceWeather.clear();
    }
    expect(await s.takeAftermath('valley'), same(valleyRain));
    expect(s.owesAftermath('valley'), isFalse);
    expect(await s.takeAftermath('valley'), isNull);
  });

  // ── The Swamp gone dry ───────────────────────────────────────────────────

  test('the dry Swamp is a mix, Dust most of all but not most of it', () {
    final byElement = <String, double>{};
    var total = 0.0;
    for (final e in swampDry.pool.entries) {
      final w = e.rarity.baseWeight * e.weightMul;
      byElement[_element(e.speciesId)] =
          (byElement[_element(e.speciesId)] ?? 0) + w;
      total += w;
    }
    final share = {for (final e in byElement.entries) e.key: e.value / total};
    // ignore: avoid_print
    print('dry Swamp by element: $share');
    final dust = share['10']!;
    expect(dust, inInclusiveRange(0.3, 0.5));
    for (final e in share.entries) {
      if (e.key != '10') expect(e.value, lessThan(dust), reason: e.key);
    }
    for (final el in ['08', '03', '13']) {
      expect(share[el], greaterThan(0.03), reason: el);
    }
    // Water is found only in the last pools.
    expect(share['02'], isNull);
    for (final id in ['SP_swamp_09']) {
      expect(
        swampDry.poolFor(id).entries.map((e) => e.speciesId),
        everyElement(predicate<String>(speciesCanWade)),
        reason: id,
      );
    }
    // Only these can take the marsh pocket's open air.
    expect(
      swampDry.pool.entries
          .where((e) => speciesCanFloat(e.speciesId))
          .map((e) => e.speciesId)
          .toSet(),
      {'LET04', 'WNG10', 'WNG08'},
    );
    // It is the state the Swamp is found in: every creature comes from it.
    expect(swampDry.pick(6, () => 0.999), everyElement(isTrue));
    expect(WeatherKind.dry.settled, isTrue);
    for (final k in [WeatherKind.storm, WeatherKind.rain, WeatherKind.snow]) {
      expect(k.settled, isFalse, reason: '$k');
    }
  });

  test('a dry Swamp batch is all dry Swamp creatures, and goes with its '
      'batch', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final scenes = {'swamp': _swamp()};
    final s = await service(db, scenes);
    final dryIds = swampDry.pool.entries.map((e) => e.speciesId).toSet();
    final seen = <String, int>{};
    var creatures = 0, ponds = 0;
    for (var round = 0; round < 60; round++) {
      expect(await s.debugBringWeather('swamp', WeatherKind.dry), isTrue);
      expect(s.weatherIn('swamp'), same(swampDry));
      for (final id in s.getActiveSpawnPoints('swamp')) {
        final species = s.getSpawnAt('swamp', id)!.speciesId;
        final point = swampScene.spawnPoints.firstWhere((p) => p.id == id);
        expect(
          {...dryIds, ...swampDry.poolFor(id).entries.map((e) => e.speciesId)},
          contains(species),
          reason: '$id: $species',
        );
        expect(point.takes(species), isTrue, reason: '$id: $species');
        // Water wades in the pools, and is found nowhere else.
        expect(
          speciesCanWade(species),
          point.perch == SpawnPerch.wade,
          reason: '$id: $species',
        );
        if (point.perch == SpawnPerch.wade) ponds++;
        seen[_element(species)] = (seen[_element(species)] ?? 0) + 1;
        creatures++;
      }
    }
    // ignore: avoid_print
    print('dry Swamp batches: $seen of $creatures');
    expect(seen.length, greaterThanOrEqualTo(4));
    expect(ponds, greaterThan(0), reason: 'no Waterlet in a pool');
    expect(seen['10']! / creatures, inInclusiveRange(0.2, 0.6));
    expect(await db.settingsDao.getSetting('wild_weather_swamp'), 'dry');

    // Survives a restart while its batch does, and ends with it.
    final again = await service(db, scenes);
    expect(again.weatherIn('swamp'), same(swampDry));
    for (final id in again.getActiveSpawnPoints('swamp')) {
      await again.removeSpawn('swamp', id);
    }
    expect(again.hasWeather('swamp'), isFalse);
  });

  test('the Swamp\'s pools are only there when it has gone dry', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = await service(db, {'swamp': _swamp()});
    final pools = {
      for (final p in swampScene.spawnPoints)
        if (p.onlyIn != null) p.id,
    };
    expect(pools, {'SP_swamp_09'});
    var wet = 0;
    for (var i = 0; i < 200; i++) {
      await s.clearSceneSpawns('swamp');
      await s.ensureSpawnsForScene('swamp');
      if (s.hasWeather('swamp')) continue;
      wet++;
      for (final id in s.getActiveSpawnPoints('swamp')) {
        expect(pools, isNot(contains(id)), reason: 'a pool in a wet batch');
      }
    }
    expect(wet, greaterThan(50));
  });

  test('half the Swamp\'s batches find it dry', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = await service(db, {'swamp': _swamp()});
    var times = 0;
    const tries = 400;
    for (var i = 0; i < tries; i++) {
      await s.clearSceneSpawns('swamp');
      await s.ensureSpawnsForScene('swamp');
      if (identical(s.weatherIn('swamp'), swampDry)) times++;
    }
    // ignore: avoid_print
    print('dry Swamp: $times / $tries');
    final mean = tries * swampDry.chance;
    final spread = 7 * math.sqrt(mean * (1 - swampDry.chance));
    expect(times, inInclusiveRange(mean - spread, mean + spread));
  });
}
