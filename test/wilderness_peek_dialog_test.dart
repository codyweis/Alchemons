// The peek previews what is waiting in a biome. It used to list creature names
// as text; the whole point is to show the creatures.

import 'package:alchemons/screens/wilderness_peek_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<PeekedSpawn> spawns,
  VoidCallback? onReset,
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WildernessPeekDialog(
          biomeName: 'Verdant Valley',
          spawns: spawns,
          onResetSpawns: onReset,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const one = [PeekedSpawn(rarityName: 'rare', fallbackId: 'emberlet')];

  testWidgets('names the biome and counts what was found', (tester) async {
    await _pump(tester, spawns: one);
    expect(find.text('Verdant Valley'), findsOneWidget);
    expect(find.text('1 SPECIMEN DETECTED'), findsOneWidget);
  });

  testWidgets('pluralises the count', (tester) async {
    await _pump(
      tester,
      spawns: const [
        PeekedSpawn(rarityName: 'rare', fallbackId: 'a'),
        PeekedSpawn(rarityName: 'common', fallbackId: 'b'),
      ],
    );
    expect(find.text('2 SPECIMENS DETECTED'), findsOneWidget);
  });

  testWidgets('an unresolved species falls back to its id, not a crash', (
    tester,
  ) async {
    await _pump(tester, spawns: one);
    expect(find.text('emberlet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a spawn with no roll at all still renders', (tester) async {
    await _pump(tester, spawns: const [PeekedSpawn(rarityName: 'unknown')]);
    expect(find.text('Unknown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the reset action', () {
    testWidgets('is labelled RESET SPAWNS, not CLEAR', (tester) async {
      await _pump(tester, spawns: one, onReset: () {});
      expect(find.text('RESET SPAWNS'), findsOneWidget);
      expect(find.text('CLEAR'), findsNothing);
    });

    testWidgets('is absent when the caller offers no reset', (tester) async {
      await _pump(tester, spawns: one);
      expect(find.text('RESET SPAWNS'), findsNothing);
      expect(find.text('CLOSE'), findsOneWidget);
    });

    testWidgets('fires exactly once when tapped', (tester) async {
      var calls = 0;
      await _pump(tester, spawns: one, onReset: () => calls++);
      await tester.tap(find.text('RESET SPAWNS'));
      await tester.pump();
      expect(calls, 1);
    });
  });

  testWidgets('a long label does not overflow a 320dp phone', (tester) async {
    // "RESET SPAWNS" is wide enough to burst the narrow slot it started in.
    await _pump(
      tester,
      spawns: one,
      onReset: () {},
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long spawn list scrolls rather than overflowing', (
    tester,
  ) async {
    // The old dialog used a fixed 220px box: dead space for two spawns, and
    // clipped at eight.
    await _pump(
      tester,
      spawns: [
        for (var i = 0; i < 12; i++)
          PeekedSpawn(rarityName: 'common', fallbackId: 'spawn_$i'),
      ],
      onReset: () {},
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('12 SPECIMENS DETECTED'), findsOneWidget);
  });

  test('rarity colours are distinct per tier', () {
    final seen = <Color>{};
    for (final r in ['legendary', 'rare', 'uncommon', 'common']) {
      expect(seen.add(WildernessPeekDialog.rarityColor(r)), isTrue, reason: r);
    }
    // Case should not matter — rarity arrives from an enum name.
    expect(
      WildernessPeekDialog.rarityColor('LEGENDARY'),
      WildernessPeekDialog.rarityColor('legendary'),
    );
  });
}
