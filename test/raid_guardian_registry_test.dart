// kRaidGuardianIds used to be a second hand-maintained map beside
// kPlanetDungeonLayouts, naming the same six mystics. A copy like that can
// only drift: build a dungeon, forget the map, and the planet is enterable but
// silently unraidable. With eleven elements still to author that is eleven
// chances to miss it, so the raid list is now derived from the layouts.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the derivation reproduces what was hand-maintained', () {
    // Pinned so deriving it did not quietly change any guardian.
    expect(kRaidGuardianIds, {
      'Air': 'Roc',
      'Fire': 'Simurgh',
      'Water': 'Leviathan',
      'Earth': 'Terradon',
      'Lightning': 'Raikuma',
      'Steam': 'Boilrog',
    });
  });

  test('every authored dungeon can be raided', () {
    // The property that matters going forward: a new dungeon brings its raid
    // with it, with no second edit.
    for (final element in kPlanetDungeonLayouts.keys) {
      expect(
        kRaidGuardianIds.containsKey(element),
        isTrue,
        reason: '$element has a dungeon but no raid guardian',
      );
    }
  });

  test('no raid exists for an element with no dungeon', () {
    for (final element in kRaidGuardianIds.keys) {
      expect(kPlanetDungeonLayouts.containsKey(element), isTrue);
    }
  });

  test('every raid guardian has a name, and they are all distinct', () {
    final names = kRaidGuardianIds.values.toList();
    expect(names.any((n) => n.trim().isEmpty), isFalse);
    expect(names.toSet().length, names.length, reason: 'duplicate mystic');
  });

  test('every raid element builds a usable arena', () {
    for (final element in kRaidGuardianIds.keys) {
      final layout = buildRaidArenaLayout(element);
      expect(layout.rooms.length, 1, reason: element);
      expect(layout.entranceRoom.guardian, isNotNull, reason: element);
    }
  });
}
