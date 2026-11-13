// THE ALTARS: a second tap on FUSE while the first is still loading what
// it makes is not a second move.

import 'dart:convert';
import 'dart:io';

import 'package:alchemons/games/heart_puzzle/heart_puzzle_progress.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/heart_puzzle/altar_play_screen.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FUSE tapped twice in a hurry is one move', (tester) async {
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

    await dragOn();
    // Two taps before the made creature's body has loaded.
    await tester.tapAt(s.debugFuse(0));
    await tester.tapAt(s.debugFuse(0));
    for (var i = 0; i < 400 && (s.debugBusy || !s.debugWon); i++) {
      await settle(1);
    }
    expect(s.debugWon, isTrue);
    expect(s.debugMoves, 1);
    expect(progress.starsOf(1), 3);

    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
