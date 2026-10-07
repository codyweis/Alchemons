@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// START in the survival lobby, frame by frame: the lobby's chrome easing
// away, the core carried from the stage to the run's opening view of it,
// the arena fading in round it, the run taking the core over, and the camera
// gliding out to the ship. On the phone, real fonts, a saved team.
//
//   ENTRANCE_OUT=/tmp/entrance flutter test \
//     test/survival_entrance_preview_test.dart --tags preview
//
// Frames are every 33 ms (ENTRANCE_EVERY=n keeps every nth), named by their
// time since START: entrance_01320.png is 1.32 s in. ENTRANCE_ORB picks the
// equipped orb (celestialOrb by default; defaultOrb, infernalOrb, …).
void main() {
  final out = Platform.environment['ENTRANCE_OUT'];
  final every = int.tryParse(Platform.environment['ENTRANCE_EVERY'] ?? '') ?? 1;

  setUpAll(loadLobbyFonts);

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('START carries the core into the run', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);

    final save = await LobbySave.create(
      tester,
      team: kLobbyTeam,
      orb: Platform.environment['ENTRANCE_ORB'] ?? 'celestialOrb',
    );
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<AudioController>.value(
          value: SilentAudio(),
          child: save.app(shot: key),
        ),
      );
      await settleLobby(tester, 8);
      await precacheLobbyImages(tester);
      await settleLobby(tester, 4);
      await shoot(tester, key, 'entrance_lobby');

      await tester.tap(find.byKey(const ValueKey('survival.start')));
      var ms = 0;
      var frame = 0;
      while (ms <= 4300) {
        if (frame % every == 0) {
          tester.takeException();
          await shoot(tester, key, 'entrance_${ms.toString().padLeft(5, '0')}');
        }
        await tester.pump(const Duration(milliseconds: 33));
        ms += 33;
        frame++;
      }
      tester.takeException();
    } finally {
      debugDisableShadows = true;
    }
  });
}
