@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_party_slot.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

// A Survival run on the phone, as the player sees it: the real screen, a
// debug test squad launched from the lobby, the arena and the HUD over it.
//
//   RUN_OUT=/tmp/run flutter test test/survival_run_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['RUN_OUT'];

  setUpAll(loadLobbyFonts);

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('survival run on the phone', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);

    final save = await LobbySave.create(tester);
    await tester.runAsync(() => DebugSettingsService().setEnabled(true));
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<AudioController>.value(
          value: _SilentAudio(),
          child: save.app(shot: key),
        ),
      );
      for (var i = 0; i < 40 && !lobbyShown(); i++) {
        await settleLobby(tester, 1);
      }
      await settleLobby(tester, 4);
      final scroll = lobbyScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await settleLobby(tester, 4);
      await tester.tap(
        find.text(Platform.environment['RUN_SQUAD'] ?? 'Test Squad Lets'),
      );
      // Through the portal and some way into the first wave.
      for (var i = 0; i < 12 * 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        if (i % 30 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
      }
      await precacheLobbyImages(tester);
      await tester.pump(const Duration(milliseconds: 33));
      tester.takeException();
      await shoot(tester, key, 'run_1');
      // Deploy the first two of the party.
      final slots = find.byType(SurvivalPartySlot);
      for (var i = 0; i < 2 && i < slots.evaluate().length; i++) {
        await tester.tap(slots.at(i), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 33));
      }
      for (var i = 0; i < 8 * 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      tester.takeException();
      await shoot(tester, key, 'run_2');
      final pause = find.byKey(const ValueKey('survival.pause'));
      if (pause.evaluate().isNotEmpty) {
        await tester.tap(pause);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
        await shoot(tester, key, 'run_pause');
      }
    } finally {
      debugDisableShadows = true;
      await tester.runAsync(() => DebugSettingsService().setEnabled(false));
    }
  });
}

/// The screen starts the run's music; under test there is nothing to play it
/// on, and the real controller opens audio players as it is built.
class _SilentAudio extends ChangeNotifier implements AudioController {
  @override
  Future<void> playSurvivalMusic() async {}

  @override
  Future<void> playHomeMusic() async {}

  @override
  int soundEventSerial = 0;

  @override
  Future<void> playSound(
    SoundCue cue, {
    Object? owner,
    double speed = 1,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
