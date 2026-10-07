// The raid popup holds CONTINUE until the clear is saved — and it can only
// keep that promise if the Future it is handed is the save itself. Until
// 2026-10-07 the dungeon screen called the clear without awaiting it, so the
// popup waited on nothing (the combat audit's P1). A save that fails must not
// trap the player behind loot that has already landed either.

import 'dart:async';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/planet_dungeon/raid_rewards.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AlchemonsDatabase db;
  setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required Future<void> Function() onGranted,
    required VoidCallback onContinue,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RaidRewardPopup(
                element: 'Fire',
                raidLevel: 1,
                level3ClearsBeforeFight: 0,
                db: db,
                onGranted: onGranted,
                onContinue: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    // Drift runs its queries off the test clock; let them land.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('Continue waits for the clear to be saved', (tester) async {
    final save = Completer<void>();
    var continued = false;
    await pump(
      tester,
      onGranted: () => save.future,
      onContinue: () => continued = true,
    );
    await settle(tester);

    await tester.tap(find.text('RETURN FOR LEVEL 2'));
    await tester.pump();
    expect(continued, isFalse, reason: 'the clear has not been saved yet');

    save.complete();
    await settle(tester);
    await tester.tap(find.text('RETURN FOR LEVEL 2'));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('a save that fails is retried, and never traps the player', (
    tester,
  ) async {
    var attempts = 0;
    var continued = false;
    await pump(
      tester,
      onGranted: () async {
        attempts++;
        throw StateError('disk full');
      },
      onContinue: () => continued = true,
    );
    await settle(tester);
    expect(attempts, 2);

    await tester.tap(find.text('RETURN FOR LEVEL 2'));
    await tester.pump();
    expect(continued, isTrue);
  });
}
