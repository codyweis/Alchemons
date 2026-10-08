import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/screens/cosmic/widgets/mini_map_overlay.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The star chart opens already framed on the ship: its zoom is set before
// its first frame is painted, not a frame or two later, which showed as a
// jump in the middle of the chart's fade.
void main() {
  testWidgets('the chart is framed on the ship from its first frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await tester.runAsync(() => game.onLoad());
    game.onGameResize(Vector2(412, 915));
    for (final p in game.world_.planets) {
      p.discovered = true;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: MiniMapOverlay(
          world: game.world_,
          game: game,
          theme: FactionTheme.scorchForge(),
          markers: const [],
          dungeonStarsFor: (_) => null,
          dungeonStarTotal: 0,
          dungeonStarMax: 51,
          onTeleport: (_) {},
          onNavigatePlanet: (_) {},
          onGoHome: () {},
          onClose: () {},
          onMarkersChanged: (_) {},
        ),
      ),
    );
    // One frame only.
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final zoom = viewer.transformationController!.value.getMaxScaleOnAxis();
    expect(zoom, closeTo(1.25, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home leads the planet carousel and NAVIGATE HOME goes home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    await tester.runAsync(() => game.onLoad());
    game.onGameResize(Vector2(412, 915));
    for (final p in game.world_.planets) {
      p.discovered = true;
    }
    game.homePlanet = HomePlanet(
      position: game.ship.pos + const Offset(-3600, 2600),
      sizeTierLevel: 2,
      activeSizeTier: 2,
      activeColor: 'Water',
    );
    var home = 0;
    CosmicPlanet? planet;
    await tester.pumpWidget(
      MaterialApp(
        home: MiniMapOverlay(
          world: game.world_,
          game: game,
          theme: FactionTheme.scorchForge(),
          markers: const [],
          dungeonStarsFor: (_) => null,
          dungeonStarTotal: 0,
          dungeonStarMax: 51,
          onTeleport: (_) {},
          onNavigatePlanet: (p) => planet = p,
          onGoHome: () => home++,
          onClose: () {},
          onMarkersChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NAVIGATE HOME'), findsOneWidget);
    await tester.tap(find.text('NAVIGATE HOME'));
    await tester.pump();
    expect(home, 1);
    expect(planet, isNull);
  });
}
