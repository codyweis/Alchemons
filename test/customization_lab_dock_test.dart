import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/customization_menu_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The lab's one way of doing things: tap something, it docks at the foot of
// the lab with its price and the one thing to do with it.

class _Calls {
  final crafted = <String>[];
  final toggled = <String>[];
  final sized = <int>[];
  var upgradedSize = 0;
}

Widget _lab(
  _Calls calls, {
  required HomeCustomizationState state,
  Map<String, double> stored = const {},
  int tab = 0,
  HomePlanet? planet,
}) => MaterialApp(
  home: Scaffold(
    body: CustomizationMenuOverlay(
      customizationState: state,
      elementStorage: ElementStorage(stored: stored),
      homePlanet: planet ?? HomePlanet(position: Offset.zero, astralBank: 500),
      onTryRecipe: calls.crafted.add,
      onToggleRecipe: calls.toggled.add,
      onOptionChanged: (_, _, _) {},
      onUpgradeSize: () => calls.upgradedSize++,
      onSelectSize: calls.sized.add,
      onUnlockColor: (_) {},
      onSelectColor: (_) {},
      onClose: () {},
      cargoLevel: 0,
      isNearHome: true,
      onUpgradeCargo: () {},
      onUpgradePowerUp: (_) {},
      onGarrison: () {},
      initialTab: tab,
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _settle(tester);
  await tester.tap(target);
  await _settle(tester);
}

Future<void> _act(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('lab.dock.action')));
  await _settle(tester);
}

void main() {

  testWidgets('both tabs lay out on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final tab in [0, 1]) {
      await tester.pumpWidget(
        _lab(_Calls(), state: HomeCustomizationState(), tab: tab),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'tab $tab');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a locked thing keeps its name, shows its price, and crafts', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _lab(
        calls,
        state: HomeCustomizationState(),
        stored: const {'Fire': 999, 'Lightning': 999},
      ),
    );
    await _settle(tester);
    await _tap(tester, 'lab.recipe.storm_bolts');
    expect(find.text('???'), findsOneWidget);
    expect(find.text('CRAFT'), findsOneWidget);
    await _act(tester);
    expect(calls.crafted, ['storm_bolts']);
  });

  testWidgets('a craft the hold cannot pay for does nothing', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_lab(calls, state: HomeCustomizationState()));
    await _settle(tester);
    await _tap(tester, 'lab.recipe.storm_bolts');
    await _act(tester);
    expect(calls.crafted, isEmpty);
  });

  testWidgets('an owned hull equips, and the standard hull takes it off', (
    tester,
  ) async {
    final calls = _Calls();
    final state = HomeCustomizationState(
      unlockedIds: {'skin_solar'},
      activeIds: {'skin_solar'},
    );
    await tester.pumpWidget(_lab(calls, state: state));
    await _settle(tester);
    await _tap(tester, 'lab.hull.standard');
    expect(find.text('EQUIP'), findsOneWidget);
    await _act(tester);
    expect(calls.toggled, ['skin_solar']);
  });

  testWidgets('a built station has nothing to switch', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _lab(
        calls,
        state: HomeCustomizationState(unlockedIds: {'refuel_station'}),
        tab: 1,
      ),
    );
    await _settle(tester);
    await _tap(tester, 'lab.recipe.refuel_station');
    expect(find.text('BUILT'), findsOneWidget);
    await _act(tester);
    expect(calls.toggled, isEmpty);
  });

  testWidgets('an owned size is one tap; the next one docks its price', (
    tester,
  ) async {
    final calls = _Calls();
    await tester.pumpWidget(
      _lab(
        calls,
        state: HomeCustomizationState(),
        tab: 1,
        planet: HomePlanet(
          position: Offset.zero,
          astralBank: 500,
          sizeTierLevel: 1,
          activeSizeTier: 1,
        ),
      ),
    );
    await _settle(tester);
    await _tap(tester, 'lab.size.0');
    expect(calls.sized, [0]);
    await _tap(tester, 'lab.size.2');
    expect(find.text('UNLOCK'), findsOneWidget);
    await _act(tester);
    expect(calls.upgradedSize, 1);
  });
}
