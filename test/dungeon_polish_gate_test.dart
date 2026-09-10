// BUILT is not POLISHED, and only POLISHED is descendable.
//
// All seventeen dungeons are built and the suite is green on all of them —
// which is exactly the problem. Every fault that has mattered on a first
// descent (arrivals that strand you, a door on the wrong wall, art that reads
// as something it is not) came out of a device session, never out of a test
// that already existed. So the unpolished ten keep their gate ritual and show
// the coming-soon placard instead of DESCEND.
//
// docs/dungeons.md §7.9 is canonical. This pins the code against it.

import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';

void main() {
  test('the polished set is the seven that have had the pass', () {
    expect(kPolishedDungeons, {
      'Fire',
      'Air',
      'Water',
      'Earth',
      'Lightning',
      'Steam',
      'Lava',
    });
  });

  test('every polished dungeon is actually built', () {
    for (final element in kPolishedDungeons) {
      expect(
        kPlanetDungeonLayouts.containsKey(element),
        isTrue,
        reason: '$element is marked polished but has no layout',
      );
      expect(
        kCosmicPlanetEntry.containsKey(element),
        isTrue,
        reason: '$element is marked polished but has no entry requirement',
      );
      expect(dungeonIsPlayable(element), isTrue);
      expect(dungeonIsComingSoon(element), isFalse);
    }
  });

  test('every built-but-unpolished planet reads as coming soon', () {
    final unpolished = kPlanetDungeonLayouts.keys.where(
      (e) => !kPolishedDungeons.contains(e),
    );
    expect(unpolished, isNotEmpty, reason: 'the gate would be pointless');
    for (final element in unpolished) {
      expect(
        dungeonIsPlayable(element),
        isFalse,
        reason: '$element has not had the polish pass but offers DESCEND',
      );
      expect(dungeonIsComingSoon(element), isTrue);
      // It keeps the gate ritual — the offering can still be made.
      expect(isDungeonGatePlanet(element), isTrue);
    }
  });

  test('a planet is never both playable and coming soon', () {
    for (final element in kPlanetDungeonLayouts.keys) {
      expect(
        dungeonIsPlayable(element) && dungeonIsComingSoon(element),
        isFalse,
        reason: '$element is in both states',
      );
    }
  });
}
