// Free battles from the Trials: the header's BATTLE beside RACES and GEMS
// opens the battle hub's page (the arena live, your four, the computer's
// four, the record, BATTLE), locked until the Silver Cup is won as the gem
// cups are. The first time a battle is opened — there, in the debug hub or
// at the Emerald Cup's ladder — the rules come up once, and never again.

import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/battle/battle_hub_screen.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'survival_lobby_harness.dart';

class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}

/// The rules' first page is up.
bool _rulesShown() =>
    find.textContaining('You bring four Alchemons').evaluate().isNotEmpty;

/// Pages through the rules to their OK.
Future<void> _readRules(WidgetTester tester) async {
  for (var i = 0; i < 4 && find.text('NEXT').evaluate().isNotEmpty; i++) {
    await tester.tap(find.text('NEXT'));
    await settleLobby(tester, 4);
  }
  expect(find.textContaining('most health left wins'), findsOneWidget);
  await tester.tap(find.text('OK'));
  await settleLobby(tester, 6);
  expect(_rulesShown(), isFalse);
}

void main() {
  Future<LobbySave> open(
    WidgetTester tester, {
    required String progress,
    Widget home = const StadiumScreen(),
  }) async {
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final save = await LobbySave.create(tester);
    SharedPreferences.setMockInitialValues({RaceProgress.prefsKey: progress});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AudioController>.value(value: SilentAudio()),
          ChangeNotifierProvider<SelectedPartyNotifier>(
            create: (_) => SelectedPartyNotifier(),
          ),
          ChangeNotifierProvider<ThemeNotifier>(
            create: (_) => _PlainFont(save.db),
          ),
        ],
        child: save.app(home: home),
      ),
    );
    await settleLobby(tester, 16);
    // Cups won before their rewards were shown: their cards first.
    for (var i = 0; i < 4 && find.text('CONTINUE').evaluate().isNotEmpty; i++) {
      await tester.tap(find.text('CONTINUE'));
      await settleLobby(tester, 6);
    }
    return save;
  }

  Future<bool> seen(WidgetTester tester, LobbySave save) async =>
      (await tester.runAsync(save.db.settingsDao.hasSeenBattleHowTo))!;

  testWidgets('BATTLE waits for the Silver Cup, and says so', (tester) async {
    final save = await open(tester, progress: '{"copper":3,"silver":1}');
    expect(find.text('RACES'), findsOneWidget);
    expect(find.text('GEMS'), findsOneWidget);
    await tester.tap(find.text('BATTLE'));
    await settleLobby(tester, 16);
    expect(find.text('Win the Silver Cup to open battles.'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('YOUR FOUR'), findsOneWidget);
    // Nothing to fight yet, so no rules either.
    expect(_rulesShown(), isFalse);
    expect(await seen(tester, save), isFalse);
    await save.dispose(tester);
  });

  testWidgets('BATTLE opens the hub page, the rules once', (tester) async {
    final save = await open(tester, progress: '{"copper":3,"silver":3}');
    await tester.tap(find.text('BATTLE'));
    await settleLobby(tester, 16);
    // The first time: the rules over the page.
    expect(_rulesShown(), isTrue);
    await _readRules(tester);
    expect(await seen(tester, save), isTrue);

    // The hub's page: the arena row, the two fours, the record, BATTLE.
    expect(find.text('ARENA'), findsOneWidget);
    expect(find.text('YOUR FOUR'), findsOneWidget);
    expect(find.text('AGAINST THE COMPUTER'), findsOneWidget);
    expect(find.text('NO BATTLES YET'), findsOneWidget);
    expect(find.text('RULES'), findsOneWidget);
    expect(find.byKey(const ValueKey('battle.arena.orrery')), findsOneWidget);
    expect(find.byType(BattleCase), findsNWidgets(8));
    expect(find.text('LOCKED'), findsNothing);
    expect(find.byKey(const ValueKey('battle.start')), findsOneWidget);

    // Back to the races and again: no rules this time.
    await tester.tap(find.text('RACES'));
    await settleLobby(tester, 16);
    expect(find.text('YOUR FOUR'), findsNothing);
    await tester.tap(find.text('BATTLE'));
    await settleLobby(tester, 16);
    expect(find.text('AGAINST THE COMPUTER'), findsOneWidget);
    expect(_rulesShown(), isFalse);

    // RULES reads them again on purpose.
    await tester.tap(find.text('RULES'));
    await settleLobby(tester, 6);
    expect(_rulesShown(), isTrue);
    await _readRules(tester);
    await save.dispose(tester);
  });

  testWidgets('the Emerald ladder asks once too, then the hub does not', (
    tester,
  ) async {
    // Ruby and Sapphire done: GEMS opens on Emerald, the battle ladder.
    final save = await open(
      tester,
      progress: '{"copper":3,"silver":3,"ruby":5,"sapphire_course":5}',
    );
    await tester.tap(find.text('GEMS'));
    await settleLobby(tester, 16);
    expect(find.text('THEIR FOUR'), findsOneWidget);
    expect(_rulesShown(), isTrue);
    await _readRules(tester);
    // Off and on again: once was enough.
    await tester.tap(find.text('RACES'));
    await settleLobby(tester, 12);
    await tester.tap(find.text('GEMS'));
    await settleLobby(tester, 12);
    expect(_rulesShown(), isFalse);
    // Nor at BATTLE.
    await tester.tap(find.text('BATTLE'));
    await settleLobby(tester, 16);
    expect(find.text('AGAINST THE COMPUTER'), findsOneWidget);
    expect(_rulesShown(), isFalse);
    await save.dispose(tester);
  });

  testWidgets('the debug hub shows the rules the first time only', (
    tester,
  ) async {
    final save = await open(
      tester,
      progress: '{}',
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BattleHubScreen()),
          ),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await settleLobby(tester, 20);
    expect(find.text('YOUR FOUR'), findsOneWidget);
    expect(_rulesShown(), isTrue);
    await _readRules(tester);
    expect(await seen(tester, save), isTrue);

    // Out and back in: straight to the hub.
    Navigator.of(tester.element(find.text('YOUR FOUR'))).pop();
    await settleLobby(tester, 12);
    await tester.tap(find.text('go'));
    await settleLobby(tester, 20);
    expect(find.text('YOUR FOUR'), findsOneWidget);
    expect(_rulesShown(), isFalse);
    await save.dispose(tester);
  });
}
