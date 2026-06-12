import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kPlanetDungeonLayouts integrity', () {
    kPlanetDungeonLayouts.forEach((element, layout) {
      group('$element layout', () {
        test('element matches its key', () {
          expect(layout.element, element);
        });

        test('entrance room exists and spawn is inside it', () {
          final room = layout.rooms[layout.entranceRoomId];
          expect(room, isNotNull, reason: 'entrance room must exist');
          expect(
            room!.bounds.contains(layout.entranceSpawn),
            isTrue,
            reason: 'entrance spawn must be inside the entrance room',
          );
        });

        test('every door targets a real room', () {
          for (final room in layout.rooms.values) {
            for (final door in room.doors) {
              expect(
                layout.rooms.containsKey(door.targetRoomId),
                isTrue,
                reason:
                    'door in ${room.id} targets missing room ${door.targetRoomId}',
              );
              final target = layout.rooms[door.targetRoomId]!;
              expect(
                target.bounds.contains(door.targetSpawn),
                isTrue,
                reason:
                    'door spawn into ${door.targetRoomId} must be inside it',
              );
              // Into an open-sky room you must land on a platform, not the void.
              if (target.platforms.isNotEmpty) {
                final onPlatform = target.platforms.any(
                  (p) => p.inflate(2).contains(door.targetSpawn),
                );
                expect(
                  onPlatform,
                  isTrue,
                  reason:
                      'spawn into ${door.targetRoomId} must be on a platform',
                );
              }
            }
          }
        });

        test('star indices are 0..2 and distinct count ≤ 3', () {
          for (final room in layout.rooms.values) {
            for (final s in room.stars) {
              expect(s.starIndex, inInclusiveRange(0, 2));
            }
            if (room.summit != null) {
              expect(room.summit!.starIndex, inInclusiveRange(0, 2));
            }
            if (room.loomStarIndex != null) {
              expect(room.loomStarIndex!, inInclusiveRange(0, 2));
            }
            if (room.guardian != null) {
              expect(room.guardian!.starIndex, inInclusiveRange(0, 2));
            }
          }
          expect(layout.totalStars, lessThanOrEqualTo(3));
        });

        test('AUTHORING RULE: Star 3 is the mystic guardian, and only it', () {
          // Exactly one guardian per dungeon, always carrying star index 2 —
          // the relic drop and raid eligibility both key off this.
          final guardianRooms = layout.rooms.values
              .where((r) => r.guardian != null)
              .toList();
          expect(guardianRooms.length, 1);
          expect(guardianRooms.single.guardian!.starIndex, 2);

          // No other source may award star 2; stars 0 and 1 must both exist
          // from non-guardian sources (the rite gate needs them earnable).
          final nonGuardianStars = <int>{};
          for (final room in layout.rooms.values) {
            for (final s in room.stars) {
              nonGuardianStars.add(s.starIndex);
            }
            if (room.summit != null) {
              nonGuardianStars.add(room.summit!.starIndex);
            }
            if (room.loomStarIndex != null) {
              nonGuardianStars.add(room.loomStarIndex!);
            }
          }
          expect(nonGuardianStars, isNot(contains(2)));
          expect(nonGuardianStars, containsAll([0, 1]));
        });

        test('every door has a way back (no one-way trips)', () {
          for (final room in layout.rooms.values) {
            for (final door in room.doors) {
              final target = layout.rooms[door.targetRoomId];
              expect(
                target?.doors.any((d) => d.targetRoomId == room.id),
                isTrue,
                reason: '${room.id} → ${door.targetRoomId} has no return door',
              );
            }
          }
        });

        test('door spawns never land in a gap', () {
          for (final room in layout.rooms.values) {
            for (final door in room.doors) {
              final target = layout.rooms[door.targetRoomId]!;
              final inGap = target.gaps.any(
                (g) => g.rect.contains(door.targetSpawn),
              );
              expect(
                inGap,
                isFalse,
                reason:
                    'spawn into ${door.targetRoomId} lands in an impassable gap',
              );
            }
          }
        });

        test('vertical door travel lands on the matching side', () {
          // Exiting through a BOTTOM-edge door must never drop you in the
          // bottom of the next room (and top-edge exits never in its top) —
          // that reads as teleporting, not traveling.
          for (final room in layout.rooms.values) {
            for (final door in room.doors) {
              final target = layout.rooms[door.targetRoomId]!;
              final exitsBottom =
                  (room.bounds.bottom - door.rect.bottom).abs() < 40 &&
                  door.rect.width > door.rect.height;
              final exitsTop =
                  (door.rect.top - room.bounds.top).abs() < 40 &&
                  door.rect.width > door.rect.height;
              final arrivalFraction =
                  (door.targetSpawn.dy - target.bounds.top) /
                  target.bounds.height;
              if (exitsBottom) {
                expect(
                  arrivalFraction,
                  lessThan(0.7),
                  reason:
                      '${room.id} bottom exit → ${door.targetRoomId} must not '
                      'arrive at its bottom',
                );
              }
              if (exitsTop) {
                expect(
                  arrivalFraction,
                  greaterThan(0.3),
                  reason:
                      '${room.id} top exit → ${door.targetRoomId} must not '
                      'arrive at its top',
                );
              }
            }
          }
        });

        test('ring orders form one complete 0..n-1 sequence', () {
          final orders = [
            for (final room in layout.rooms.values)
              for (final ring in room.rings) ring.order,
          ]..sort();
          expect(
            orders,
            List.generate(orders.length, (i) => i),
            reason: 'ring orders must be exactly 0..n-1 with no gaps/dupes',
          );
        });

        test('derived anchor types are craftable in their room', () {
          for (final room in layout.rooms.values) {
            for (final an in room.anchors) {
              if (an.requiredCloudType != 'Thundercloud') continue;
              // Thundercloud = carried Anvil + Fire inside a wind current,
              // so the loom room must hold both ingredients.
              expect(
                room.clouds.any((c) => c.cloudType == 'Anvil'),
                isTrue,
                reason: '${room.id}: Thundercloud anchor without an Anvil',
              );
              expect(
                room.currents,
                isNotEmpty,
                reason:
                    '${room.id}: Thundercloud anchor without a wind current '
                    'to ignite in',
              );
            }
          }
        });

        test('arc-only conduits share a room with a wind current', () {
          for (final room in layout.rooms.values) {
            for (final c in room.conduits) {
              if (c.preferred != null) continue; // channelled, not arc-lit
              expect(
                room.currents,
                isNotEmpty,
                reason:
                    'conduit ${c.id} in ${room.id} is arc-only but the room '
                    'has no current for the Fire creature to ignite in',
              );
            }
          }
        });

        test('loom anchors reference clouds present in the room', () {
          for (final room in layout.rooms.values) {
            final cloudTypes = room.clouds.map((c) => c.cloudType).toSet();
            for (final an in room.anchors) {
              // 'Thundercloud' is derived from an Anvil via the air+fire combo.
              final ok =
                  cloudTypes.contains(an.requiredCloudType) ||
                  an.requiredCloudType == 'Thundercloud';
              expect(
                ok,
                isTrue,
                reason:
                    'anchor ${an.id} wants ${an.requiredCloudType} with no source cloud',
              );
            }
          }
        });
      });
    });

    test('Air dungeon has its three star chambers and full 3 stars', () {
      final air = kPlanetDungeonLayouts['Air']!;
      expect(
        air.rooms.keys,
        containsAll([
          'entry',
          'hub',
          'lower_spire',
          'crosswind_hall',
          'cloud_platforms',
          'spire_summit',
          'spiral_cloud',
          'ring_cloud',
          'anvil_cloud',
          'feather_cloud',
          'veil_cloud',
          'sky_loom',
          'relic_chamber',
          'storm_rune_hall',
          'twin_conduit',
          'storm_altar',
          'guardian_summit',
        ]),
      );
      expect(air.starIndices, {0, 1, 2});
      // Storm altar needs a Lightning channel conduit + a guardian.
      final altar = air.rooms['twin_conduit']!;
      expect(
        altar.conduits.any((c) => c.requireElement == 'Lightning'),
        isTrue,
      );
      expect(air.rooms['guardian_summit']!.guardian, isNotNull);
    });
  });
}
