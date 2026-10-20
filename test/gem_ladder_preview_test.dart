@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/providers/selected_party.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/screens/battle/battle_screen.dart';
import 'package:alchemons/screens/stadium/stadium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'survival_lobby_harness.dart';

// The Emerald Cup's battle ladder from the Trials: the GEMS shelf on
// Emerald, the round's two fours, START, the fight, and back.
//
//   LADDER_OUT=/tmp/ladder flutter test test/gem_ladder_preview_test.dart \
//     --tags preview
//   [LADDER_FIGHT=1]  also fights round 1 and films it into <out>/fight

class _PlainFont extends ThemeNotifier {
  _PlainFont(super.db);

  @override
  TextTheme Function(TextTheme) get currentTextThemeFn =>
      (t) => t;
}

void main() {
  final out = Platform.environment['LADDER_OUT'];

  setUpAll(loadLobbyFonts);

  testWidgets('the ladder from the Trials', (tester) async {
    if (out == null) return;
    Directory('$out/fight').createSync(recursive: true);
    tester.view.physicalSize = kLobbyPhysical;
    tester.view.devicePixelRatio = kLobbyDpr;
    addTearDown(tester.view.reset);
    final save = await LobbySave.create(tester);
    // Silver won and the other two gem cups done: the Trials open on
    // Emerald.
    SharedPreferences.setMockInitialValues({
      RaceProgress.prefsKey:
          '{"copper":3,"silver":3,"ruby":5,"sapphire_course":5}',
    });
    final key = GlobalKey();
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
        child: save.app(shot: key, home: const StadiumScreen()),
      ),
    );
    var n = 0;
    Future<void> shot(String name, {double ratio = 1.2}) async {
      tester.takeException();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await settleLobby(tester, 30);
    for (var i = 0; i < 4 && find.text('CONTINUE').evaluate().isNotEmpty; i++) {
      await tester.tap(find.text('CONTINUE'));
      await settleLobby(tester, 8);
    }
    await tester.tap(find.text('GEMS'));
    await settleLobby(tester, 16);
    await precacheLobbyImages(tester);
    await settleLobby(tester, 8);
    expect(find.text('HORNS AND KIN'), findsWidgets);
    expect(find.text('YOUR FOUR'), findsOneWidget);
    expect(find.text('THEIR FOUR'), findsOneWidget);
    expect(find.text('WITH FRIENDS'), findsNothing);
    await shot('emerald');
    // The last round, locked.
    await tester.tap(find.text('THE LAST FOUR'));
    await settleLobby(tester, 30);
    await shot('emerald_last');
    // The other two, each with its own five (the shelf's trophies are
    // painted: tapped where they stand).
    for (final (cup, x) in [('ruby', 80.0), ('sapphire', 200.0)]) {
      await tester.tapAt(Offset(x, 170));
      await settleLobby(tester, 30);
      await shot(cup);
    }
    await tester.tapAt(const Offset(358, 170));
    await settleLobby(tester, 30);
    await tester.tap(find.text('HORNS AND KIN').first);
    await settleLobby(tester, 10);

    if (Platform.environment['LADDER_FIGHT'] == '1') {
      await tester.tap(find.text('START'));
      for (var i = 0; i < 95 * 30; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        if (i % 10 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        if (i % 45 == 0) {
          await shot('fight/f${(n++).toString().padLeft(3, '0')}', ratio: 0.7);
        }
        if (find.text('BACK TO THE TRIALS').evaluate().isNotEmpty) break;
      }
      expect(find.byType(BattleScreen), findsOneWidget);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot('result');
      await tester.tap(find.text('BACK TO THE TRIALS'), warnIfMissed: false);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(find.byType(BattleScreen), findsNothing);
      await shot('after');
    }
    await save.dispose(tester);
  });
}
