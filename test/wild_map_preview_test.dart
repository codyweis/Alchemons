@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/sky/sky_scene.dart';
import 'package:alchemons/models/scenes/swamp/swamp_scene.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/models/scenes/volcano/volcano_scene.dart';
import 'package:alchemons/screens/map_screen.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/wilderness/wild_map.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The wild map: the field on its own (at rest, a finger through it, each
// weather, realms with something waiting, Arcane open), and the real map
// screen around it in the dark theme and the light.
//
//   WILDMAP_OUT=/tmp/wildmap flutter test test/wild_map_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['WILDMAP_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont(
      'monospace',
      '/System/Library/Fonts/Supplemental/Andale Mono.ttf',
    );
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  testWidgets('wild map field preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const size = Size(390, 600);
    const scale = 2.0;

    final sheet = <ui.Image>[];
    Future<void> save(String name, ui.Image img) async {
      sheet.add(img);
      await tester.runAsync(() async {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    ui.Image shoot(WildMapField f) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..color = f.ink ? const Color(0xFFF7F4EE) : const Color(0xFF07070A),
      );
      f.paint(c);
      return rec.endRecording().toImageSync(
        (size.width * scale).round(),
        (size.height * scale).round(),
      );
    }

    WildMapField fresh({
      Map<String, WeatherKind> weather = const {},
      Set<String> ready = const {},
      bool arcane = false,
      WildVolcano volcano = WildVolcano.still,
      bool rainbow = false,
    }) {
      final f = WildMapField()
        ..weather = weather
        ..ready = ready
        ..arcane = arcane
        ..volcano = volcano
        ..rainbow = rainbow
        ..layout(size)
        ..settle();
      for (var i = 0; i < 90; i++) {
        f.step(1 / 60);
      }
      return f;
    }

    final sw = Stopwatch()..start();
    final rest = fresh();
    sw.stop();
    await save('1_rest', shoot(rest));

    // A finger drawn across the Valley and on into the Sky.
    final stir = fresh();
    const from = Offset(40, 150), to = Offset(330, 190);
    for (var i = 0; i <= 24; i++) {
      final p = Offset.lerp(from, to, i / 24)!;
      stir
        ..stir(p, (to - from) / 24, 1 / 60)
        ..step(1 / 60);
    }
    await save('2_stir', shoot(stir));
    for (var i = 0; i < 30; i++) {
      stir.step(1 / 60);
    }
    await save('3_settling', shoot(stir));

    final storm = fresh(weather: {'sky': WeatherKind.storm})..debugStrike();
    for (var i = 0; i < 3; i++) {
      storm.step(1 / 60);
    }
    await save('4_storm', shoot(storm));
    await save('5_rain', shoot(fresh(weather: {'valley': WeatherKind.rain})));
    await save('6_snow', shoot(fresh(weather: {'valley': WeatherKind.snow})));
    await save('7_dry', shoot(fresh(weather: {'swamp': WeatherKind.dry})));
    await save(
      '8_ready_arcane',
      shoot(fresh(ready: {'valley', 'volcano', 'arcane'}, arcane: true)),
    );
    // A storm between strikes: lit only from inside the cloud.
    final between = fresh(weather: {'sky': WeatherKind.storm});
    for (var i = 0; i < 400; i++) {
      between.step(1 / 60);
      if (between.debugFlickering && !between.debugStriking) break;
    }
    await save('9_storm_flicker', shoot(between));
    await save('10_rainbow', shoot(fresh(rainbow: true)));
    await save(
      '11_volcano_smoking',
      shoot(fresh(volcano: WildVolcano.smoking)),
    );
    await save(
      '12_volcano_erupting',
      shoot(fresh(volcano: WildVolcano.erupting)),
    );
    await save(
      '13_arcane_meteors',
      shoot(fresh(weather: {'arcane': WeatherKind.meteors}, arcane: true)),
    );
    await save(
      '14_arcane_aurora',
      shoot(fresh(weather: {'arcane': WeatherKind.aurora}, arcane: true)),
    );
    // The map opening with something waiting everywhere: dust, the realms
    // on their way, their shapes.
    final gather = WildMapField()
      ..ready = const {'valley', 'sky', 'volcano', 'swamp'}
      ..layout(size)
      ..settle(gather: true);
    for (final (name, until) in [
      ('15_gather_dust', 0.3),
      ('16_gather_quarter', 0.8),
      ('17_gather_half', 1.25),
      ('18_gather_three_quarters', 1.7),
      ('19_gathered', 2.4),
    ]) {
      while (gather.time < until) {
        gather.step(1 / 60);
      }
      await save(name, shoot(gather));
    }

    // WILDMAP_FRAMES=dir: the same at 30 frames a second, the dust
    // drifting a while first, for a clip.
    final frames = Platform.environment['WILDMAP_FRAMES'];
    if (frames != null) {
      Directory(frames).createSync(recursive: true);
      final clip = WildMapField()
        ..ready = const {}
        ..layout(size)
        ..settle(gather: true);
      for (var i = 0; i < 30 * 6; i++) {
        // Two seconds of dust, then the Valley and the Volcano are called.
        if (i == 60) clip.ready = const {'valley', 'volcano'};
        clip
          ..step(1 / 60)
          ..step(1 / 60);
        final img = shoot(clip);
        await tester.runAsync(() async {
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$frames/f_${i.toString().padLeft(4, '0')}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
        img.dispose();
      }
    }

    // The same states in ink, for the light theme.
    await save(
      'ink_1_storm_snow_dry_erupting',
      shoot(
        fresh(
            weather: {
              'sky': WeatherKind.storm,
              'valley': WeatherKind.snow,
              'swamp': WeatherKind.dry,
            },
            volcano: WildVolcano.erupting,
          )
          ..ink = true
          ..debugStrike()
          ..step(1 / 60),
      ),
    );
    await save(
      'ink_2_rain_smoking',
      shoot(
        fresh(
          weather: {'valley': WeatherKind.rain},
          volcano: WildVolcano.smoking,
        )..ink = true,
      ),
    );
    await save(
      'ink_3_rainbow_still_aurora',
      shoot(
        fresh(
          rainbow: true,
          arcane: true,
          ready: {'arcane'},
          weather: {'arcane': WeatherKind.aurora},
        )..ink = true,
      ),
    );
    await save(
      'ink_4_meteors',
      shoot(
        fresh(arcane: true, weather: {'arcane': WeatherKind.meteors})
          ..ink = true,
      ),
    );

    // Every frame on one sheet, four to a row.
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < sheet.length; i++) {
        final img = sheet[i];
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(
            (i % 4) * size.width,
            (i ~/ 4) * size.height,
            size.width,
            size.height,
          ),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
      final img = rec.endRecording().toImageSync(
        (size.width * 4).round(),
        (size.height * ((sheet.length + 3) ~/ 4)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/sheet.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    // Cost: recording a frame at rest, and with a finger through it.
    var t0 = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      rest.step(1 / 60);
      final rec = ui.PictureRecorder();
      rest.paint(Canvas(rec));
      rec.endRecording().dispose();
    }
    final restUs = t0.elapsedMicroseconds / 60;
    t0 = Stopwatch()..start();
    for (var i = 0; i < 60; i++) {
      final p = Offset.lerp(from, to, (i % 24) / 24)!;
      rest
        ..stir(p, (to - from) / 24, 1 / 60)
        ..step(1 / 60);
      final rec = ui.PictureRecorder();
      rest.paint(Canvas(rec));
      rec.endRecording().dispose();
    }
    final stirUs = t0.elapsedMicroseconds / 60;
    // And at rest with every realm showing a state at once.
    final busy = fresh(
      weather: {
        'sky': WeatherKind.storm,
        'valley': WeatherKind.rain,
        'swamp': WeatherKind.dry,
      },
      volcano: WildVolcano.erupting,
    );
    t0 = Stopwatch()..start();
    for (var i = 0; i < 120; i++) {
      busy.step(1 / 60);
      final rec = ui.PictureRecorder();
      busy.paint(Canvas(rec));
      rec.endRecording().dispose();
    }
    final busyUs = t0.elapsedMicroseconds / 120;
    // ignore: avoid_print
    print(
      'built in ${sw.elapsedMilliseconds} ms; ${rest.debugGrains} grains; '
      '${restUs.round()} µs/frame at rest, ${stirUs.round()} µs stirred, '
      '${busyUs.round()} µs with every realm showing a state',
    );
  });

  // Notifications are a platform plugin; here they go nowhere.
  void quietNotifications() {
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
  }

  for (final (name, theme) in [
    ('dark', FactionTheme.scorchForge()),
    ('light', factionThemeFor(null, brightness: Brightness.light)),
  ]) {
    testWidgets('wild map screen preview ($name)', (tester) async {
      if (out == null) return;
      quietNotifications();
      Directory(out).createSync(recursive: true);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      late WildernessSpawnService spawns;
      late ConstellationEffectsService constellations;
      await tester.runAsync(() async {
        final scenes =
            <
              String,
              ({
                SceneDefinition scene,
                EncounterPool sceneWide,
                Map<String, EncounterPool> perSpawn,
              })
            >{
              'valley': (
                scene: valleySceneCorrected,
                sceneWide: valleyEncounterPools(valleySceneCorrected).sceneWide,
                perSpawn: valleyEncounterPools(valleySceneCorrected).perSpawn,
              ),
              'sky': (
                scene: skyScene,
                sceneWide: skyEncounterPools(skyScene).sceneWide,
                perSpawn: skyEncounterPools(skyScene).perSpawn,
              ),
              'volcano': (
                scene: volcanoScene,
                sceneWide: volcanoEncounterPools(volcanoScene).sceneWide,
                perSpawn: volcanoEncounterPools(volcanoScene).perSpawn,
              ),
              'swamp': (
                scene: swampScene,
                sceneWide: swampEncounterPools(swampScene).sceneWide,
                perSpawn: swampEncounterPools(swampScene).perSpawn,
              ),
            };
        spawns = WildernessSpawnService(db);
        await spawns.initializeActiveSpawns(
          scenes: scenes,
          suppressSummaryNotifications: true,
        );
        constellations = ConstellationEffectsService(db);
        // Arcane open, so its circle shows.
        await db.settingsDao.setSetting('arcane_portal_unlocked', '1');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      addTearDown(spawns.dispose);

      final key = GlobalKey();
      Future<void> shoot(String shot) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$out/screen_${name}_$shot.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> settle([int frames = 8]) async {
        for (var i = 0; i < frames; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 33));
        }
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            ChangeNotifierProvider<WildernessSpawnService>.value(value: spawns),
            ChangeNotifierProvider<ConstellationEffectsService>.value(
              value: constellations,
            ),
            ChangeNotifierProvider<FactionService>(
              create: (_) => FactionService(db),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.brightness == Brightness.light
                ? ThemeData.light()
                : ThemeData.dark(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: const MapScreen(),
          ),
        ),
      );
      await settle(24);
      await shoot('1_open');

      // A finger through the Valley, caught mid-stroke.
      final g = await tester.startGesture(const Offset(30, 250));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset(30 + i * 26.0, 250 + i * 4.0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await shoot('2_stir');
      await g.up();
      await settle(4);

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // Cleared in the body: a widget test checks it before tear-down.
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
