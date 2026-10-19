// The home biome's new switches on the real screen: SKY & SEASON turns the
// planet's look, the constellations and the idle camera off and holds a
// season; LAYOUTS keeps the realm as it stands; FRAME keeps the view. Each
// is saved with the home.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/home_sky.dart';
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
  testWidgets('sky switches, a kept layout and a framed view are saved', (
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
    await tester.runAsync(() => const HomeBiomeLayout().save(db.settingsDao));

    Future<void> settle(int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 4)),
        );
        await tester.pump(const Duration(milliseconds: 66));
      }
    }

    Future<void> tapText(String text) async {
      final f = find.text(text).first;
      await tester.ensureVisible(f);
      await settle(2);
      await tester.tap(f);
      await settle(6);
    }

    Future<HomeBiomeLayout> saved() async =>
        (await tester.runAsync(() => HomeBiomeLayout.load(db.settingsDao)))!;

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
    await tapText('SKY & SEASON');
    expect(find.text('SEASON'), findsOneWidget);
    await tapText('PLANET');
    await tapText('WINTER');
    await tapText('IDLE CAMERA');
    var layout = await saved();
    expect(layout.sky.planet, isFalse);
    expect(layout.sky.season, HomeSeasonPick.winter);
    expect(layout.sky.idleCamera, isFalse);
    expect(layout.sky.constellations, isTrue);

    await tapText('LAYOUTS');
    await tapText('KEEP AS 1');
    layout = await saved();
    expect(layout.arrangementsHere.first, isNotNull);
    expect(find.text('KEEP OVER'), findsOneWidget);

    await tapText('Done');
    await tapText('Frame');
    expect(find.text('KEEP THIS VIEW'), findsOneWidget);
    expect(find.text('Arrange'), findsNothing, reason: 'the HUD steps aside');
    await tapText('KEEP THIS VIEW');
    layout = await saved();
    expect(layout.frame, isNotNull);
    expect(find.text('Arrange'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(2);
    await tester.runAsync(db.close);
  });
}
