// The Volcano's moods: each visit finds the next stage of its cycle —
// quiet twice, smoking twice, then erupting — and round again; the count
// survives a restart; a field without stages is always found in its
// first; and the field takes the stage it is given.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/field/grain_field.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
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

Map<String, _Scene> _scenes() {
  final volcano = volcanoEncounterPools(volcanoScene);
  final swamp = swampEncounterPools(swampScene);
  return {
    'volcano': (
      scene: volcanoScene,
      sceneWide: volcano.sceneWide,
      perSpawn: volcano.perSpawn,
    ),
    'swamp': (
      scene: swampScene,
      sceneWide: swamp.sceneWide,
      perSpawn: swamp.perSpawn,
    ),
  };
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

  Future<WildernessSpawnService> service(AlchemonsDatabase db) async {
    final s = WildernessSpawnService(db);
    await s.initializeActiveSpawns(
      scenes: _scenes(),
      suppressSummaryNotifications: true,
    );
    addTearDown(s.dispose);
    return s;
  }

  test('the Volcano is quiet twice, smokes twice, then erupts', () {
    expect(volcanoScene.stages, [
      VolcanoField.still,
      VolcanoField.still,
      VolcanoField.smoking,
      VolcanoField.smoking,
      VolcanoField.erupting,
    ]);
  });

  test('each visit finds the next stage, round and round', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = await service(db);
    final seen = <int>[];
    for (var i = 0; i < 11; i++) {
      seen.add(s.fieldStageFor('volcano', volcanoScene));
      await s.noteFieldVisit('volcano');
    }
    const still = VolcanoField.still, smoking = VolcanoField.smoking;
    const erupting = VolcanoField.erupting;
    expect(seen, [
      still, still, smoking, smoking, erupting, //
      still, still, smoking, smoking, erupting,
      still,
    ]);
  });

  test('the count survives a restart', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final first = await service(db);
    for (var i = 0; i < 3; i++) {
      await first.noteFieldVisit('volcano');
    }
    expect(first.fieldStageFor('volcano', volcanoScene), VolcanoField.smoking);
    final again = await service(db);
    expect(again.fieldStageFor('volcano', volcanoScene), VolcanoField.smoking);
    await again.noteFieldVisit('volcano');
    expect(again.fieldStageFor('volcano', volcanoScene), VolcanoField.erupting);
  });

  test('a field without stages is always found in its first', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = await service(db);
    expect(swampScene.stages, isEmpty);
    for (var i = 0; i < 4; i++) {
      expect(s.fieldStageFor('swamp', swampScene), 0);
      await s.noteFieldVisit('swamp');
    }
  });

  test('the debug tools move the cycle on a stage', () async {
    final db = AlchemonsDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final s = await service(db);
    for (final want in [
      VolcanoField.still,
      VolcanoField.smoking,
      VolcanoField.smoking,
      VolcanoField.erupting,
      VolcanoField.still,
    ]) {
      expect(await s.debugAdvanceFieldStage('volcano', volcanoScene), want);
    }
  });
}
