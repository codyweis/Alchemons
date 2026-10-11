// Home ambiences and trails (the Athanor's) at home: an ambience shows only
// at its hour, never announces itself — no words drawn, no snack, nothing
// on the screen naming it while looking — and choosing one says nothing
// either. Trails keep a bounded number of prints that fade.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:alchemons/widgets/fx/cosmetics/home_ambience_art.dart';
import 'package:alchemons/widgets/fx/cosmetics/trail_art.dart';
import 'package:drift/native.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts what a painter draws that is not grains.
class _Spy implements Canvas {
  int words = 0, atlases = 0, other = 0;

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => words++;

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) => atlases++;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    other++;
    return null;
  }
}

/// A notice on screen: a SnackBar, or the game's own top notice
/// (showGameSnack's overlay).
Finder _notices() => find.byWidgetPredicate(
  (w) => w is SnackBar || w.runtimeType.toString() == '_TopNotification',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the ambience layer', () {
    test('each shows only at its own hour', () {
      double at(HomeAmbience a, double h, {bool clear = true}) =>
          ambienceShows(a, h, clear: clear);
      expect(at(HomeAmbience.peatMist, 23), 1);
      expect(at(HomeAmbience.peatMist, 2), 1);
      expect(at(HomeAmbience.peatMist, 12), 0);
      expect(at(HomeAmbience.moonlitSnowfall, 23), 1);
      expect(at(HomeAmbience.moonlitSnowfall, 23, clear: false), 0);
      expect(at(HomeAmbience.moonlitSnowfall, 12), 0);
      expect(at(HomeAmbience.sunMotes, 12), 1);
      expect(at(HomeAmbience.sunMotes, 23), 0);
      expect(at(HomeAmbience.emberFall, 19), 1);
      expect(at(HomeAmbience.emberFall, 12), 0);
      expect(at(HomeAmbience.emberFall, 2), 0);
      // Easing, never a switch: halfway through dusk the mist is coming.
      final dusk = at(HomeAmbience.peatMist, 19.2);
      expect(dusk, greaterThan(0));
      expect(dusk, lessThan(1));
    });

    test('it draws grains only: no words, one or two atlas draws', () {
      for (final a in HomeAmbience.values) {
        final spy = _Spy();
        final over = CosmeticAtlas(800), light = CosmeticAtlas(1200);
        paintHomeAmbience(
          a,
          AmbienceView(
            left: -300,
            right: 1600,
            top: 0,
            bottom: 412,
            height: 412,
            time: 30,
            ground: (x) => 330,
            feet: const [Offset(200, 330)],
          ),
          1,
          over,
          light,
        );
        expect(over.length + light.length, greaterThan(20), reason: a.id);
        over.draw(spy);
        light.draw(spy, blend: BlendMode.plus);
        expect(spy.words, 0, reason: a.id);
        expect(spy.atlases, inInclusiveRange(1, 2), reason: a.id);
        expect(spy.other, 0, reason: a.id);
      }
    });
  });

  test('a trail keeps a bounded number of prints, and they fade', () {
    for (final style in TrailStyle.values) {
      final p = TrailPrints(style, capacity: 6);
      for (var i = 0; i < 40; i++) {
        p.step(i * 10.0, 0, i * 0.3, size: 20);
      }
      final g = CosmeticAtlas(1000), l = CosmeticAtlas(1000);
      p.paint(g, l, 12);
      expect(g.length, lessThanOrEqualTo(6 * TrailPrints.entriesPerPrint));
      expect(p.aliveAt(12), isTrue);
      expect(p.aliveAt(12 + p.life + 0.1), isFalse);
      g.clear();
      l.clear();
      p.paint(g, l, 12 + p.life + 0.1);
      expect(g.length + l.length, 0);
    }
  });

  testWidgets('home never announces its ambience', (tester) async {
    const screen = Size(915, 412);
    tester.view.physicalSize = screen * 2;
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
    final wear = CosmeticWearService(db);
    await tester.runAsync(() async {
      await db.creatureDao.insertInstance(
        instanceId: 'fire_horn',
        baseId: 'HOR01',
        level: 5,
      );
      for (final a in HomeAmbience.values) {
        await OwnedCosmetics.grant(db, AthanorPieceKind.ambience, a.id);
      }
      await wear.load();
      await wear.wearAmbience('valley', HomeAmbience.peatMist);
      await const HomeBiomeLayout(
        hour: 23,
        residents: [HomeResident(instanceId: 'fire_horn', x: 0.1)],
      ).save(db.settingsDao);
    });

    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 66));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
          Provider<CreatureCatalog>.value(value: catalog),
          ChangeNotifierProvider<CosmeticWearService>.value(value: wear),
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

    final game = tester
        .widget<GameWidget<SceneGame>>(find.byType(GameWidget<SceneGame>))
        .game!;
    expect(game.ambience, HomeAmbience.peatMist);

    // Looking: nothing on the screen names it, and nothing was posted.
    for (final a in HomeAmbience.values) {
      expect(find.textContaining(a.title), findsNothing);
      expect(find.textContaining(a.title.toUpperCase()), findsNothing);
    }
    expect(_notices(), findsNothing);

    // Choosing another, arranging, says nothing either: the chip is lit,
    // and that is all.
    await tester.tap(find.text('Arrange'));
    await settle(6);
    final chip = find.text('MOONLIT SNOWFALL');
    await tester.ensureVisible(chip);
    await settle(2);
    await tester.tap(chip);
    await settle(10);
    expect(game.ambience, HomeAmbience.moonlitSnowfall);
    expect(wear.ambienceIn('valley'), HomeAmbience.moonlitSnowfall);
    expect(_notices(), findsNothing);
    // Its name is on its chip and nowhere else.
    expect(find.textContaining('SNOWFALL'), findsOneWidget);
    expect(find.textContaining('Snowfall'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await settle(2);
    await tester.runAsync(db.close);
  });
}
