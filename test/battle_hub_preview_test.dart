@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/battle/battle_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// The battle hub on the phone: the arena live, the arena row, your four,
// the computer's four, BATTLE.
//
//   HUB_OUT=/tmp/hub flutter test test/battle_hub_preview_test.dart \
//     --tags preview
//   [HUB_FLOW=1]  also films the whole way: BATTLE, the floor flying in,
//     the fight (sampled), the ending and card, BACK TO THE HUB, the flight
//     back — frames into <out>/flow
void main() {
  final out = Platform.environment['HUB_OUT'];

  setUpAll(loadLobbyFonts);

  testWidgets('battle hub', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final save = await LobbySave.create(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: SilentAudio(),
        child: save.app(shot: key, home: const BattleHubScreen()),
      ),
    );
    await settleLobby(tester, 30);
    await precacheLobbyImages(tester);
    await settleLobby(tester, 10);
    tester.takeException();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/hub.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await save.dispose(tester);
  });

  testWidgets('battle flow from the hub', (tester) async {
    if (out == null || Platform.environment['HUB_FLOW'] != '1') return;
    Directory('$out/flow').createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final save = await LobbySave.create(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: SilentAudio(),
        child: save.app(shot: key, home: const BattleHubScreen()),
      ),
    );
    await settleLobby(tester, 30);
    await precacheLobbyImages(tester);
    await settleLobby(tester, 6);
    var n = 0;
    Future<void> shot() async {
      tester.takeException();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 0.7);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/flow/f${(n++).toString().padLeft(4, '0')}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> film(double seconds, {int every = 2}) async {
      final frames = (seconds * 30).round();
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        if (i % 10 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
        }
        if (i % every == 0) await shot();
      }
    }

    await shot();
    await tester.tap(find.byKey(const ValueKey('battle.start')));
    // The flight in, the game loading under it, the fight starting.
    await film(3.0);
    // The fight, sampled, until it is over.
    for (var i = 0; i < 90 * 30; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (i % 10 == 0) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      if (i % 30 == 0) await shot();
      if (find.text('BACK TO THE HUB').evaluate().isNotEmpty) break;
      if (find.textContaining('After').evaluate().isNotEmpty) break;
    }
    // The ending and the card.
    await film(4.0);
    final back = find.text('BACK TO THE HUB');
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first, warnIfMissed: false);
      await film(2.2);
    }
    await save.dispose(tester);
  });
}
