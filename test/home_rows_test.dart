// The home biome's three rows: front, middle and back. Each keeps its own
// room (a full front row leaves the middle free), an isle up in the sky
// takes no room from the ground under it, something let go where its row
// has no room goes to the same place on the next row, and on the screen a
// keepsake is carried up from the front row to the middle one by a finger
// and sent back with the row chips.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every realm\'s middle row stands between its near and far rows', () {
    for (final realm in HomeRealm.values) {
      final near = realm.row(HomeDepth.front);
      final mid = realm.row(HomeDepth.mid);
      final far = realm.row(HomeDepth.back);
      expect(near.feet, greaterThan(mid.feet), reason: realm.name);
      expect(mid.feet, greaterThan(far.feet), reason: realm.name);
      expect(mid.size, inExclusiveRange(far.size, near.size));
      // It pans with the far row, nearer and bigger.
      expect(mid.layer, far.layer, reason: realm.name);
    }
  });

  test('each thing keeps its row through a save, older saves as they were', () {
    final layout =
        const HomeBiomeLayout(
          residents: [
            HomeResident(instanceId: 'a', x: .1),
            HomeResident(instanceId: 'b', x: .2, depth: HomeDepth.mid),
            HomeResident(instanceId: 'c', x: .3, depth: HomeDepth.back),
          ],
        ).withPlaced(const [
          HomePiece(
            id: 'candles#0',
            kind: 'candles',
            x: .4,
            depth: HomeDepth.mid,
          ),
        ]);
    final back = HomeBiomeLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())),
    );
    expect(
      [for (final r in back.residents) r.depth],
      [HomeDepth.front, HomeDepth.mid, HomeDepth.back],
    );
    expect(back.placed.single.depth, HomeDepth.mid);

    // Saved before there was a middle row: the far row is where it was.
    expect(
      HomeResident.fromJson({'id': 'x', 'back': true})!.depth,
      HomeDepth.back,
    );
    // Scenery has no middle row: read as the near one.
    expect(
      HomePiece.fromJson({
        'id': 't',
        'kind': FieldPiece.tree,
        'mid': true,
      })!.depth,
      HomeDepth.front,
    );
  });

  test('a full front row leaves the middle row its own room', () {
    var layout = const HomeBiomeLayout();
    var n = 0;
    while (true) {
      final r = HomeResident(instanceId: 'r${n++}');
      final x = layout.freeSpotNear(r, .5);
      if (x == null) break;
      layout = layout.copyWith(
        residents: [
          ...layout.residents,
          r.copyWith(x: x),
        ],
      );
    }
    expect(
      layout.freeSpotNear(
        const HomeResident(instanceId: 'm', depth: HomeDepth.mid),
        .5,
      ),
      .5,
    );
  });

  test('an isle up in the sky takes no room from the ground under it', () {
    const realm = HomeRealm.sky;
    const candles = HomePiece(id: 'candles#0', kind: 'candles');
    HomeBiomeLayout withIsle(double y) =>
        const HomeBiomeLayout(realm: realm).withPlaced([
          HomePiece(id: 'i', kind: FieldPiece.grove, x: .5, y: y, scale: 1.45),
        ]);
    // Set high, where it reads as far off: candles stand right under it.
    expect(withIsle(.22).freeSpotForPiece(candles, .5), .5);
    // Set where the front row's feet are, it is that row's ground.
    final feet = realm.row(HomeDepth.front).feet;
    expect(withIsle(feet).freeSpotForPiece(candles, .5), isNot(.5));
    // …and still none of the middle row's.
    expect(
      withIsle(
        feet,
      ).freeSpotForPiece(candles.copyWith(depth: HomeDepth.mid), .5),
      .5,
    );
  });

  group('let go', () {
    const realm = HomeRealm.valley;
    double same(HomeDepth d) => .5;

    HomeBiomeLayout fullFront() {
      var layout = const HomeBiomeLayout(realm: realm);
      var n = 0;
      while (true) {
        final r = HomeResident(instanceId: 'r${n++}');
        final x = layout.freeSpotNear(r, .5);
        if (x == null) break;
        layout = layout.copyWith(
          residents: [
            ...layout.residents,
            r.copyWith(x: x),
          ],
        );
      }
      return layout;
    }

    test('where it was let go, when there is room', () {
      final layout = const HomeBiomeLayout(
        realm: realm,
      ).copyWith(residents: const [HomeResident(instanceId: 'a', x: .1)]);
      final drop = layout.dropResident(
        layout.residents.single,
        HomeDepth.mid,
        same,
      )!;
      expect(drop.how, HomeLanding.asked);
      expect(drop.depth, HomeDepth.mid);
      expect(drop.layout.residents.single.depth, HomeDepth.mid);
      expect(drop.layout.residents.single.x, closeTo(.5, 1e-9));
    });

    test('where its row is full, at the same place on the next row', () {
      final layout = fullFront().withPlaced(const [
        HomePiece(
          id: 'candles#0',
          kind: 'candles',
          x: .9,
          depth: HomeDepth.back,
        ),
      ]);
      final drop = layout.dropPiece(
        layout.placed.single,
        HomeDepth.front,
        same,
      )!;
      expect(drop.how, HomeLanding.otherRow);
      expect(drop.depth, HomeDepth.mid);
      expect(drop.x, closeTo(.5, layout.gap(HomeDepth.mid)));
    });

    test('asked for a row, it stays on that row', () {
      final layout = fullFront().copyWith(
        residents: [
          ...fullFront().residents,
          const HomeResident(instanceId: 'm', x: .5, depth: HomeDepth.mid),
        ],
      );
      final drop = layout.dropResident(
        layout.resident('HOME_m')!,
        HomeDepth.front,
        same,
        stay: true,
      );
      expect(drop, isNull, reason: 'the front row has no room at all');
    });

    test('by a resident on its row, it stands beside it', () {
      const layout = HomeBiomeLayout(
        realm: realm,
        residents: [HomeResident(instanceId: 'a', x: .5, depth: HomeDepth.mid)],
      );
      final placed = layout.withPlaced(const [
        HomePiece(id: 'candles#0', kind: 'candles', x: .1),
      ]);
      final row = realm.row(HomeDepth.mid);
      final size = row.size / realm.period(row.layer);
      final drop = placed.dropPiece(
        placed.placed.single,
        HomeDepth.mid,
        (_) => .5 + size * .4,
      )!;
      expect(drop.how, HomeLanding.beside);
      expect(drop.layout.placed.single.beside, 'HOME_a');
      expect(drop.layout.placed.single.depth, HomeDepth.mid);
    });
  });

  testWidgets('carried up by a finger to the middle row, sent back by chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(915, 412) * 2;
    tester.view.devicePixelRatio = 2;
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
    SharedPreferences.setMockInitialValues({});
    const post = 'PIECE_lantern_post#0';
    await tester.runAsync(() async {
      await db.inventoryDao.addItemQty('home.lantern_post', 1);
      await const HomeBiomeLayout()
          .withPlaced(const [
            HomePiece(id: 'lantern_post#0', kind: 'lantern_post', x: .07),
          ])
          .save(db.settingsDao);
    });

    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    Future<HomePiece> saved() async {
      final layout = await tester.runAsync(
        () => HomeBiomeLayout.load(db.settingsDao),
      );
      return layout!.piece(post)!;
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const HomeBiomeScreen(),
        ),
      ),
    );
    for (
      var i = 0;
      i < 60 && find.byType(GameWidget<SceneGame>).evaluate().isEmpty;
      i++
    ) {
      await settle(1);
    }
    await settle(30);
    SceneGame game() => tester
        .widget<GameWidget<SceneGame>>(find.byType(GameWidget<SceneGame>))
        .game!;

    await tester.tap(find.text('Arrange'));
    await settle(6);

    // Held a moment, then carried up toward the middle row: where it would
    // land is shown there, and let go, it stands there.
    final at = game().debugScreenOf(post)!;
    final finger = await tester.startGesture(at + const Offset(0, -30));
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final h = game().fieldHeight;
    const realm = HomeRealm.valley;
    final up =
        (realm.row(HomeDepth.front).feet - realm.row(HomeDepth.mid).feet) * h;
    for (var i = 1; i <= 12; i++) {
      await finger.moveBy(Offset(2, -up / 12));
      await settle(1);
    }
    expect(game().debugLanding?.layer, realm.row(HomeDepth.mid).layer);
    await finger.up();
    await settle(6);
    expect((await saved()).depth, HomeDepth.mid);
    expect(game().debugPointOf(post)!.depth, HomeDepth.mid.index);

    // Chosen, the chips send it to the back, and to the front again.
    game().onResidentTap!(post);
    await settle(4);
    expect(find.text('MIDDLE'), findsOneWidget);
    await tester.tap(find.text('BACK'));
    await settle(6);
    expect((await saved()).depth, HomeDepth.back);
    await tester.tap(find.text('FRONT'));
    await settle(6);
    expect((await saved()).depth, HomeDepth.front);

    await tester.pumpWidget(const SizedBox());
    await settle(2);
    await tester.runAsync(db.close);
  });
}
