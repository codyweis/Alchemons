// Arranging the home biome: Alchemons gather beside a thing (several to a
// side, closed up when one leaves), the scenery tray stays open while
// pieces are added, what is chosen is let go with OK, decor tiles say what
// is owned and what a tap does, and leaving with an unbought preview asks
// first.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
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
  group('standing beside', () {
    const realm = HomeRealm.valley;
    final row = realm.row(HomeDepth.front);
    final size = row.size / realm.period(row.layer);
    const post = HomePiece(id: 'lantern_post#0', kind: 'lantern_post', x: .5);

    HomeBiomeLayout put(HomeBiomeLayout layout, String id, double x) {
      final r = layout.resident('HOME_$id')!;
      final nest = layout.nestBeside(r.spawnId, x, depth: HomeDepth.front);
      expect(nest, isNotNull, reason: '$id let go at $x');
      return layout.replace(r.copyWith(x: nest!.$2, beside: () => nest.$1));
    }

    test('three to a side of a lantern post, then the other side', () {
      var layout = const HomeBiomeLayout()
          .withPlaced(const [post])
          .copyWith(
            residents: [
              for (final id in ['a', 'b', 'c', 'd'])
                HomeResident(instanceId: id, x: .05),
            ],
          );
      // Each let go just right of the post — or of the last one there.
      layout = put(layout, 'a', .5 + size * 0.3);
      final a = layout.resident('HOME_a')!.x;
      expect(a, greaterThan(.5));
      layout = put(layout, 'b', a + size * 0.3);
      final b = layout.resident('HOME_b')!.x;
      expect(b, greaterThan(a + size * 0.5), reason: 'past the first');
      layout = put(layout, 'c', b + size * 0.3);
      final c = layout.resident('HOME_c')!.x;
      expect(c, greaterThan(b + size * 0.5));
      for (final id in ['a', 'b', 'c']) {
        expect(layout.resident('HOME_$id')!.beside, post.spawnId);
      }
      // That side is full: the fourth stands on the other.
      layout = put(layout, 'd', c + size * 0.3);
      expect(layout.resident('HOME_d')!.x, lessThan(.5));
      expect(layout.resident('HOME_d')!.beside, post.spawnId);

      // The middle one leaves: the rest close up to the post.
      layout = layout
          .replace(
            layout.resident('HOME_b')!.copyWith(x: .1, beside: () => null),
          )
          .packBeside(post.spawnId);
      expect(layout.resident('HOME_a')!.x, closeTo(a, 1e-9));
      expect(layout.resident('HOME_c')!.x, closeTo(b, 1e-9));
    });

    test('let go near the far end of a group, it joins the group', () {
      var layout = const HomeBiomeLayout()
          .withPlaced(const [post])
          .copyWith(
            residents: const [
              HomeResident(instanceId: 'a', x: .05),
              HomeResident(instanceId: 'b', x: .05),
            ],
          );
      layout = put(layout, 'a', .5 - size * 0.3);
      final a = layout.resident('HOME_a')!.x;
      // Further from the post than nesting beside it alone ever reached.
      final nest = layout.nestBeside(
        'HOME_b',
        a - size,
        depth: HomeDepth.front,
      );
      expect(nest?.$1, post.spawnId);
      expect(nest!.$2, lessThan(a));
    });

    test('Spirit Alchemons can fly', () {
      expect(speciesCanFloat('LET14'), isTrue);
      expect(speciesCanFloat('HOR14'), isTrue);
    });
  });

  testWidgets('placing scenery and decor, letting go, and leaving', (
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
    await tester.runAsync(() async {
      // Two candle clusters owned; nothing else.
      await db.inventoryDao.addItemQty('home.candles', 2);
      await const HomeBiomeLayout().save(db.settingsDao);
    });

    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 66));
      }
    }

    Future<void> tapText(String text) async {
      // The first of them: the lantern post leads the decor tray.
      final f = find.text(text).first;
      await tester.ensureVisible(f);
      await settle(2);
      await tester.tap(f);
      await settle(6);
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

    await tapText('Arrange');
    await tapText('SCENERY');
    await tapText('BOULDER');
    // Placed and chosen, and the tray is still there for the next piece.
    expect(find.text('BOULDER'), findsWidgets);
    expect(find.text('OK'), findsOneWidget);
    await tapText('BOULDER');
    expect(find.text('OK'), findsOneWidget);
    await tapText('OK');
    expect(find.text('OK'), findsNothing);
    expect(find.text('Arrange'), findsNothing, reason: 'still arranging');

    // The decor tray says what is owned and what a tap does.
    await tapText('SCENERY');
    await tapText('DECOR');
    expect(find.text('OWN 2 OF 8'), findsOneWidget);
    expect(find.text('PLACE · 2 LEFT'), findsOneWidget);
    expect(find.text('PREVIEW · 400 S'), findsWidgets, reason: 'lantern');
    expect(find.text('NOT OWNED'), findsWidgets);

    // An owned one: placed, the tray steps aside, and OK brings it back.
    await tapText('PLACE · 2 LEFT');
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('PLACE · 1 LEFT'), findsNothing);
    await tapText('OK');
    expect(find.text('PLACE · 1 LEFT'), findsOneWidget);

    // One not owned is a preview, said so, with no OK: bought or not.
    await tapText('PREVIEW · 400 S');
    expect(find.textContaining('· PREVIEW'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
    expect(find.text('This is a preview. Buy it to keep it here.'), findsOne);

    // Leaving with it unbought asks first.
    await tapText('Done');
    expect(find.text('Arrange'), findsNothing);
    expect(find.textContaining('Tap again to leave'), findsOneWidget);
    await tapText('Leave?');
    expect(find.text('Arrange'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(2);
    await tester.runAsync(db.close);
  });
}
