@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The home biome on a phone held sideways, through the real screen: the
// player's own Alchemons standing in each of the five realms, each realm in
// its own weather, and arranging — with one of them chosen.
//
//   HOME_BIOME_OUT=/tmp/home_biome flutter test \
//     test/home_biome_preview_test.dart --tags preview
//
// HOME_BIOME_SIZE=915x412 picks the screen (logical px), HOME_BIOME_ONLY=
// valley,sky,… a subset of the sets (valley, sky, swamp, volcano, arcane,
// weather, arrange, moved).
void main() {
  final out = Platform.environment['HOME_BIOME_OUT'];

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

  testWidgets('home biome preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final dims = (Platform.environment['HOME_BIOME_SIZE'] ?? '915x412')
        .split('x')
        .map(double.parse)
        .toList();
    final screen = Size(dims[0], dims[1]);
    final only = Platform.environment['HOME_BIOME_ONLY']?.split(',').toSet();
    bool wants(String set) => only == null || only.contains(set);
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
    // A household: horns, a mane, a let, a pip, a kin — and two that fly.
    const roster = [
      ('fire_horn', 'HOR01'),
      ('plant_let', 'LET12'),
      ('water_pip', 'PIP02'),
      ('ice_mane', 'MAN09'),
      ('earth_kin', 'KIN03'),
      ('air_wing', 'WNG04'),
      ('light_horn', 'HOR16'),
      ('steam_let', 'LET05'),
    ];
    await tester.runAsync(() async {
      for (final (id, base) in roster) {
        await db.creatureDao.insertInstance(
          instanceId: id,
          baseId: base,
          level: 10,
        );
      }
    });

    const household = [
      HomeResident(instanceId: 'fire_horn', x: 0.02),
      HomeResident(instanceId: 'plant_let', x: 0.105, flip: true),
      HomeResident(instanceId: 'water_pip', x: 0.19),
      HomeResident(instanceId: 'ice_mane', x: 0.035, back: true),
      HomeResident(instanceId: 'earth_kin', x: 0.17, back: true, flip: true),
      HomeResident(instanceId: 'air_wing', x: 0.13, lift: 0.3),
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

    SceneGame game() => tester
        .widget<GameWidget<SceneGame>>(find.byType(GameWidget<SceneGame>))
        .game!;

    Future<void> shoot(
      String name,
      HomeBiomeLayout layout, {
      double seconds = 2.5,
      Future<void> Function()? then,
    }) async {
      await tester.runAsync(() => layout.save(db.settingsDao));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AlchemonsDatabase>.value(value: db),
            Provider<FactionTheme>.value(value: theme),
            Provider<CreatureCatalog>.value(value: catalog),
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
      // The layout, the instances, the field, the sprites.
      await settle(12, ms: 33);
      for (
        var i = 0;
        i < 40 && find.byType(GameWidget<SceneGame>).evaluate().isEmpty;
        i++
      ) {
        await settle(1);
      }
      await settle((seconds * 1000 / 66).round());
      if (then != null) {
        await then();
        await settle(14);
      }
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

    const base = HomeBiomeLayout(hour: 18.8, residents: household);
    for (final realm in HomeRealm.values) {
      if (!wants(realm.name)) continue;
      await shoot(realm.name, base.copyWith(realm: realm));
    }
    if (wants('weather')) {
      for (final (realm, mood, hour) in const [
        (HomeRealm.valley, 'rain', 14.0),
        (HomeRealm.valley, 'snow', 11.0),
        (HomeRealm.valley, 'rainbow', 16.5),
        (HomeRealm.sky, 'storm', 15.0),
        (HomeRealm.swamp, 'dry', 12.0),
        (HomeRealm.volcano, 'erupting', 23.0),
        (HomeRealm.arcane, 'meteors', 23.0),
        (HomeRealm.arcane, 'aurora', 23.0),
      ]) {
        await shoot(
          'wx_${realm.name}_$mood',
          base.copyWith(realm: realm, hour: () => hour).withMood(mood),
          seconds: mood == 'rainbow' ? 6 : 3.5,
        );
      }
    }
    if (wants('arrange')) {
      for (final realm in const [HomeRealm.valley, HomeRealm.sky]) {
        await shoot(
          'arrange_${realm.name}',
          base.copyWith(realm: realm),
          then: () async {
            await tester.tap(find.text('Arrange'));
            await settle(4);
            game().onResidentTap!('HOME_air_wing');
          },
        );
      }
    }
    if (wants('moved')) {
      // The Volcano after its fire horn is carried right of the light horn:
      // its shelf goes with it.
      await shoot(
        'moved_volcano',
        base.copyWith(realm: HomeRealm.volcano),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(2);
          game().onResidentDropped!('HOME_fire_horn', 0.36, 0.7);
        },
      );
    }
    await tester.runAsync(db.close);
  });
}
