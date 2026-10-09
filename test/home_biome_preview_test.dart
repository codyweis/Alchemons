@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_sand.dart';
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
// weather, arrange, essence, moved).
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
    // Keepsakes earned: a few maxims, two contests, one species bred a
    // hundred times.
    var stars = PlanetStarState.fresh();
    for (final k in Keepsake.all.where((k) => k.eggId != null)) {
      stars = stars.withDiscoveredCloud(k.element!, k.eggId!);
    }
    SharedPreferences.setMockInitialValues({
      kPlanetStarsPrefsKey: stars.serialise(),
      kContestProgressPrefsKey: CosmicContestProgress.fresh()
          .withCompleted(CosmicContestTrait.beauty, 5)
          .withCompleted(CosmicContestTrait.strength, 5)
          .serialise(),
    });
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await db.constellationDao.incrementBreedCount('LET01');
      }
      // Every piece of decor owned, as many as a realm stands.
      for (final d in HomeDecor.all) {
        await db.inventoryDao.addItemQty(d.inventoryKey, d.max);
      }
      // The Arcane is a home only once it is unlocked in the wild.
      await db.settingsDao.setSetting('arcane_portal_unlocked', '1');
      // So is a realm the shop sells, once bought.
      await db.settingsDao.setSetting('scene_unlocked_dunes', '1');
      await db.settingsDao.setSetting('scene_unlocked_geode', '1');
      await db.settingsDao.setSetting('scene_unlocked_tidal', '1');
      await db.settingsDao.setSetting('scene_unlocked_sand', '1');
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
        (HomeRealm.dunes, 'sandstorm', 14.0),
        (HomeRealm.dunes, 'glass', 23.0),
        (HomeRealm.geode, 'frostfall', 12.0),
        (HomeRealm.geode, 'rime', 12.0),
        (HomeRealm.tidal, 'fog', 12.0),
        (HomeRealm.tidal, 'swell', 13.0),
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
    if (wants('essence')) {
      // Each one tapped: mid-way through coming apart into its element.
      for (final (realm, at) in const [
        (HomeRealm.valley, 0.9),
        (HomeRealm.valley, 1.4),
        (HomeRealm.arcane, 1.2),
      ]) {
        await shoot(
          'essence_${realm.name}_${(at * 10).round()}',
          base.copyWith(realm: realm),
          seconds: 1.5,
          then: () async {
            for (final r in household) {
              game().playEssence(r.spawnId);
            }
            // The grains are read off the test clock.
            await settle(3, ms: 1);
            await settle((at * 1000 / 66).round() - 14);
          },
        );
      }
    }
    if (wants('sandpan')) {
      // Living Sands panned so two of its tiles meet mid-screen (no seam),
      // then held still and a real finger drawn through it in a loop.
      final sands = base.copyWith(realm: HomeRealm.sand);
      Future<void> loop() async {
        final x0 = game().cameraX;
        final finger = await tester.startGesture(const Offset(607, 230));
        for (var i = 1; i <= 40; i++) {
          final a = i / 40 * 6.28;
          await finger.moveTo(
            Offset(457 + 150 * math.cos(a), 230 + 110 * math.sin(a)),
          );
          await settle(1, ms: 16);
        }
        await finger.up();
        if ((game().cameraX - x0).abs() > 0.5) {
          throw StateError('the view moved while locked');
        }
      }

      await shoot('sand_seam', sands, then: () async => game().debugPanTo(235));
      await shoot(
        'sand_stirred',
        sands,
        then: () async {
          await tester.tap(find.text('Lock'));
          await settle(2);
          await loop();
        },
      );
      // Sand that stays: the loop left as a furrow, and Smooth beside the
      // lock.
      await shoot(
        'sand_furrow',
        sands.copyWith(
          sandStyle: const HomeSandStyle(motion: SandMotion.staysPut),
        ),
        then: () async {
          await tester.tap(find.text('Lock'));
          await settle(2);
          await loop();
          await settle(60);
        },
      );
      // MIXES chosen in the settings, then the loop drawn through it: the
      // sands swirled through each other, nothing dug, and Smooth beside the
      // lock.
      await shoot(
        'sand_mixed',
        sands.copyWith(sandStyle: const HomeSandStyle(count: 3)),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(4);
          await tester.tap(find.text('SETTINGS'));
          await settle(2);
          await tester.tap(find.text('MIXES'));
          await settle(2);
          await tester.tap(find.text('Done'));
          await settle(4);
          await tester.tap(find.text('Lock'));
          await settle(2);
          await loop();
          await settle(60);
        },
      );
      // Arranging, with the colours open on the second of three sands.
      await shoot(
        'sand_tray',
        sands.copyWith(sandStyle: const HomeSandStyle(count: 3)),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(4);
          await tester.tap(find.text('COLORS'));
          await settle(2);
          await tester.tap(find.text('SAND 2'));
          await settle(2);
        },
      );
      // The settings, laid in layers.
      await shoot(
        'sand_settings',
        sands.copyWith(sandStyle: const HomeSandStyle(count: 3)),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(4);
          await tester.tap(find.text('SETTINGS'));
          await settle(2);
          await tester.tap(find.text('LAYERED'));
          await settle(4);
        },
      );
      // The second sand's hue drawn along to green: the floor follows the
      // finger, and is saved when it lifts.
      await shoot(
        'sand_dragged',
        sands,
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(4);
          await tester.tap(find.text('COLORS'));
          await settle(2);
          await tester.tap(find.text('SAND 2'));
          await settle(2);
          final hue = tester.getCenter(find.text('HUE'));
          final gesture = await tester.startGesture(Offset(665, hue.dy));
          for (var i = 1; i <= 12; i++) {
            await gesture.moveTo(Offset(665 - 30.0 * i, hue.dy));
            await settle(1, ms: 16);
          }
          await gesture.up();
          await settle(2);
          final saved = await tester.runAsync(
            () => HomeBiomeLayout.load(db.settingsDao),
          );
          final green = HSLColor.fromColor(saved!.sandStyle.colors[1]).hue;
          if (green < 90 || green > 160) {
            throw StateError('second sand saved at hue $green');
          }
        },
      );
      await shoot(
        'sand_rose',
        sands.copyWith(
          sandStyle: const HomeSandStyle(
            colors: [
              Color(0xFFE88AA0),
              Color(0xFF6FD3C8),
              Color(0xFFE6DCC6),
              Color(0xFF63B5A6),
              Color(0xFFE6DCC6),
            ],
            count: 3,
            pattern: SandPattern.drifts,
            shimmer: Color(0xFFFFFFFF),
          ),
        ),
      );
      await shoot(
        'sand_five',
        sands.copyWith(
          sandStyle: const HomeSandStyle(
            count: 5,
            pattern: SandPattern.layered,
          ),
        ),
      );
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
    if (wants('keepsakes')) {
      // Keepsakes stood among the household in every realm, by night and
      // by day, the residents left to live.
      const sets = <List<(String, double, bool)>>[
        [
          ('ember_torch#0', 0.06, false),
          ('ember_torch#1', 0.235, false),
          ('twin_portals#0', 0.145, false),
          ('twin_portals#1', 0.33, false),
          ('effigy:LET01', 0.10, true),
          ('hourglass', 0.215, true),
        ],
        [
          ('frozen_moon', 0.06, false),
          ('mud_lotus', 0.33, false),
          ('lancet_stone', 0.10, true),
          ('night_book', 0.215, true),
          ('giants_palm', 0.3, true),
        ],
        [
          ('star_walker', 0.06, false),
          ('the_dose', 0.33, false),
          ('crown_mirror', 0.10, true),
          ('titan_anvil', 0.215, true),
          ('garnet_heart', 0.3, true),
        ],
      ];
      for (final realm in HomeRealm.values) {
        for (final (i, hour) in const [(0, 21.5), (1, 12.5), (2, 18.8)]) {
          var layout = base.copyWith(realm: realm, hour: () => hour);
          layout = layout.withPlaced([
            ...realm.defaultPieces,
            for (final (id, x, back) in sets[i])
              HomePiece(id: id, kind: id.split('#').first, x: x, back: back),
          ]);
          await shoot('keepsakes_${realm.name}_$i', layout, seconds: 5);
        }
      }
    }
    if (wants('decor')) {
      // The decor stood about the household, by day and by night.
      const sets = <List<(String, double, bool, double?)>>[
        [
          ('lantern_post#0', 0.03, false, null),
          ('candles#0', 0.075, false, null),
          ('banner#0', 0.155, false, null),
          ('geode#0', 0.235, false, null),
          ('sky_lanterns#0', 0.12, false, 0.3),
          ('rune_stone#0', 0.10, true, null),
          ('planter#0', 0.215, true, null),
          ('lantern_post#1', 0.30, false, null),
        ],
        [
          ('wind_chimes#0', 0.03, false, null),
          ('fountain#0', 0.13, false, null),
          ('rest_nest#0', 0.24, false, null),
          ('swing#0', 0.33, false, null),
          ('flyer_perch#0', 0.10, true, null),
          ('mushroom_ring#0', 0.215, true, null),
        ],
        [
          ('hot_spring#0', 0.06, false, null),
          ('stage#0', 0.21, false, null),
          ('elder_tree#0', 0.12, true, null),
          ('orrery#0', 0.33, false, null),
        ],
        [
          ('reflecting_pool#0', 0.10, false, null),
          ('canopy#0', 0.25, false, null),
          ('elder_tree#0', 0.30, true, null),
        ],
      ];
      const resting = [
        HomeResident(instanceId: 'fire_horn', x: 0.02),
        HomeResident(instanceId: 'plant_let', x: 0.105, flip: true),
        HomeResident(instanceId: 'water_pip', x: 0.19),
        HomeResident(instanceId: 'air_wing', x: 0.13, lift: 0.3),
        HomeResident(instanceId: 'light_horn', x: 0.28),
      ];
      for (final (i, realm, hour, wx) in const [
        (0, HomeRealm.valley, 21.5, null),
        (0, HomeRealm.valley, 12.0, null),
        (1, HomeRealm.valley, 12.0, null),
        (1, HomeRealm.sky, 12.0, null),
        (2, HomeRealm.valley, 18.8, null),
        (2, HomeRealm.swamp, 18.8, null),
        (3, HomeRealm.valley, 14.0, 'rain'),
        (3, HomeRealm.arcane, 23.0, null),
      ]) {
        var layout = base.copyWith(
          realm: realm,
          hour: () => hour,
          residents: resting,
        );
        if (wx != null) layout = layout.withMood(wx);
        layout = layout.withPlaced([
          ...realm.defaultPieces,
          for (final (id, x, back, y) in sets[i])
            HomePiece(
              id: id,
              kind: id.split('#').first,
              x: x,
              back: back,
              y: y,
            ),
        ]);
        await shoot(
          'decor_${i}_${realm.name}_${hour.round()}${wx ?? ''}',
          layout,
          seconds: 6,
        );
      }
    }
    if (wants('spring')) {
      // Two residents bathing in the hot spring, by day in the Valley and
      // by night in the Arcane.
      for (final (realm, hour) in const [
        (HomeRealm.valley, 12.0),
        (HomeRealm.arcane, 22.5),
      ]) {
        final period = realm.period(realm.near.layer);
        final off = 1.33 * realm.near.size / period;
        await shoot(
          'spring_${realm.name}',
          base
              .copyWith(
                realm: realm,
                hour: () => hour,
                residents: [
                  HomeResident(
                    instanceId: 'water_pip',
                    x: 0.15 - off,
                    beside: 'PIECE_hot_spring#0',
                  ),
                  HomeResident(
                    instanceId: 'plant_let',
                    x: 0.15 + off,
                    beside: 'PIECE_hot_spring#0',
                  ),
                ],
              )
              .withPlaced([
                ...realm.defaultPieces,
                const HomePiece(
                  id: 'hot_spring#0',
                  kind: 'hot_spring',
                  x: 0.15,
                ),
              ]),
          seconds: 1,
          then: () async {
            expect(
              game().debugVisit('HOME_water_pip', 'PIECE_hot_spring#0'),
              isTrue,
            );
            expect(
              game().debugVisit('HOME_plant_let', 'PIECE_hot_spring#0'),
              isTrue,
            );
            game().debugPanTo(0.15 * realm.wildScene.worldWidth - 230);
            await settle(70);
          },
        );
      }
    }
    if (wants('pool')) {
      // The Reflecting Pool by day and by night, a resident at its edge
      // looking in, given back in the water.
      for (final (realm, hour) in const [
        (HomeRealm.valley, 12.0),
        (HomeRealm.valley, 22.5),
        (HomeRealm.arcane, 22.5),
        (HomeRealm.sky, 12.0),
      ]) {
        await shoot(
          'pool_${realm.name}_${hour.round()}',
          base
              .copyWith(
                realm: realm,
                hour: () => hour,
                residents: [
                  const HomeResident(instanceId: 'fire_horn', x: 0.02),
                  // Beside the pool, out at its rim.
                  HomeResident(
                    instanceId: 'water_pip',
                    x:
                        0.15 +
                        1.24 * realm.near.size / realm.period(realm.near.layer),
                    beside: 'PIECE_reflecting_pool#0',
                  ),
                ],
              )
              .withPlaced([
                ...realm.defaultPieces,
                const HomePiece(
                  id: 'reflecting_pool#0',
                  kind: 'reflecting_pool',
                  x: 0.15,
                ),
              ]),
          seconds: 1,
          then: () async {
            expect(
              game().debugVisit('HOME_water_pip', 'PIECE_reflecting_pool#0'),
              isTrue,
            );
            game().debugPanTo(0.15 * realm.wildScene.worldWidth - 180);
            await settle(45);
          },
        );
      }
    }
    if (wants('decortray')) {
      // Arranging with the decor tray open, the Wonders not owned: one is
      // stood in to be tried, and chosen, BUY on it.
      await tester.runAsync(() async {
        for (final d in HomeDecor.ofTier(DecorTier.wonder)) {
          await db.inventoryDao.setItemQty(d.inventoryKey, 0);
        }
      });
      await shoot(
        'decor_tray',
        base.copyWith(realm: HomeRealm.valley),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(3);
          await tester.tap(find.text('DECOR'));
          await settle(4);
        },
      );
      await shoot(
        'decor_trial',
        base.copyWith(realm: HomeRealm.valley),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(3);
          await tester.tap(find.text('DECOR'));
          await settle(3);
          // The purse stands at the head of the shelf, so the Living Pieces
          // start off screen: scroll the shelf itself to the spring.
          final shelf = tester.element(
            find
                .ancestor(
                  of: find.text('CURIOS'),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.scrollUntilVisible(
            find.text('HOT SPRING'),
            300,
            scrollable: find.byElementPredicate((e) => e == shelf),
          );
          await settle(3);
          await tester.tap(find.text('HOT SPRING'));
          await settle(8);
        },
      );
    }
    if (wants('shared')) {
      // Residents put down beside keepsakes and beside each other: one
      // isle, bank or shelf under each pair.
      for (final realm in const [
        HomeRealm.sky,
        HomeRealm.swamp,
        HomeRealm.volcano,
      ]) {
        final period = realm.period(realm.near.layer);
        final size = realm.near.size / period;
        await shoot(
          'shared_${realm.name}',
          base
              .copyWith(
                realm: realm,
                residents: [
                  HomeResident(
                    instanceId: 'fire_horn',
                    x: 0.10 + size * 0.62,
                    beside: 'PIECE_ember_torch#0',
                  ),
                  const HomeResident(instanceId: 'plant_let', x: 0.20),
                  HomeResident(
                    instanceId: 'water_pip',
                    x: 0.20 + size * 0.78,
                    beside: 'HOME_plant_let',
                  ),
                  HomeResident(
                    instanceId: 'light_horn',
                    x: 0.31 - size * 0.62,
                    beside: 'PIECE_twin_portals#0',
                  ),
                ],
              )
              .withPlaced([
                const HomePiece(
                  id: 'ember_torch#0',
                  kind: 'ember_torch',
                  x: 0.10,
                ),
                const HomePiece(
                  id: 'twin_portals#0',
                  kind: 'twin_portals',
                  x: 0.31,
                ),
              ]),
          seconds: 3,
        );
      }
    }
    if (wants('overview')) {
      // Arranging, zoomed out: the field a band floating in the dark.
      for (final (realm, hour) in const [
        (HomeRealm.valley, 18.8),
        (HomeRealm.sky, 12.0),
        (HomeRealm.volcano, 23.0),
        (HomeRealm.arcane, 23.0),
      ]) {
        await shoot(
          'overview_${realm.name}',
          base.copyWith(realm: realm, hour: () => hour),
          then: () async {
            await tester.tap(find.text('Arrange'));
            await settle(3);
            await tester.tap(find.text('OVERVIEW'));
            await settle(30);
          },
        );
      }
    }
    if (wants('scenery')) {
      // The Sky with its isles moved and a new grove set high; the Valley
      // with a boulder and its trees; arranging, the tray open.
      await shoot(
        'scenery_tray_valley',
        base.copyWith(realm: HomeRealm.valley),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(3);
          await tester.tap(find.text('SCENERY'));
          await settle(2);
          await tester.tap(find.text('BOULDER'));
          await settle(4);
        },
      );
      await shoot(
        'keepsake_tray',
        base.copyWith(realm: HomeRealm.valley),
        then: () async {
          await tester.tap(find.text('Arrange'));
          await settle(3);
          await tester.tap(find.text('KEEPSAKES'));
          await settle(6);
        },
      );
      await shoot(
        'scenery_valley',
        base.copyWith(realm: HomeRealm.valley).withPlaced([
          ...HomeRealm.valley.defaultPieces,
          const HomePiece(id: 'b1', kind: FieldPiece.boulder, x: 0.06),
          const HomePiece(
            id: 'b2',
            kind: FieldPiece.boulder,
            x: 0.24,
            scale: 1.45,
          ),
          const HomePiece(id: 't1', kind: FieldPiece.tree, x: 0.15, scale: 0.7),
        ]),
      );
      for (final realm in const [
        HomeRealm.swamp,
        HomeRealm.volcano,
        HomeRealm.arcane,
        HomeRealm.dunes,
        HomeRealm.geode,
        HomeRealm.tidal,
      ]) {
        await shoot(
          'scenery_${realm.name}',
          base.copyWith(realm: realm).withPlaced([
            for (final p in realm.defaultPieces)
              p.copyWith(x: (p.x + 0.03) % 1),
            for (final (i, s) in realm.scenery.indexed)
              HomePiece(id: 'n$i', kind: s.piece, x: 0.07 + i * 0.09),
          ]),
        );
      }
      await shoot(
        'scenery_sky',
        base.copyWith(realm: HomeRealm.sky).withPlaced([
          for (final p in HomeRealm.sky.defaultPieces)
            p.copyWith(x: (p.x + 0.05) % 1),
          const HomePiece(
            id: 'grove_new',
            kind: FieldPiece.grove,
            x: 0.12,
            y: 0.25,
            scale: 1.2,
          ),
        ]),
      );
    }
    await tester.runAsync(db.close);
  });
}
