@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'survival_lobby_harness.dart';

// The survival lobby (CosmicSurvivalScreen before a run) on the phone, with
// real fonts, a mid-game save and BoxShadows switched back on:
//
//   1_first_seen.png      the screen as it opens, 475 x 751
//   2_command_hub.png     scrolled to the bottom, the Command Hub in view
//   3_full_length.png     the whole scroll length in one tall viewport
//   4_card_expanded.png   the first roster card tapped open
//   5_fresh_save.png      a brand-new save: no path, no upgrades, default orb
//
//   LOBBY_OUT=/tmp/lobby flutter test \
//     test/survival_lobby_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['LOBBY_OUT'];

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

  Future<void> open(WidgetTester tester, LobbySave save, GlobalKey key) async {
    await tester.pumpWidget(save.app(shot: key));
    for (var i = 0; i < 40 && !lobbyShown(); i++) {
      await settleLobby(tester, 1);
    }
    await precacheLobbyImages(tester);
    await settleLobby(tester, 6);
    expect(lobbyShown(), isTrue);
    expect(tester.takeException(), isNull);
  }

  testWidgets('survival lobby on the phone', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);

    final save = await LobbySave.create(tester);
    final key = GlobalKey();
    // Tests turn BoxShadows off; the phone draws them. Back on for the
    // pictures, and off again before the test ends (the binding checks).
    debugDisableShadows = false;
    try {
      await open(tester, save, key);
      await shoot(tester, key, '1_first_seen');

      final scroll = lobbyScroll(tester);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await settleLobby(tester, 4);
      await shoot(tester, key, '2_command_hub');
      scroll.position.jumpTo(0);
      await settleLobby(tester, 2);

      await tester.tap(find.byKey(const ValueKey('species-card-Let')));
      await settleLobby(tester, 8);
      // The card's text expands at once while its height animates up over
      // 160 ms, so the first frames of an expand overflow the card (clipped on
      // the phone, striped in debug). Reported, not failed.
      final overflow = tester.takeException();
      if (overflow != null) {
        // ignore: avoid_print
        print(
          'expanding a roster card overflowed mid-animation: '
          '${overflow.toString().split('\n').first}',
        );
      }
      await shoot(tester, key, '4_card_expanded');
      await tester.tap(find.byKey(const ValueKey('species-card-Let')));
      await settleLobby(tester, 8);

      // The whole scroll length: grow the viewport until nothing scrolls.
      final extent = lobbyScroll(tester).position.maxScrollExtent;
      tester.view.physicalSize = Size(
        kLobbyPhysical.width,
        kLobbyPhysical.height + (extent + 2) * kLobbyDpr,
      );
      await settleLobby(tester, 4);
      expect(lobbyScroll(tester).position.maxScrollExtent, 0);
      await shoot(tester, key, '3_full_length');

      // And again with the first card open, the longest the lobby gets.
      await tester.tap(find.byKey(const ValueKey('species-card-Let')));
      await settleLobby(tester, 8);
      tester.takeException();
      final more = lobbyScroll(tester).position.maxScrollExtent;
      tester.view.physicalSize = Size(
        kLobbyPhysical.width,
        tester.view.physicalSize.height + (more + 2) * kLobbyDpr,
      );
      await settleLobby(tester, 4);
      await shoot(tester, key, '6_full_length_expanded');
    } finally {
      debugDisableShadows = true;
    }

    await save.dispose(tester);
  });

  testWidgets('survival lobby on a fresh save', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);

    final save = await LobbySave.create(tester, fresh: true);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await open(tester, save, key);
      final extent = lobbyScroll(tester).position.maxScrollExtent;
      tester.view.physicalSize = Size(
        kLobbyPhysical.width,
        kLobbyPhysical.height + (extent + 2) * kLobbyDpr,
      );
      await settleLobby(tester, 4);
      await shoot(tester, key, '5_fresh_save');
    } finally {
      debugDisableShadows = true;
    }

    await save.dispose(tester);
  });
}
