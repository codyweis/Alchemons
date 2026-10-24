@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/raid_rewards.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

// The raid's loot popup as the player sees it on a phone, at each tier: the
// cards counted out under the rays, then CONTINUE lit.
//
//   RAID_REWARD_OUT=/tmp/raid_reward flutter test \
//     test/raid_reward_popup_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['RAID_REWARD_OUT'];
  setUpAll(loadLobbyFonts);

  for (final (level, l3Clears) in const [(1, 0), (3, 0), (3, 1)]) {
    testWidgets('raid popup L$level echo$l3Clears', (tester) async {
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
                  RaidRewardPopup(
                    element: 'Fire',
                    raidLevel: level,
                    level3ClearsBeforeFight: l3Clears,
                    db: db,
                    onGranted: () async {},
                    onContinue: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File(
          '$out/raid_popup_L${level}_echo$l3Clears.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
