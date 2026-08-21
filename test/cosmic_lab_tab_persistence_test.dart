import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/customization_menu_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors how the cosmic screen mounts the lab: it can be torn down entirely
/// (PREVIEW) and rebuilt, with the tab index held outside the overlay.
class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int labTab = 0;
  bool showLab = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: showLab
            ? CustomizationMenuOverlay(
                customizationState: HomeCustomizationState(),
                elementStorage: ElementStorage(stored: const {'Fire': 500}),
                homePlanet: HomePlanet(position: Offset.zero),
                onTryRecipe: (_) {},
                onToggleRecipe: (_) {},
                onOptionChanged: (_, _, _) {},
                onUpgradeSize: () {},
                onSelectSize: (_) {},
                onUnlockColor: (_) {},
                onSelectColor: (_) {},
                onClose: () {},
                cargoLevel: 0,
                isNearHome: true,
                onUpgradeCargo: () {},
                onChambers: () {},
                onUpgradePowerUp: (_) {},
                initialTab: labTab,
                onTabChanged: (i) => labTab = i,
                canPreview: true,
                // PREVIEW tears the overlay down, exactly like the real screen.
                onPreview: () => setState(() => showLab = false),
              )
            : Center(
                child: TextButton(
                  onPressed: () => setState(() => showLab = true),
                  child: const Text('END PREVIEW'),
                ),
              ),
      ),
    );
  }
}

void main() {
  testWidgets('the lab reopens on the tab you left it on', (tester) async {
    tester.view.physicalSize = const Size(880, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();

    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.labTab, 0, reason: 'starts on SHIP');

    // Switch to HOME.
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(host.labTab, 1, reason: 'tab change must reach the host');

    // PREVIEW: the whole overlay is destroyed.
    await tester.tap(find.text('PREVIEW ON PLANET'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomizationMenuOverlay), findsNothing);

    // END PREVIEW: rebuilt from scratch.
    await tester.tap(find.text('END PREVIEW'));
    await tester.pumpAndSettle();

    expect(host.labTab, 1, reason: 'the host kept the tab');
    final state = tester.state<CustomizationMenuOverlayState>(
      find.byType(CustomizationMenuOverlay),
    );
    // The rebuilt overlay must come back on HOME, not snap to SHIP.
    expect(state.activeTabForTest, 1);
  });
}
