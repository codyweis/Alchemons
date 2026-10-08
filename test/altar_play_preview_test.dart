@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_progress.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/heart_puzzle/altar_levels_screen.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// THE ALTARS on a phone: each chosen level played through its proof with
// real taps (seat, seat, FUSE; SPLIT), shot at the start, mid-moment and
// after every move, and the result.
//
//   ALTARS_OUT=/tmp/altars ALTARS_LEVELS=1,12,30 flutter test \
//     test/altar_play_preview_test.dart --tags preview
//
// ALTARS_SIZE=412x900 picks the screen (logical px).
void main() {
  final out = Platform.environment['ALTARS_OUT'];

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

  testWidgets('altars preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final size = (Platform.environment['ALTARS_SIZE'] ?? '412x900')
        .split('x')
        .map(double.parse)
        .toList();
    tester.view.physicalSize = Size(size[0] * 3, size[1] * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    late CreatureCatalog catalog;
    late AltarProgress progress;
    await tester.runAsync(() async {
      final json =
          jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
              as Map<String, dynamic>;
      catalog = CreatureCatalog.fromList([
        for (final c in json['creatures'] as List)
          Creature.fromJson(c as Map<String, dynamic>),
      ]);
      progress = await AltarProgress.load();
    });

    final key = GlobalKey();
    Future<void> shoot(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    final levels = (Platform.environment['ALTARS_LEVELS'] ?? '1')
        .split(',')
        .map(int.parse)
        .toList();
    for (final n in levels) {
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
            home: AltarPlayScreen(key: ValueKey(n), number: n, progress: progress),
          ),
        ),
      );
      // Past the opening: the realm up, the word gathered, the hand in.
      await settle(50);
      final s = tester.state<AltarPlayScreenState>(find.byType(AltarPlayScreen));
      await shoot('L${n}_0_start');

      final level = kAltarLevels[n - 1];
      final plan = altarSolve(level).plan;
      var step = 0;
      for (final move in plan) {
        step++;
        AltarUnit byName(String name, {String? not}) => s.debugState.units
            .firstWhere((u) => u.name == name && u.id != not);
        if (move.startsWith('split ')) {
          final u = byName(move.substring(6));
          await tester.tapAt(s.debugUnit(u.id));
          await settle(2);
          await tester.tapAt(s.debugSplit);
          await settle(8);
          await tester.tapAt(s.debugSplitButton);
        } else {
          final m = RegExp(r'^(.+?) \+ (.+?) → .+?(?: on altar (\d+)|, the goal)').firstMatch(move)!;
          final ai = int.parse(m.group(3) ?? '1') - 1;
          final a = byName(m.group(1)!);
          final b = byName(m.group(2)!, not: a.id);
          await tester.tapAt(s.debugUnit(a.id));
          await settle(2);
          await tester.tapAt(s.debugSeat(ai, 0));
          await settle(8);
          await tester.tapAt(s.debugUnit(b.id));
          await settle(2);
          await tester.tapAt(s.debugSeat(ai, 1));
          await settle(10);
          if (step == 1) await shoot('L${n}_${step}a_seated');
          await tester.tapAt(s.debugFuse(ai));
        }
        // Mid-moment, then to its end.
        await settle(40);
        await shoot('L${n}_${step}b_moment');
        for (var i = 0; i < 400 && s.debugBusy; i++) {
          await settle(1);
          if (i == 20 || i == 45 || i == 70) await shoot('L${n}_${step}w$i');
        }
        await settle(12);
        await shoot('L${n}_${step}c_done');
      }
      await settle(40);
      expect(s.debugWon, isTrue, reason: 'level $n: ${plan.join(' / ')}');
      expect(s.debugMoves, level.par);
      await shoot('L${n}_9_result');
    }

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('altars level select preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'altars.stars.v1': jsonEncode({
        for (var n = 1; n <= 13; n++) '$n': n % 4 == 0 ? 2 : (n % 5 == 0 ? 1 : 3),
      }),
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      Provider<FactionTheme>.value(
        value: FactionTheme.scorchForge(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child!),
          home: const AltarLevelsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 33));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/levels.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
