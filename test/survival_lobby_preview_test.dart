@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic_survival/components/survival_lobby_stage.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_screen.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/navigation/emblem_passage.dart';
import 'package:alchemons/widgets/dock_emblems.dart';
import 'package:alchemons/widgets/dock_passages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dock_passage_stage.dart';
import 'survival_lobby_harness.dart';

// The survival lobby (CosmicSurvivalScreen before a run) on the phone, with
// real fonts, a mid-game save and BoxShadows switched back on:
//
//   1_team_chosen.png     the screen as it opens with a team saved, 475 x 751
//   2_scrolled.png        on a shorter phone (475 x 600), scrolled to the bottom
//   3_full_length.png     the whole scroll length in one tall viewport
//   4_empty_team.png      the mid-game save with no team chosen yet
//   5_fresh_save.png      a brand-new save: no team, no upgrades, default orb
//   6_fold_cover.png      the Fold's cover screen (344 wide) at 1.3x text,
//                         the whole scroll length
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
    await settleLobby(tester, 8);
    await precacheLobbyImages(tester);
    await settleLobby(tester, 6);
    expect(lobbyShown(), isTrue);
    expect(tester.takeException(), isNull);
  }

  Future<void> growToFit(WidgetTester tester) async {
    final extent = lobbyScroll(tester).position.maxScrollExtent;
    tester.view.physicalSize = Size(
      kLobbyPhysical.width,
      kLobbyPhysical.height + (extent + 2) * kLobbyDpr,
    );
    await settleLobby(tester, 4);
    expect(lobbyScroll(tester).position.maxScrollExtent, 0);
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
  }

  // The dock's orb carrying the player onto the hub's own, frame by frame
  // over the real hub, and back.
  testWidgets('survival passage', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    phone(tester);
    tester.view.padding = const FakeViewPadding(top: 28 * kLobbyDpr);
    final save = await LobbySave.create(tester, team: kLobbyTeam);
    final skin = save.upgrades.state.equippedSkin;
    final key = GlobalKey();
    final emblem = GlobalKey();
    final lifted = ValueNotifier(false);
    await tester.pumpWidget(
      save.app(
        shot: key,
        home: DockStandIn(
          kind: DockEmblemKind.survival,
          emblemKey: emblem,
          lifted: lifted,
          size: 80,
          top: 240,
          orb: skin,
        ),
      ),
    );
    await settleLobby(tester, 4);
    final ready = ValueNotifier(false);
    EmblemPassage.pushScene<void>(
      emblem.currentContext!,
      scene: SurvivalPassage(skin: skin, target: survivalLobbyOrbFor),
      from: emblem,
      page: CosmicSurvivalScreen(revealReady: ready),
      ready: ready,
      lifted: lifted,
    );
    var n = 0;
    String tag(String s) => 'passage_${(n++).toString().padLeft(2, '0')}_$s';
    await shoot(tester, key, tag('home'));
    for (var i = 0; i < 6; i++) {
      await settleLobby(tester, 5);
      await shoot(tester, key, tag('in'));
    }
    for (var i = 0; i < 6; i++) {
      await settleLobby(tester, 5);
      await shoot(tester, key, tag(ready.value ? 'land' : 'hold'));
    }
    await settleLobby(tester, 30);
    await shoot(tester, key, tag('page'));
    Navigator.of(emblem.currentContext!).pop();
    for (var i = 0; i < 7; i++) {
      await settleLobby(tester, 4);
      await shoot(tester, key, tag('back'));
    }
    expect(OrbBaseSkin.values, contains(skin));
    await save.dispose(tester);
  });

  // CHANGE TEAM carries three cases up into the picker's team row; two more
  // are chosen there, and CHOOSE TEAM carries all five down into the
  // lobby's slots, frame by frame.
  testWidgets('team flight', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    phone(tester);
    final save = await LobbySave.create(
      tester,
      team: const ['own-1', 'own-2', 'own-3'],
    );
    final key = GlobalKey();
    await open(tester, save, key);
    var n = 0;
    String tag(String s) => 'flight_${(n++).toString().padLeft(2, '0')}_$s';
    await shoot(tester, key, tag('lobby'));

    await tester.tap(find.byKey(const ValueKey('survival.changeTeam')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      await shoot(tester, key, tag('up'));
    }
    await settleLobby(tester, 20);
    for (final id in ['own-4', 'own-5']) {
      await tester.tap(find.byKey(ValueKey(id)).hitTestable().first);
      await settleLobby(tester, 3);
    }
    await shoot(tester, key, tag('picked'));

    await tester.tap(find.byKey(const ValueKey('partyPicker.confirm')));
    for (var i = 0; i < 16; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 55));
      await shoot(tester, key, tag('down'));
    }
    await settleLobby(tester, 10);
    await shoot(tester, key, tag('landed'));
    expect(tester.takeException(), isNull);
    await save.dispose(tester);
  });

  testWidgets('survival lobby with a team chosen', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    phone(tester);

    final save = await LobbySave.create(tester, team: kLobbyTeam);
    final key = GlobalKey();
    // Tests turn BoxShadows off; the phone draws them. Back on for the
    // pictures, and off again before the test ends (the binding checks).
    debugDisableShadows = false;
    try {
      await open(tester, save, key);
      await shoot(tester, key, '1_team_chosen');

      tester.view.physicalSize = Size(kLobbyPhysical.width, 600 * kLobbyDpr);
      await settleLobby(tester, 4);
      final scroll = lobbyScroll(tester);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await settleLobby(tester, 4);
      await shoot(tester, key, '2_scrolled');
      scroll.position.jumpTo(0);
      tester.view.physicalSize = kLobbyPhysical;
      await settleLobby(tester, 4);

      await growToFit(tester);
      await shoot(tester, key, '3_full_length');
    } finally {
      debugDisableShadows = true;
    }

    await save.dispose(tester);
  });

  testWidgets('survival lobby with no team yet', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    phone(tester);

    final save = await LobbySave.create(tester);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await open(tester, save, key);
      await shoot(tester, key, '4_empty_team');
    } finally {
      debugDisableShadows = true;
    }

    await save.dispose(tester);
  });

  testWidgets('survival lobby on the Fold cover at 1.3x text', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(344 * kLobbyDpr, 882 * kLobbyDpr);
    tester.view.devicePixelRatio = kLobbyDpr;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final save = await LobbySave.create(tester, team: kLobbyTeam);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await open(tester, save, key);
      final extent = lobbyScroll(tester).position.maxScrollExtent;
      tester.view.physicalSize = Size(
        344 * kLobbyDpr,
        (882 + extent + 2) * kLobbyDpr,
      );
      await settleLobby(tester, 4);
      expect(tester.takeException(), isNull);
      await shoot(tester, key, '6_fold_cover');
    } finally {
      debugDisableShadows = true;
    }

    await save.dispose(tester);
  });

  testWidgets('survival lobby on a fresh save', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    phone(tester);

    final save = await LobbySave.create(tester, fresh: true);
    final key = GlobalKey();
    debugDisableShadows = false;
    try {
      await open(tester, save, key);
      await growToFit(tester);
      await shoot(tester, key, '5_fresh_save');
    } finally {
      debugDisableShadows = true;
    }

    await save.dispose(tester);
  });
}
