import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/games/wilderness/ship_landing.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The cosmic ship in the Valley: it comes down (the camera turning to it),
// can't be claimed until it has landed, and once claimed it takes off and
// is cleared — it used to just vanish.
void main() {
  Future<SceneGame> openValley(WidgetTester tester) async {
    tester.view.physicalSize = const Size(751, 475) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final game = SceneGame(scene: valleySceneCorrected)..fieldHourOverride = 12;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 751, height: 475, child: GameWidget(game: game)),
      ),
    );
    for (var i = 0; i < 40 && !game.isLoaded; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    game.update(1 / 60);
    return game;
  }

  void run(SceneGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  testWidgets('the ship lands, then lifts off and is cleared when claimed', (
    tester,
  ) async {
    final game = await openValley(tester);
    var burns = 0, landings = 0;
    final camBefore = game.cameraX;
    game.placeShipBeaconAt(
      'SP_valley_06',
      onTap: () {},
      flyIn: true,
      onBurn: () => burns++,
      onCrashLanded: () => landings++,
    );
    run(game, 0.1);
    final ship = game.debugShipBeacon!;
    expect(ship.isMounted, isTrue);
    expect(ship.landed, isFalse);
    // Not claimable in the air.
    expect(ship.containsLocalPoint(ship.size / 2), isFalse);

    run(
      game,
      ShipLandingComponent.leadIn + ShipLandingComponent.descentTime + 0.5,
    );
    expect(ship.landed, isTrue);
    expect(burns, 1);
    expect(landings, 1);
    // The camera came round to the landing.
    expect(game.cameraX, isNot(closeTo(camBefore, 1)));

    var gone = 0;
    game.launchShipBeacon(onGone: () => gone++);
    run(game, ShipLandingComponent.liftTime * 0.5);
    // Still there, on its way up — not snapped out of existence.
    expect(game.debugShipBeacon, same(ship));
    expect(ship.landed, isFalse);
    expect(gone, 0);

    run(game, 5);
    expect(gone, 1);
    expect(ship.gone, isTrue);
    expect(game.debugShipBeacon, isNull);
    expect(ship.isMounted, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a ship restored from a save is simply there, claimable', (
    tester,
  ) async {
    final game = await openValley(tester);
    var taps = 0;
    game.placeShipBeaconAt('SP_valley_06', onTap: () => taps++);
    run(game, 0.1);
    final ship = game.debugShipBeacon!;
    expect(ship.landed, isTrue);
    expect(taps, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
