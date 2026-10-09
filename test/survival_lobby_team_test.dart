// The survival lobby's team, its layout contract, and START.
//
//   flutter test test/survival_lobby_team_test.dart

import 'package:alchemons/games/cosmic_survival/components/survival_lobby_stage.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

void main() {
  setUpAll(loadLobbyFonts);

  void phone(WidgetTester tester, {double top = 0}) {
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    tester.view.padding = FakeViewPadding(top: top * kLobbyDpr);
    addTearDown(tester.view.reset);
  }

  BracketButton start(WidgetTester tester) => tester.widget<BracketButton>(
    find.byKey(const ValueKey('survival.start')),
  );

  testWidgets('the lobby is up on the first frame, its core where the '
      'contract says', (tester) async {
    phone(tester, top: 28);
    final save = await LobbySave.create(tester);
    final revealReady = ValueNotifier<bool>(false);
    await tester.pumpWidget(save.app(revealReady: revealReady));

    expect(lobbyShown(), isTrue);
    expect(find.byType(SurvivalLobbyStage), findsOneWidget);
    expect(revealReady.value, isTrue);

    final screen = tester.view.physicalSize / kLobbyDpr;
    const pad = EdgeInsets.only(top: 28);
    final stage = tester.getRect(find.byType(SurvivalLobbyStage));
    expect(stage, survivalLobbyStageRect(screen, pad));
    final orb = survivalLobbyOrbFor(screen, pad);
    expect(orb.centre, stage.center);
    expect(orb.centre.dy, 28 + kSurvivalLobbyHeaderHeight + stage.height / 2);
    expect(
      orb.radius,
      closeTo(
        SurvivalLobbyScene.coreRadius * SurvivalLobbyScene.fitScale(stage.size),
        1e-9,
      ),
    );

    await save.dispose(tester);
  });

  testWidgets('with no team, five empty slots and what to do', (tester) async {
    phone(tester);
    final save = await LobbySave.create(tester);
    await tester.pumpWidget(save.app());
    await settleLobby(tester, 8);

    expect(
      find.text('Choose up to five Alchemons to take into the run.'),
      findsOneWidget,
    );
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('CHOOSE TEAM'), findsOneWidget);
    // Nothing to take in yet: START is not lit.
    expect(start(tester).primary, isFalse);
    expect(tester.takeException(), isNull);

    await save.dispose(tester);
  });

  testWidgets('the saved team comes back, less any that have gone', (
    tester,
  ) async {
    phone(tester);
    final save = await LobbySave.create(
      tester,
      team: const ['own-1', 'released-long-ago', 'own-3'],
    );
    await tester.pumpWidget(save.app());
    await settleLobby(tester, 10);

    expect(find.text('WATERLET'), findsOneWidget);
    expect(find.text('POISONHORN'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('CHANGE TEAM'), findsOneWidget);
    expect(
      find.text('Choose up to five Alchemons to take into the run.'),
      findsNothing,
    );
    expect(start(tester).primary, isTrue);
    expect(await savedLobbyTeam(tester, save), ['own-1', 'own-3']);
    expect(tester.takeException(), isNull);

    await save.dispose(tester);
  });

  testWidgets('with no team START opens the picker, and choosing only sets '
      'the team', (tester) async {
    phone(tester);
    final save = await LobbySave.create(tester);
    await tester.pumpWidget(save.app());
    await settleLobby(tester, 8);

    await tester.tap(find.byKey(const ValueKey('survival.start')));
    await settleLobby(tester, 20);
    final picker = tester.widget<PartyPickerScreen>(
      find.byType(PartyPickerScreen),
    );
    expect(picker.initialSelection, isNull);
    expect(picker.maxSelections, 5);
    expect(picker.confirmLabel, 'Choose Team');
    Finder pickerShows(String text) => find.descendant(
      of: find.byType(PartyPickerScreen),
      matching: find.text(text),
    );

    // The picker's grid fills from a database stream, in an order the test
    // does not fix (they were all made in the same instant): take the first
    // two on screen.
    const names = [
      'WATERLET',
      'LAVAPIP',
      'POISONHORN',
      'EARTHMANE',
      'FIREMASK',
    ];
    List<String> onScreen() => [
      for (final n in names)
        if (find.text(n).hitTestable().evaluate().isNotEmpty) n,
    ];
    for (var i = 0; i < 60 && onScreen().length < 2; i++) {
      await settleLobby(tester, 1);
    }
    for (final name in onScreen().take(2)) {
      await tester.tap(find.text(name).hitTestable().first);
      await settleLobby(tester, 2);
    }
    expect(pickerShows('2 / 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('partyPicker.confirm')));
    await settleLobby(tester, 20);

    // Back in the lobby with the team shown and saved; nothing started.
    expect(find.byType(PartyPickerScreen), findsNothing);
    expect(lobbyShown(), isTrue);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is GameWidget), findsNothing);
    expect(start(tester).primary, isTrue);
    final chosen = await savedLobbyTeam(tester, save);
    expect(chosen, hasLength(2));

    // CHANGE TEAM opens the picker on the team already chosen.
    await tester.tap(find.byKey(const ValueKey('survival.changeTeam')));
    await settleLobby(tester, 20);
    expect(
      tester
          .widget<PartyPickerScreen>(find.byType(PartyPickerScreen))
          .initialSelection,
      chosen,
    );
    expect(pickerShows('2 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await save.dispose(tester);
  });

  testWidgets('START carries the team into the run', (tester) async {
    phone(tester);
    final save = await LobbySave.create(tester, team: kLobbyTeam);
    await tester.pumpWidget(
      ChangeNotifierProvider<AudioController>.value(
        value: SilentAudio(),
        child: save.app(),
      ),
    );
    await settleLobby(tester, 10);

    await tester.tap(find.byKey(const ValueKey('survival.start')));
    await tester.pump(const Duration(milliseconds: 33));

    CosmicSurvivalGame game() =>
        tester
                .widget<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .game!
            as CosmicSurvivalGame;

    // The run is built at once, held under the lobby while the core moves.
    expect(game().party.length, 5);
    expect(game().paused, isTrue);
    expect(game().entranceCoreHidden, isTrue);
    expect(find.byType(SurvivalLobbyStage), findsOneWidget);

    // Partway: the core is still on its way, the run still held.
    for (var ms = 33; ms < 900; ms += 33) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(game().paused, isTrue);

    // Landed, the arena fades in with the run playing under it; then the
    // run has the core and the lobby is gone.
    var playingBeforeLobbyLeft = false;
    for (var ms = 900; ms < 4000 && lobbyShown(); ms += 33) {
      await tester.pump(const Duration(milliseconds: 33));
      if (!game().paused && lobbyShown()) playingBeforeLobbyLeft = true;
    }
    expect(playingBeforeLobbyLeft, isTrue);
    expect(find.byType(SurvivalLobbyStage), findsNothing);
    expect(lobbyShown(), isFalse);
    expect(game().paused, isFalse);
    expect(game().entranceCoreHidden, isFalse);
    expect(find.text('WAVE 1'), findsOneWidget);

    // The camera glides from the core out to the ship and lets go.
    final zoomAtRelease = game().cameraZoom;
    expect(zoomAtRelease, closeTo(CosmicSurvivalGame.entranceZoom, 0.01));
    final core = game().worldToScreen(game().orb.position);
    final size = tester.view.physicalSize / kLobbyDpr;
    expect((core - size.center(Offset.zero)).distance, lessThan(1));
    for (var ms = 0; ms < 2000; ms += 33) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(game().cameraZoom, lessThan(zoomAtRelease));
    final ship = game().worldToScreen(game().ship.position);
    expect((ship - size.center(Offset.zero)).distance, lessThan(1));
    expect(tester.takeException(), isNull);

    await save.dispose(tester);
  });
}
