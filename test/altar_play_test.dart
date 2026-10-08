// THE ALTARS, played by hand: creatures dragged onto an altar's seats, FUSE,
// AGAIN giving every move back, and the level solved in par.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_progress.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('drag two onto the altar, fuse, start again, solved', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
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

    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
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
          home: AltarPlayScreen(number: 1, progress: progress),
        ),
      ),
    );
    await settle(12);
    final s = tester.state<AltarPlayScreenState>(find.byType(AltarPlayScreen));

    Future<void> dragOn() async {
      final [a, b] = s.debugState.units.toList();
      for (final (u, side) in [(a, 0), (b, 1)]) {
        final from = s.debugUnit(u.id);
        final g = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 16));
        final to = s.debugSeat(0, side);
        for (var k = 1; k <= 8; k++) {
          await g.moveTo(Offset.lerp(from, to, k / 8)!);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await settle(8);
      }
    }

    Future<void> playOut() async {
      for (var i = 0; i < 400 && s.debugBusy; i++) {
        await settle(1);
      }
      await settle(8);
    }

    await dragOn();
    expect(s.debugMoves, 0, reason: 'seating is free');
    await tester.tapAt(s.debugFuse(0));
    await settle(4);
    expect(s.debugMoves, 1);
    await playOut();
    expect(s.debugWon, isTrue);

    // AGAIN gives the move back and the two come back apart.
    await settle(40);
    await tester.tap(find.text('AGAIN'));
    await settle(8);
    expect(s.debugMoves, 0);
    expect(s.debugState.units, hasLength(2));
    expect(s.debugWon, isFalse);

    await dragOn();
    await tester.tapAt(s.debugFuse(0));
    await playOut();
    expect(s.debugWon, isTrue);
    expect(progress.starsOf(1), 3);

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('UNDO gives a fusion back, creatures and count', (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final n = kAltarLevels.indexWhere((l) => l.par >= 2) + 1;
    final level = kAltarLevels[n - 1];

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
    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 33));
      }
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CreatureCatalog>.value(value: catalog),
          Provider<FactionTheme>.value(value: FactionTheme.scorchForge()),
        ],
        child: MaterialApp(home: AltarPlayScreen(number: n, progress: progress)),
      ),
    );
    await settle(12);
    final s = tester.state<AltarPlayScreenState>(find.byType(AltarPlayScreen));
    final before = s.debugState.key;

    // The proof's first move, by tapping: one, its seat; the other, its seat.
    final m = RegExp(r'^(.+?) \+ (.+?) → .+?(?: on altar (\d+)|, the goal)')
        .firstMatch(altarSolve(level).plan.first)!;
    final ai = int.parse(m.group(3) ?? '1') - 1;
    final a = s.debugState.units.firstWhere((u) => u.name == m.group(1));
    final b = s.debugState.units.firstWhere((u) => u.name == m.group(2) && u.id != a.id);
    await tester.tapAt(s.debugUnit(a.id));
    await settle(2);
    await tester.tapAt(s.debugSeat(ai, 0));
    await settle(8);
    await tester.tapAt(s.debugUnit(b.id));
    await settle(2);
    await tester.tapAt(s.debugSeat(ai, 1));
    await settle(8);
    await tester.tapAt(s.debugFuse(ai));
    await settle(4);
    for (var i = 0; i < 400 && s.debugBusy; i++) {
      await settle(1);
    }
    expect(s.debugMoves, 1);
    expect(s.debugState.key, isNot(before));

    await tester.tap(find.byTooltip('Undo'));
    await settle(8);
    expect(s.debugMoves, 0);
    expect(s.debugState.key, before);

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
