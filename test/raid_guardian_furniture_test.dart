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

    test('Water gets tide zones for Leviathan to haul', () {
      final room = buildRaidArenaLayout('Water').entranceRoom;
      expect(room.tideZones, isNotEmpty);
      // Both stands must exist or the tide has nothing to move between.
      final levels = room.tideZones.map((z) => z.floodedAt).toSet();
      expect(levels, containsAll([1, 2]));
    });

    test('a dry corridor survives high tide', () {
      // A fully flooded arena is unplayable, and unlike the temple there are
      // no authored ledges to retreat to.
      final room = buildRaidArenaLayout('Water').entranceRoom;
      final flooded = room.tideZones.map((z) => z.rect).toList();
      for (final p in [
        const Offset(700, 380), // the guardian
        const Offset(700, 740), // the entrance
        const Offset(700, 500), // between them
      ]) {
        expect(
          flooded.any((r) => r.contains(p)),
          isFalse,
          reason: '$p is under water at high tide',
        );
      }
    });

    test('rod ids are unique', () {
      final rods = buildRaidArenaLayout('Air').entranceRoom.stormRods;
      expect(rods.map((r) => r.id).toSet().length, rods.length);
    });

    test('Air gets the storm cell, and its rods are close enough to climb', () {
      // A bolt hops at most kStormHopReach from conductor to conductor. Six
      // rods round this ring sat 220–300 apart, so no staircase could ever
      // be climbed, and the arena had no storm cell to throw a bolt anyway.
      final room = buildRaidArenaLayout('Air').entranceRoom;
      expect(room.stormOrbit, isNotNull);
      final rods = room.stormRods;
      for (var i = 0; i < rods.length; i++) {
        final next = rods[(i + 1) % rods.length];
        expect(
          (rods[i].position - next.position).distance,
          lessThanOrEqualTo(kStormHopReach),
          reason: '${rods[i].id} to ${next.id}',
        );
      }
      // An Air Alchemon has to raise one: none starts at the top rank.
      expect(rods.every((r) => r.initialHeight < kStormRodMaxHeight), isTrue);
    });

    test('Ice gets the hoarfrost pillar, Mud the mire anchor', () {
      expect(
        buildRaidArenaLayout('Ice').entranceRoom.rime?.hoarfrost,
        isNotNull,
      );
      expect(buildRaidArenaLayout('Mud').entranceRoom.fen?.anchor, isNotNull);
    });

    test('Dust gets the cut, Spirit the chime and its Blood Pip gate', () {
      expect(
        buildRaidArenaLayout('Dust').entranceRoom.ruins?.hollowCut,
        isNotNull,
      );
      final spirit = buildRaidArenaLayout('Spirit');
      expect(spirit.entranceRoom.funeral?.chime, isNotNull);
      final gate = spirit.familyGateFor('vigil_chime');
      expect(gate, isNotNull);
      expect(gate!.element, 'Blood');
    });

    test("Solarin's raid floor: only its shadow is within reach", () {
      // It is struck from two squares off, from its shadow. Stone is never
      // in shadow and never burns, so stone in reach would let it be struck
      // from anywhere on it (the orbit room keeps its ledge and dais out of
      // reach, and so must the arena's landing).
      final def = buildRaidArenaLayout('Light').entranceRoom.hall!.def!;
      for (final o in def.orbit!) {
        for (var y = 0; y < def.rows; y++) {
          for (var x = 0; x < def.cols; x++) {
            if (def.at(x, y) == '~') continue;
            final dx = x - o.x, dy = y - o.y;
            final inReach = dx * dx + dy * dy <= 2.01 * 2.01;
            expect(
              inReach && !'PV'.contains(def.at(x, y)),
              isFalse,
              reason: 'stone at ($x,$y) is in reach of ($o)',
            );
          }
        }
      }
    });

    test('a raid whose guardian needs one kind of Alchemon says so', () {
      for (final el in const [
        'Ice',
        'Mud',
        'Dust',
        'Spirit',
        'Crystal',
        'Plant',
        'Poison',
        'Lightning',
      ]) {
        expect(kRaidOpeningLines[el], isNotNull, reason: el);
      }
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

    test('only Water gets a tide', () {
      for (final el in kRaidGuardianIds.keys.where((e) => e != 'Water')) {
        expect(
          buildRaidArenaLayout(el).entranceRoom.tideZones,
          isEmpty,
          reason: '$el should not have a tide',
        );
      }
    });

    test('only its own planet gets each guardian prop', () {
      for (final el in kRaidGuardianIds.keys) {
        final layout = buildRaidArenaLayout(el);
        final room = layout.entranceRoom;
        if (el != 'Air') expect(room.stormOrbit, isNull, reason: el);
        if (el != 'Ice') expect(room.rime, isNull, reason: el);
        if (el != 'Mud') expect(room.fen, isNull, reason: el);
        if (el != 'Dust') expect(room.ruins, isNull, reason: el);
        if (el != 'Crystal') expect(room.prism, isNull, reason: el);
        if (el != 'Plant') expect(room.grove, isNull, reason: el);
        if (el != 'Light') expect(room.hall, isNull, reason: el);
        if (el != 'Spirit') {
          expect(room.funeral, isNull, reason: el);
          expect(layout.familyGates, isEmpty, reason: el);
        }
      }
    });

    test('only Lightning carries the spike and the one trunk', () {
      for (final el in kRaidGuardianIds.keys) {
        final layout = buildRaidArenaLayout(el);
        if (el == 'Lightning') {
          expect(layout.entranceRoom.coreBreaker, isNotNull);
          expect(layout.dynamoTrunks.single.roomIds, ['raid_arena']);
          expect(layout.initialTrunkId, layout.dynamoTrunks.single.id);
          // No dynamo room: the trunk-select verb stays off.
          expect(layout.dynamoRoomId, isNull);
        } else {
          expect(layout.entranceRoom.coreBreaker, isNull, reason: el);
          expect(layout.dynamoTrunks, isEmpty, reason: el);
        }
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
        expect(
          b.contains(z.position),
          isTrue,
          reason: '$el brazier ${z.order}',
        );
      }
      for (final p in [
        room.rime?.hoarfrost,
        room.fen?.anchor,
        room.ruins?.hollowCut,
        room.funeral?.chime,
        room.coreBreaker,
        room.apothecary?.cistern,
        ...?room.grove?.arenaRings,
      ].nonNulls) {
        expect(b.contains(p), isTrue, reason: '$el prop at $p');
      }
      final floor = room.prism?.choir;
      if (floor != null) {
        for (var c = 0; c < 9; c++) {
          expect(
            room.bounds.contains(floor.plateRect(c).bottomRight),
            isTrue,
            reason: '$el choir plate $c',
          );
        }
        // The heart plate sits under the guardian.
        expect(
          floor.cellAt(room.guardian!.position),
          4,
          reason: '$el heart plate',
        );
      }
    }
  });
}
