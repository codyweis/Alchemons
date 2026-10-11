@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/cosmetic_wear.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/owned_cosmetics.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart';
import 'package:alchemons/services/cosmetic_wear_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The Athanor's trails and home ambiences in the real home biome screen, on
// a phone held sideways:
//
//   ATHANOR_SYSTEMS_OUT=docs/athanor/content/systems flutter test -j 1 \
//     test/athanor_home_cosmetics_preview_test.dart --tags preview
//
// writes home_<ambience>_<realm>_<hour>.png (each ambience at its hour and
// at an hour it does not show) and home_trails_<hour>.png (every resident
// wearing a trail, some time after they were left alone). ATHANOR_HOME_ONLY=
// trails,peat_mist,… picks a subset.
void main() {
  final out = Platform.environment['ATHANOR_SYSTEMS_OUT'];

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

  testWidgets('home cosmetics preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final only = Platform.environment['ATHANOR_HOME_ONLY']?.split(',').toSet();
    bool wants(String set) => only == null || only.contains(set);
    const screen = Size(915, 412);
    const dpr = 2.625;
    tester.view.physicalSize = screen * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);

    final json =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final catalog = CreatureCatalog.fromList([
      for (final c in (json['creatures'] as List).cast<Map<String, dynamic>>())
        Creature.fromJson(c),
    ]);
    final db = AlchemonsDatabase(NativeDatabase.memory());
    const roster = [
      ('fire_horn', 'HOR01'),
      ('plant_let', 'LET12'),
      ('water_pip', 'PIP02'),
      ('ice_mane', 'MAN09'),
      ('earth_kin', 'KIN03'),
      ('light_horn', 'HOR16'),
      ('steam_let', 'LET05'),
    ];
    SharedPreferences.setMockInitialValues({});
    final wear = CosmeticWearService(db);
    await tester.runAsync(() async {
      // The Arcane is a home only once it is unlocked in the wild.
      await db.settingsDao.setSetting('arcane_portal_unlocked', '1');
      for (final r in ['dunes', 'geode', 'tidal']) {
        await db.settingsDao.setSetting('scene_unlocked_$r', '1');
      }
      for (final (id, base) in roster) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: base,
          level: 10,
        );
      }
      for (final t in TrailStyle.values) {
        await OwnedCosmetics.grant(db, AthanorPieceKind.trail, t.id);
      }
      for (final a in HomeAmbience.values) {
        await OwnedCosmetics.grant(db, AthanorPieceKind.ambience, a.id);
      }
      await wear.load();
      var k = 0;
      for (final (id, _) in roster) {
        await wear.wearTrail(id, TrailStyle.values[k++ % 2]);
      }
    });

    const household = [
      HomeResident(instanceId: 'fire_horn', x: 0.02),
      HomeResident(instanceId: 'plant_let', x: 0.105, flip: true),
      HomeResident(instanceId: 'water_pip', x: 0.19),
      HomeResident(instanceId: 'ice_mane', x: 0.035, back: true),
      HomeResident(instanceId: 'earth_kin', x: 0.17, back: true, flip: true),
      HomeResident(instanceId: 'light_horn', x: 0.28),
      HomeResident(instanceId: 'steam_let', x: 0.26, back: true),
    ];

    final key = GlobalKey();
    final theme = FactionTheme.scorchForge();

    Future<void> settle(int frames, {int ms = 66}) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 8)),
        );
        await tester.pump(Duration(milliseconds: ms));
      }
    }

    Future<void> shoot(
      String name,
      HomeBiomeLayout layout, {
      double seconds = 3,
    }) async {
      await tester.runAsync(() => layout.save(db.settingsDao));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            Provider<CreatureCatalog>.value(value: catalog),
            ChangeNotifierProvider<CosmeticWearService>.value(value: wear),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child!),
            home: const HomeBiomeScreen(),
          ),
        ),
      );
      await settle(12, ms: 33);
      for (
        var i = 0;
        i < 40 && find.byType(GameWidget<SceneGame>).evaluate().isEmpty;
        i++
      ) {
        await settle(1);
      }
      await settle((seconds * 1000 / 66).round());
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await settle(2);
    }

    final base = HomeBiomeLayout(
      residents: household,
      households: {for (final r in HomeRealm.values) r.name: household},
    );

    Future<void> ambience(HomeAmbience a, HomeRealm realm, double hour) async {
      await tester.runAsync(() async {
        for (final r in HomeRealm.values) {
          await wear.wearAmbience(r.name, a);
        }
      });
      await shoot(
        'home_${a.id}_${realm.name}_${hour.round()}',
        base.copyWith(realm: realm, hour: () => hour),
      );
    }

    for (final (a, realm, hour) in const [
      (HomeAmbience.peatMist, HomeRealm.valley, 23.0),
      (HomeAmbience.peatMist, HomeRealm.valley, 12.0),
      (HomeAmbience.peatMist, HomeRealm.swamp, 23.0),
      (HomeAmbience.moonlitSnowfall, HomeRealm.valley, 23.0),
      (HomeAmbience.moonlitSnowfall, HomeRealm.valley, 12.0),
      (HomeAmbience.moonlitSnowfall, HomeRealm.arcane, 23.0),
      (HomeAmbience.sunMotes, HomeRealm.valley, 12.0),
      (HomeAmbience.sunMotes, HomeRealm.valley, 23.0),
      (HomeAmbience.sunMotes, HomeRealm.dunes, 12.0),
      (HomeAmbience.emberFall, HomeRealm.valley, 18.8),
      (HomeAmbience.emberFall, HomeRealm.valley, 12.0),
      (HomeAmbience.emberFall, HomeRealm.volcano, 18.8),
    ]) {
      if (!wants(a.id)) continue;
      await ambience(a, realm, hour);
    }

    if (wants('trails')) {
      await tester.runAsync(() async {
        for (final r in HomeRealm.values) {
          await wear.wearAmbience(r.name, null);
        }
      });
      for (final (realm, hour) in const [
        // By day: at night they sleep, and leave nothing.
        (HomeRealm.valley, 12.0),
        (HomeRealm.geode, 12.0),
      ]) {
        await shoot(
          'home_trails_${realm.name}_${hour.round()}',
          base.copyWith(realm: realm, hour: () => hour),
          seconds: 14,
        );
      }
    }
  });
}
