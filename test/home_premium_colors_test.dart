import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/customization_menu_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The premium home colours (Void, Radiant): shown on the HOME tab with what
// they cost, unlockable only with every element in hand, selectable once
// owned, and kept across a save.

Widget _lab({
  required HomePlanet planet,
  required Map<String, double> stored,
  void Function(String)? onUnlock,
  void Function(String?)? onSelect,
}) => MaterialApp(
  home: Scaffold(
    body: CustomizationMenuOverlay(
      customizationState: HomeCustomizationState(),
      elementStorage: ElementStorage(stored: stored),
      homePlanet: planet,
      onTryRecipe: (_) {},
      onToggleRecipe: (_) {},
      onOptionChanged: (_, _, _) {},
      onUpgradeSize: () {},
      onSelectSize: (_) {},
      onUnlockColor: onUnlock ?? (_) {},
      onSelectColor: onSelect ?? (_) {},
      onClose: () {},
      cargoLevel: 0,
      isNearHome: true,
      onUpgradeCargo: () {},
      onChambers: () {},
      onUpgradePowerUp: (_) {},
      onGarrison: () {},
      initialTab: 1,
    ),
  ),
);

Future<void> _reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('both premium colours show, with their costs, on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _lab(planet: HomePlanet(position: Offset.zero), stored: const {}),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, 'RADIANT LIGHT');
    expect(find.text('VOID BLACK'), findsOneWidget);
    expect(find.text('400 Dark'), findsOneWidget);
    expect(find.text('400 Light'), findsOneWidget);
    expect(find.text('LOCKED'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlocking needs every element, not just some', (tester) async {
    tester.view.physicalSize = const Size(880, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final asked = <String>[];
    // Plenty of Dark, none of the Spirit or Blood Void also needs.
    await tester.pumpWidget(
      _lab(
        planet: HomePlanet(position: Offset.zero),
        stored: const {'Dark': 9999},
        onUnlock: asked.add,
      ),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, 'VOID BLACK');
    await tester.tap(find.text('VOID BLACK'));
    await tester.pumpAndSettle();
    expect(asked, isEmpty);

    await tester.pumpWidget(
      _lab(
        planet: HomePlanet(position: Offset.zero),
        stored: const {'Dark': 400, 'Spirit': 200, 'Blood': 150},
        onUnlock: asked.add,
      ),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, 'VOID BLACK');
    expect(find.text('UNLOCK'), findsWidgets);
    await tester.tap(find.text('VOID BLACK'));
    await tester.pumpAndSettle();
    expect(asked, ['Void']);
  });

  testWidgets('an owned premium colour selects, and shows as current', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(880, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final picked = <String?>[];
    await tester.pumpWidget(
      _lab(
        planet: HomePlanet(
          position: Offset.zero,
          activeColor: 'Radiant',
          unlockedColors: {'Radiant', 'Void'},
        ),
        stored: const {},
        onSelect: picked.add,
      ),
    );
    await tester.pumpAndSettle();
    // The current colour reads by its name, not a missing element.
    expect(find.text('RADIANT LIGHT'), findsWidgets);
    await _reveal(tester, 'VOID BLACK');
    await tester.tap(find.text('VOID BLACK'));
    await tester.pumpAndSettle();
    expect(picked, ['Void']);
    expect(tester.takeException(), isNull);
  });

  test('a premium colour survives a save, and tints as its swatch', () {
    final planet = HomePlanet(
      position: const Offset(100, 200),
      activeColor: 'Void',
      unlockedColors: {'Void', 'Fire'},
    );
    final back = HomePlanet.deserialise(planet.serialise());
    expect(back.activeColor, 'Void');
    expect(back.unlockedColors, containsAll(['Void', 'Fire']));
    expect(back.blendedColor, premiumHomeColor('Void')!.swatch);
    expect(homeColorSwatch('Fire'), kElementColors['Fire']);
    expect(homeColorSwatch(null), const Color(0xFF607D8B));
    // A colour id nobody knows falls back rather than throwing.
    expect(homeColorSwatch('Nonsense'), const Color(0xFF607D8B));
  });
}
