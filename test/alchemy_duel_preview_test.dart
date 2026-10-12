@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_boards.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_match.dart';
import 'package:alchemons/games/heart_puzzle/alchemy_duel_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ALCHEMY FOR TWO on a phone: a match on DUEL_BOARD (or the first that ends
// in a win) played with real drags and taps — shot at the start, after each
// move, mid-fusion, as the word goes up, and the result — and the level
// select's TWO PLAYERS band (shown with the developer tools on).
//
//   DUEL_OUT=/tmp/duel [DUEL_BOARD=3] flutter test \
//     test/alchemy_duel_preview_test.dart --tags preview
//
// DUEL_SIZE=412x900 picks the screen (logical px).
void main() {
  final out = Platform.environment['DUEL_OUT'];

  Future<void> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer))))
        .load();
  }

  setUpAll(() async {
    await loadFont('monospace', '/System/Library/Fonts/Supplemental/Andale Mono.ttf');
    await loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  (List<DuelStep>, DuelEnd) line(DuelBoard b) {
    final solver = DuelSolver(b);
    var p = duelStart(b);
    final steps = <DuelStep>[];
    while (duelOutcome(b, p) == null) {
      final g = solver.graded(p);
      final win = g.where((x) => x.$2 == 1).firstOrNull;
      final step = win?.$1 ??
          (p.toMove == 0 ? g.firstWhere((x) => x.$2 == 0).$1 : g.first.$1);
      steps.add(step);
      p = step.next;
    }
    return (steps, duelOutcome(b, p)!);
  }

  testWidgets('duel preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final size = (Platform.environment['DUEL_SIZE'] ?? '412x900')
        .split('x')
        .map(double.parse)
        .toList();
    tester.view.physicalSize = Size(size[0] * 3, size[1] * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'debug.developer_tools_enabled': true,
    });

    final asked = int.tryParse(Platform.environment['DUEL_BOARD'] ?? '');
    var number = asked ?? 1;
    var moves = line(kDuelBoards[number - 1]).$1;
    if (asked == null) {
      for (var n = 1; n <= kDuelBoards.length; n++) {
        final (l, end) = line(kDuelBoards[n - 1]);
        if (end != DuelEnd.draw && l.every((s) => !s.pass)) {
          number = n;
          moves = l;
          break;
        }
      }
    }

    late CreatureCatalog catalog;
    await tester.runAsync(() async {
      final json =
          jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
    });

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> run(double seconds) async {
      for (var i = 0; i < (seconds / .033).round(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 6)));
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: AltarPlayScreen.duel(duel: DuelMatch(number: number)),
        ),
      ),
    );
    await run(2.5);
    await shoot('d00_start');
    final s = tester.state<AltarPlayScreenState>(find.byType(AltarPlayScreen));

    Future<void> drag(String id, Offset to) async {
      final from = s.debugUnit(id);
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 16));
      for (var k = 1; k <= 8; k++) {
        await g.moveTo(Offset.lerp(from, to, k / 8)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await run(.3);
    }

    var i = 0;
    for (final step in moves) {
      i++;
      if (step.split != null) {
        await drag(step.split!.id, s.debugSplit);
        await shoot('d${i}a_seated');
        await tester.tapAt(s.debugSplitButton);
      } else {
        final (a, b) = step.pair!;
        await drag(a.id, s.debugSeat(step.altar, 0));
        await drag(b.id, s.debugSeat(step.altar, 1));
        await shoot('d${i}a_seated');
        await tester.tapAt(s.debugFuse(step.altar));
      }
      await run(1.4);
      await shoot('d${i}b_moment');
      for (var k = 0; k < 300 && s.debugBusy && !s.debugWon; k++) {
        await run(.1);
      }
      await run(.6);
      await shoot('d${i}c_after');
    }
    for (var k = 0; k < 8; k++) {
      await run(.4);
      await shoot('d9_win$k');
    }
    await run(2);
    await shoot('d9_result');

    // The level select, with its band for two.
    final db = AlchemonsDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AlchemonsDatabase>.value(value: db),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const AltarLevelsScreen(),
        ),
      ),
    );
    await run(.6);
    await shoot('l0_band');

    await tester.pumpWidget(const SizedBox());
    for (var k = 0; k < 4; k++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.runAsync(() => db.close());
  });
}
