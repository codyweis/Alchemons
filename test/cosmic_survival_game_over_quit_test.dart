// A finished survival run used to offer only ways to start another one, which
// left the back gesture as the sole exit. These pin QUIT onto the results panel
// and require it to stay on screen on a short landscape phone — the actions sit
// outside the scroll view precisely so a long reward list cannot bury them.
//
// A run that has NOT finished is left with SAVE & EXIT in the pause menu: the
// run is kept to continue (survival_suspended_run.dart) and nothing is paid
// out — no loot, no silver or gold, no mastery — until it ends.

import 'package:alchemons/games/cosmic_survival/components/cosmic_survival_game_over_panel.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

void main() {
  LootOpeningEntry entry(int i) => LootOpeningEntry(
    icon: AppIcons.inventory_2_rounded,
    name: 'Reward $i',
    label: 'x$i',
    color: const Color(0xFFC4A35A),
  );

  Future<void> pump(
    WidgetTester tester, {
    required Size logical,
    int rewardCount = 0,
  }) async {
    tester.view.physicalSize = Size(logical.width * 2, logical.height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CosmicSurvivalGameOverPanel(
          wave: 12,
          kills: 340,
          score: 98230,
          time: '07:41',
          rewards: [for (var i = 1; i <= rewardCount; i++) entry(i)],
          onQuit: () {},
          onNewTeam: () {},
          onReplay: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('results offer a way out beside the retry actions', (
    tester,
  ) async {
    await pump(tester, logical: const Size(900, 460));

    expect(find.text('QUIT'), findsOneWidget);
    expect(find.text('DEPLOY AGAIN'), findsOneWidget);
    expect(find.text('NEW TEAM'), findsOneWidget);
  });

  testWidgets('QUIT stays on screen at 460 with a long reward list', (
    tester,
  ) async {
    await pump(tester, logical: const Size(900, 460), rewardCount: 10);

    final rect = tester.getRect(find.text('QUIT'));
    expect(rect.bottom, lessThanOrEqualTo(460));
    expect(rect.top, greaterThanOrEqualTo(0));
    // The retry actions share the row, so none of them may be clipped either.
    expect(
      tester.getRect(find.text('DEPLOY AGAIN')).bottom,
      lessThanOrEqualTo(460),
    );
  });

  testWidgets('QUIT is tappable and fires once', (tester) async {
    var quits = 0;
    tester.view.physicalSize = const Size(1560, 760);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CosmicSurvivalGameOverPanel(
          wave: 3,
          kills: 20,
          score: 100,
          time: '01:00',
          rewards: [entry(1), entry(2)],
          onQuit: () => quits++,
          onNewTeam: () {},
          onReplay: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('QUIT'));
    await tester.pump();
    expect(quits, 1);
  });

  group('SAVE & EXIT from the pause menu', () {
    setUpAll(loadLobbyFonts);

    testWidgets('keeps the run, pays nothing, and the lobby offers CONTINUE', (
      tester,
    ) async {
      tester.view.physicalSize = kLobbyPhysical;
      tester.view.devicePixelRatio = kLobbyDpr;
      addTearDown(tester.view.reset);
      final save = await LobbySave.create(tester, team: kLobbyTeam);
      Map<CreatureFamily, int> mastery() => {
        for (final f in CreatureFamily.values)
          f: save.mastery.lifetimePointsFor(f),
      };
      Future<Map<String, int>?> coins() => tester.runAsync<Map<String, int>>(
        () => save.db.currencyDao.getAllCurrencies(),
      );
      Future<SuspendedSurvivalRun?> kept() =>
          tester.runAsync<SuspendedSurvivalRun?>(
            () => SuspendedRunStore(save.db).load(),
          );
      final masteryBefore = mastery();
      final coinsBefore = await coins();

      await tester.pumpWidget(
        ChangeNotifierProvider<AudioController>.value(
          value: SilentAudio(),
          child: save.app(),
        ),
      );
      await settleLobby(tester, 10);
      await tester.tap(find.byKey(const ValueKey('survival.start')));
      for (var ms = 0; ms < 4000 && lobbyShown(); ms += 33) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      await settleLobby(tester, 4);
      final game =
          tester
                  .widget<GameWidget>(
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .game!
              as CosmicSurvivalGame;

      // The run is kept from its first frame.
      final checkpoint = await kept();
      expect(checkpoint, isNotNull);
      expect(checkpoint!.wave, 1);

      // Paused, and hurt below the checkpoint.
      await tester.tap(find.byKey(const ValueKey('survival.pause')));
      await settleLobby(tester, 4);
      game.orb.currentHp = checkpoint.orbHp - 120;

      // The question is asked in brass — leaving costs nothing — and STAY
      // stays.
      await tester.tap(find.byKey(const ValueKey('survival.saveExit')));
      await settleLobby(tester, 4);
      expect(find.text('SAVE & EXIT?'), findsOneWidget);
      expect(
        tester
            .widget<BracketButton>(find.widgetWithText(BracketButton, 'STAY'))
            .accent,
        kLeaveQuietAccent,
      );
      await tester.tap(find.text('STAY'));
      await settleLobby(tester, 4);
      expect(lobbyShown(), isFalse);

      await tester.tap(find.byKey(const ValueKey('survival.saveExit')));
      await settleLobby(tester, 4);
      await tester.tap(find.widgetWithText(BracketButton, 'SAVE & EXIT'));
      await settleLobby(tester, 8);

      // Back in the lobby, the run waiting.
      expect(lobbyShown(), isTrue);
      expect(find.byWidgetPredicate((w) => w is GameWidget), findsNothing);
      expect(find.text('CONTINUE · WAVE 1'), findsOneWidget);
      final left = await kept();
      expect(left!.wave, 1);
      expect(left.orbHp, checkpoint.orbHp - 120);
      expect(left.party.map((m) => m.instanceId), kLobbyTeam);

      // Nothing paid out.
      expect(mastery(), masteryBefore);
      expect(await coins(), coinsBefore);
      expect(tester.takeException(), isNull);

      await save.dispose(tester);
    });
  });
}
