import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/screens/scenes/rift_threshold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rift {
  _Rift({this.keys = 1, this.gold = 20, this.harvesters, this.silver = 40});

  int keys;
  int gold;

  /// Harvesters that fit what is inside; null asks for none.
  int? harvesters;
  int silver;
  int spent = 0;
  int entered = 0;
  bool stealKey = false;

  Widget build() => MaterialApp(
    home: RiftThreshold(
      faction: RiftFaction.oceanic,
      closesIn: '3h 5m',
      loadKeys: () async => keys,
      spendKey: () async {
        if (stealKey) keys = 0;
        if (keys <= 0) return false;
        keys--;
        spent++;
        return true;
      },
      onEnter: () async => entered++,
      loadGold: () async => gold,
      keyPrice: 5,
      buyKey: () async {
        if (gold < 5) return false;
        gold -= 5;
        keys++;
        return true;
      },
      harvester: harvesters == null
          ? null
          : RiftHarvesterNeed(
              fitting: const ['Volcanic', 'Stabilized'],
              biome: 'volcanic',
              load: () async => harvesters!,
              loadWallet: () async => {'silver': silver, 'res_volcanic': 9},
              price: const {'silver': 25, 'res_volcanic': 5},
              buy: () async {
                if (silver < 25) return false;
                silver -= 25;
                harvesters = harvesters! + 1;
                return true;
              },
            ),
    ),
  );
}

Future<void> _frames(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 1 / 30) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1720,
      720,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 2;
  });

  testWidgets('holding turns the key, spends one, and goes in', (
    tester,
  ) async {
    final rift = _Rift(keys: 2);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('OCEANIC KEY  ×2'), findsOneWidget);

    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO TURN THE KEY')),
    );
    await _frames(tester, 1.1);
    await hold.up();
    expect(rift.spent, 1);
    expect(rift.entered, 0, reason: 'the key flies and the fall plays first');

    await _frames(tester, 2.0);
    expect(rift.entered, 1);
    expect(rift.keys, 1);
  });

  testWidgets('letting go early spends nothing', (tester) async {
    final rift = _Rift(keys: 1);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO TURN THE KEY')),
    );
    await _frames(tester, 0.5);
    await hold.up();
    await _frames(tester, 1.5);
    expect(rift.spent, 0);
    expect(rift.entered, 0);
    expect(find.text('HOLD TO TURN THE KEY'), findsOneWidget);
  });

  testWidgets('without a key, one can be bought here', (tester) async {
    final rift = _Rift(keys: 0, gold: 12);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('NO OCEANIC KEY'), findsOneWidget);
    expect(find.text('The rift stays open for 3h 5m.'), findsOneWidget);

    await tester.tap(find.text('BUY A KEY  ·  5'));
    await _frames(tester, 0.2);
    expect(rift.gold, 7);
    expect(find.text('OCEANIC KEY  ×1'), findsOneWidget);
    expect(find.text('HOLD TO TURN THE KEY'), findsOneWidget);
  });

  testWidgets('not enough gold says so and buys nothing', (tester) async {
    final rift = _Rift(keys: 0, gold: 3);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('NEEDS 5'), findsOneWidget);
    await tester.tap(find.text('NEEDS 5'));
    await _frames(tester, 0.2);
    expect(rift.gold, 3);
    expect(rift.keys, 0);
  });

  testWidgets('a key that has gone is not spent twice', (tester) async {
    final rift = _Rift(keys: 1)..stealKey = true;
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO TURN THE KEY')),
    );
    await _frames(tester, 1.1);
    await hold.up();
    await _frames(tester, 2.5);
    expect(rift.entered, 0);
    expect(find.text('That key is gone. Buy another to enter.'), findsOneWidget);
    expect(find.text('NO OCEANIC KEY'), findsOneWidget);
  });

  testWidgets('without a harvester that fits, the key does not turn', (
    tester,
  ) async {
    final rift = _Rift(keys: 1, harvesters: 0);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('NO HARVESTER'), findsOneWidget);
    expect(
      find.text('Only Volcanic or Stabilized Harvesters can catch the '
          'Alchemon inside.'),
      findsOneWidget,
    );
    expect(find.text('HOLD TO TURN THE KEY'), findsNothing);
  });

  testWidgets('a harvester bought here lets the key turn', (tester) async {
    final rift = _Rift(keys: 1, harvesters: 0);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    await tester.tap(find.text('BUY VOLCANIC  ·  '));
    await _frames(tester, 0.2);
    expect(rift.silver, 15);
    expect(rift.harvesters, 1);
    expect(find.text('NO HARVESTER'), findsNothing);

    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO TURN THE KEY')),
    );
    await _frames(tester, 1.1);
    await hold.up();
    await _frames(tester, 2.0);
    expect(rift.spent, 1);
    expect(rift.entered, 1);
  });

  testWidgets('short of silver, no harvester is bought', (tester) async {
    final rift = _Rift(keys: 1, harvesters: 0, silver: 10);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('NEEDS  '), findsOneWidget);
    await tester.tap(find.text('NEEDS  '));
    await _frames(tester, 0.2);
    expect(rift.silver, 10);
    expect(rift.harvesters, 0);
    expect(find.text('HOLD TO TURN THE KEY'), findsNothing);
  });

  testWidgets('with neither, the key is asked for first', (tester) async {
    final rift = _Rift(keys: 0, harvesters: 0);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('NO OCEANIC KEY'), findsOneWidget);
    expect(find.text('NO HARVESTER'), findsNothing);

    await tester.tap(find.text('BUY A KEY  ·  5'));
    await _frames(tester, 0.2);
    expect(find.text('NO HARVESTER'), findsOneWidget);
    expect(find.text('HOLD TO TURN THE KEY'), findsNothing);
  });

  testWidgets('holding a harvester that fits asks for nothing more', (
    tester,
  ) async {
    final rift = _Rift(keys: 1, harvesters: 2);
    await tester.pumpWidget(rift.build());
    await _frames(tester, 0.2);
    expect(find.text('NO HARVESTER'), findsNothing);
    expect(find.text('HOLD TO TURN THE KEY'), findsOneWidget);
  });
}
