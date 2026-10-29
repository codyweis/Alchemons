@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_reward_popup.dart';
import 'package:alchemons/widgets/grain_loader.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

// The dungeon's star popup as a phone shows it: the star gathering, the rows
// counted out, the Star 3 choice before and after a row is lit; and the
// grain loader at the sizes it is used.
//
//   DUNGEON_REWARD_OUT=/tmp/dungeon_reward flutter test \
//     test/dungeon_reward_popup_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['DUNGEON_REWARD_OUT'];
  setUpAll(loadLobbyFonts);

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out!).createSync(recursive: true);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });

  Future<void> run(WidgetTester tester, int ms) async {
    for (var i = 0; i < ms ~/ 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  for (final (name, stars) in const [
    ('star1', [0]),
    ('stars12', [0, 1]),
    ('star3', [2]),
  ]) {
    testWidgets('dungeon popup $name', (tester) async {
      if (out == null) return;
      final db = AlchemonsDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: const Color(0xFF1A1512),
              body: Stack(
                children: [
                  DungeonRewardPopup(
                    element: 'Fire',
                    stars: stars,
                    starNames: stars.length == 1 ? const ['Ember Star'] : [],
                    db: db,
                    onContinue: () {},
                    onLeave: stars.contains(2) ? () {} : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await run(tester, 360);
      await shoot(tester, key, '${name}_a_arriving');
      await run(tester, 2400);
      await shoot(tester, key, '${name}_b_settled');
      if (stars.contains(2)) {
        await tester.tap(find.text('25 GOLD'));
        await run(tester, 600);
        await shoot(tester, key, '${name}_c_lit');
        await tester.tap(find.text('25 GOLD'));
        await run(tester, 1200);
        await shoot(tester, key, '${name}_d_claimed');
      }
    });
  }

  testWidgets('grain loader sizes', (tester) async {
    if (out == null) return;
    tester.view.physicalSize = const Size(390 * 3, 300 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: Color(0xFF09090B),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GrainLoader(size: 12),
                  GrainLoader(size: 18),
                  GrainLoader(size: 28),
                  GrainLoader(),
                  GrainLoader(size: 72),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final ms in [0, 800, 1600, 2400]) {
      await run(tester, ms == 0 ? 60 : 800);
      await shoot(tester, key, 'loader_$ms');
    }
  });
}
