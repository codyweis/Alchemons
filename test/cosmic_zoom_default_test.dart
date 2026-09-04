// WHERE SPACE OPENS. The zoom has three settings and it used to arrive at
// the closest of them, which shows a couple of planets and none of the shape
// of the place.
//
// Locked here because it is one integer with no other consumer: the HUD
// reads the level off the game, so nothing else would notice it drifting.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('space opens at the middle zoom, not the closest', () {
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 1),
      onMeterChanged: () {},
    );
    expect(
      game.currentZoomLevel,
      1,
      reason: '0 is the closest of the three and 2 is the farthest',
    );
  });
}
