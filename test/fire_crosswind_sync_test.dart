// There are two winds in the Fire dungeon. The burn keeps its own on
// BurnField.wind and an Air Alchemon swings it. `gardenWind` belonged to the
// vine-bed garden THE BURN replaced, and is only turned by _turnGardenWind —
// which sits behind an `if (room.vineBeds.isEmpty) return false` that is now
// always true.
//
// The on-screen crosswind arrow renders gardenWindVector, so it sat on its
// default east forever while the wind the puzzle actually uses swung freely
// underneath. Reported from a device playtest: "doesn't seem the arrow turns
// when the wind changes".

import 'package:alchemons/games/planet_dungeon/burn_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the two wind enums agree quarter for quarter', () {
    // The sync copies BurnWind.index straight into gardenWind, which is only
    // correct while both read 0 N, 1 E, 2 S, 3 W.
    expect(BurnWind.values.map((w) => w.name).toList(), [
      'north',
      'east',
      'south',
      'west',
    ]);
    expect(BurnWind.north.index, 0);
    expect(BurnWind.east.index, 1);
    expect(BurnWind.south.index, 2);
    expect(BurnWind.west.index, 3);
  });

  test('quarterRight walks the compass in order and wraps', () {
    var w = BurnWind.north;
    final seen = <BurnWind>[];
    for (var i = 0; i < 5; i++) {
      seen.add(w);
      w = w.quarterRight;
    }
    expect(seen, [
      BurnWind.north,
      BurnWind.east,
      BurnWind.south,
      BurnWind.west,
      BurnWind.north,
    ]);
  });

  test('each quarter carries the delta its arrow implies', () {
    // If these ever disagree the arrow would point one way while fire ran
    // another, which is worse than an arrow that never moves.
    expect(BurnWind.north.delta, (0, -1));
    expect(BurnWind.east.delta, (1, 0));
    expect(BurnWind.south.delta, (0, 1));
    expect(BurnWind.west.delta, (-1, 0));
  });
}
