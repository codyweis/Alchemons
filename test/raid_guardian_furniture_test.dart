// Each guardian's identity lives in the props its dungeon room carries: Roc
// drags its storm-cell across a rod field, Simurgh re-lights braziers and the
// ORDER is the bullet pattern. The raid arena is generated and carried none of
// it, so every mechanic bailed on `room.stormRods.isEmpty` and friends — and
// all six raids played as the same charging phantom.
//
// The arena now generates the furniture its guardian reads. That matters more
// as dungeons are added: eleven elements are still to author, and each brings
// a raid with it.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the arena carries what its guardian needs', () {
    test('Air gets a rod field for Roc to be led across', () {
      final room = buildRaidArenaLayout('Air').entranceRoom;
      expect(room.stormRods.length, greaterThanOrEqualTo(4));
    });

    test('Fire gets braziers for Simurgh to re-light', () {
      final room = buildRaidArenaLayout('Fire').entranceRoom;
      // The telegraph needs at least two to form a pattern.
      expect(room.braziers.length, greaterThanOrEqualTo(2));
    });

    test('the brazier order is a complete sweep, not arbitrary', () {
      // The order IS the bullet pattern, so gaps or repeats would read as a
      // stutter in the telegraph.
      final b = buildRaidArenaLayout('Fire').entranceRoom.braziers;
      final orders = b.map((x) => x.order).toList()..sort();
      expect(orders, List.generate(b.length, (i) => i));
    });

    test('rods are ranked by height, so the field can be climbed', () {
      final rods = buildRaidArenaLayout('Air').entranceRoom.stormRods;
      expect(rods.map((r) => r.initialHeight).toSet().length, greaterThan(1));
    });

    test('rod ids are unique', () {
      final rods = buildRaidArenaLayout('Air').entranceRoom.stormRods;
      expect(rods.map((r) => r.id).toSet().length, rods.length);
    });
  });

  group('furniture is per guardian, not sprayed everywhere', () {
    test('only Air gets rods', () {
      for (final el in kRaidGuardianIds.keys.where((e) => e != 'Air')) {
        expect(
          buildRaidArenaLayout(el).entranceRoom.stormRods,
          isEmpty,
          reason: '$el should not have a rod field',
        );
      }
    });

    test('only Fire gets braziers', () {
      for (final el in kRaidGuardianIds.keys.where((e) => e != 'Fire')) {
        expect(
          buildRaidArenaLayout(el).entranceRoom.braziers,
          isEmpty,
          reason: '$el should not have braziers',
        );
      }
    });

    test('a raid arena still has no puzzle plumbing', () {
      // Braziers are here for the telegraph only. A brazierStarIndex would
      // switch on the lighting puzzle, and a raid has nothing to solve.
      for (final el in kRaidGuardianIds.keys) {
        final room = buildRaidArenaLayout(el).entranceRoom;
        expect(room.brazierStarIndex, isNull, reason: el);
        expect(room.doors, isEmpty, reason: el);
        expect(room.conduits, isEmpty, reason: el);
      }
    });
  });

  test('all furniture sits inside the arena bounds', () {
    for (final el in kRaidGuardianIds.keys) {
      final room = buildRaidArenaLayout(el).entranceRoom;
      final b = room.bounds.deflate(40);
      for (final r in room.stormRods) {
        expect(b.contains(r.position), isTrue, reason: '$el rod ${r.id}');
      }
      for (final z in room.braziers) {
        expect(b.contains(z.position), isTrue, reason: '$el brazier ${z.order}');
      }
    }
  });
}
