import 'dart:ui' show Offset, Rect;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart'
    show PlanetDungeonGame, MirrorTide, StormCircuit, kSteamStartPressure;
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
            if (room.brazierStarIndex != null) {
              expect(room.brazierStarIndex!, inInclusiveRange(0, 2));
            }
            if (room.vineStarIndex != null) {
              expect(room.vineStarIndex!, inInclusiveRange(0, 2));
            }
          }
          expect(layout.totalStars, lessThanOrEqualTo(3));
        });

        test('brazier orders form one complete 0..n-1 sequence per room', () {
          for (final room in layout.rooms.values) {
            final orders = [for (final b in room.braziers) b.order]..sort();
            expect(
              orders,
              List.generate(orders.length, (i) => i),
              reason:
                  '${room.id}: brazier orders must be exactly 0..n-1 with no '
                  'gaps/dupes',
            );
          }
        });

        test('vine beds and incense chains are well-formed', () {
          for (final room in layout.rooms.values) {
            final bedIds = room.vineBeds.map((b) => b.id).toSet();
            expect(
              bedIds.length,
              room.vineBeds.length,
              reason: '${room.id}: vine bed ids must be unique',
            );
            final chainIds = room.incenseChains.map((c) => c.id).toSet();
            expect(
              chainIds.length,
              room.incenseChains.length,
              reason: '${room.id}: incense chain ids must be unique',
            );
            for (final chain in room.incenseChains) {
              expect(
                chain.nodes.length,
                greaterThanOrEqualTo(2),
                reason:
                    '${room.id}/${chain.id}: a chain needs at least an '
                    'ignition censer and one more to carry the flame to',
              );
              for (final node in chain.nodes) {
                expect(
                  room.bounds.contains(node),
                  isTrue,
                  reason: '${room.id}/${chain.id}: censer outside the room',
                );
              }
              expect(
                room.bounds.contains(chain.bellPosition),
                isTrue,
                reason: '${room.id}/${chain.id}: bell outside the room',
              );
            }
          }
        });

        test('tide verbs are well-formed', () {
          for (final room in layout.rooms.values) {
            for (final valve in room.tideValves) {
              if (valve.level != null) {
                expect(valve.level, inInclusiveRange(0, 2));
              } else {
                expect(
                  valve.pipOnly,
                  isTrue,
                  reason:
                      '${room.id}: a cycling valve (level null) must be a '
                      'pip-only pipe-mouth',
                );
              }
            }
            final sealIds = room.tideSeals.map((s) => s.id).toSet();
            expect(
              sealIds.length,
              room.tideSeals.length,
              reason: '${room.id}: seal ids must be unique',
            );
            for (final seal in room.tideSeals) {
              expect(seal.tides, isNotEmpty);
              for (final t in seal.tides) {
                expect(t, inInclusiveRange(0, 2));
              }
            }
            // The ghost-current network: ids unique, every channel endpoint
            // real, exactly one spring and one sea drain — and every channel
            // clearly east/west so the SPIN rule ("an eddy rolls the way its
            // feeder drives it") is never a coin-flip on screen.
            final nodeIds = <String, Offset>{
              for (final m in room.ghostMouths) m.id: m.position,
              for (final e in room.ghostEddies) e.id: e.position,
            };
            expect(
              nodeIds.length,
              room.ghostMouths.length + room.ghostEddies.length,
              reason: '${room.id}: ghost node ids must be unique',
            );
            if (room.ghostEddies.isNotEmpty) {
              expect(
                room.ghostMouths.where((m) => m.isSource).length,
                1,
                reason: '${room.id}: the current needs exactly one spring',
              );
              expect(
                room.ghostMouths.where((m) => !m.isSource).length,
                1,
                reason: '${room.id}: the current needs exactly one sea drain',
              );
              expect(
                room.ghostChannels,
                isNotEmpty,
                reason: '${room.id}: eddies with no channels between them',
              );
            }
            for (final ch in room.ghostChannels) {
              expect(
                nodeIds.containsKey(ch.a) && nodeIds.containsKey(ch.b),
                isTrue,
                reason: '${room.id}: channel ${ch.a}–${ch.b} names a '
                    'node that does not exist',
              );
              expect(
                (nodeIds[ch.a]!.dx - nodeIds[ch.b]!.dx).abs(),
                greaterThanOrEqualTo(60.0),
                reason: '${room.id}: channel ${ch.a}–${ch.b} is too nearly '
                    'vertical — its feeder must read clearly east or west',
              );
            }
            for (final e in room.ghostEddies) {
              expect(
                room.bounds.contains(e.position),
                isTrue,
                reason: '${room.id}/${e.id}: eddy outside the room',
              );
            }
            for (final m in room.ghostMouths) {
              expect(
                room.bounds.contains(m.position),
                isTrue,
                reason: '${room.id}/${m.id}: mouth outside the room',
              );
            }
            final poolIds = room.moonPools.map((p) => p.id).toSet();
            expect(
              poolIds.length,
              room.moonPools.length,
              reason: '${room.id}: moon-pool ids must be unique',
            );
            if (room.moonPools.isNotEmpty) {
              expect(
                room.moonPools.any((p) => p.isTrue),
                isTrue,
                reason: '${room.id}: at least one pool must hold the moon',
              );
            }
            for (final z in room.tideZones) {
              expect(z.floodedAt, inInclusiveRange(1, 2));
              expect(
                room.bounds.contains(z.rect.center),
                isTrue,
                reason: '${room.id}: tide zone outside the room',
              );
            }
            for (final rule in room.tideDoorRules) {
              expect(
                room.doors.any((d) => d.targetRoomId == rule.targetRoomId),
                isTrue,
                reason:
                    '${room.id}: tide rule for ${rule.targetRoomId} matches '
                    'no door',
              );
              expect(rule.tides, isNotEmpty);
            }
          }
        });

        test('barrow verbs are well-formed', () {
          for (final room in layout.rooms.values) {
            final ribIds = room.fossilRibs.map((r) => r.id).toSet();
            expect(
              ribIds.length,
              room.fossilRibs.length,
              reason: '${room.id}: rib ids must be unique',
            );
            for (final rib in room.fossilRibs) {
              expect(
                rib.notches.length,
                greaterThanOrEqualTo(2),
                reason: '${room.id}/${rib.id}: a track needs ≥2 notches',
              );
              for (final n in rib.notches) {
                expect(
                  room.bounds.contains(n),
                  isTrue,
                  reason: '${room.id}/${rib.id}: notch outside the room',
                );
              }
              // The bridging notch must actually span the chasm.
              if (room.ribChasm != null) {
                final bridgeRect = Rect.fromCenter(
                  center: rib.notches.last,
                  width: rib.width,
                  height: rib.height,
                );
                expect(
                  bridgeRect.left < room.ribChasm!.left &&
                      bridgeRect.right > room.ribChasm!.right,
                  isTrue,
                  reason:
                      '${room.id}/${rib.id}: the last notch must bridge '
                      'the chasm fully',
                );
              }
            }
            if (room.fossilRibs.isNotEmpty) {
              expect(
                room.ribChasm,
                isNotNull,
                reason: '${room.id}: ribs without a chasm to bridge',
              );
              expect(
                room.sternumPlate,
                isNotNull,
                reason: '${room.id}: ribs without a plate to bank the star',
              );
              expect(
                room.ribChasm!.contains(room.sternumPlate!.center),
                isFalse,
                reason: '${room.id}: the plate must lie beyond the chasm',
              );
            }
            final pillarIds = room.fossilPillars.map((p) => p.id).toSet();
            expect(
              pillarIds.length,
              room.fossilPillars.length,
              reason: '${room.id}: pillar ids must be unique',
            );
            final scale = room.stoneScale;
            if (scale != null) {
              final weightIds = scale.weights.map((w) => w.id).toSet();
              expect(weightIds.length, scale.weights.length);
              expect(
                scale.weights.any((w) => w.truePanRight) &&
                    scale.weights.any((w) => !w.truePanRight),
                isTrue,
                reason:
                    '${room.id}: the scale solution must use both pans '
                    '(all-one-side is guessable)',
              );
            }
          }
        });

        test('every dungeon hides exactly one vault cache, inside its room',
            () {
          final cacheRooms = layout.rooms.values
              .where((r) => r.vaultCache != null)
              .toList();
          expect(
            cacheRooms.length,
            1,
            reason: 'each dungeon\'s treasure room holds ONE bottled essence',
          );
          expect(
            cacheRooms.single.bounds.contains(cacheRooms.single.vaultCache!),
            isTrue,
            reason: 'the cache must sit inside its room',
          );
        });

        test('every dungeon carries a 3-line descent riddle', () {
          // One verse line per entry slot — party-picking must be a puzzle
          // the player can reason about at the planet, never a guess.
          expect(layout.riddle.length, kCosmicPlanetEntry[element]?.length);
          for (final line in layout.riddle) {
            expect(line.trim(), isNotEmpty);
          }
        });

        test('layout door refs point at real doors', () {
          bool refExists(DungeonDoorRef ref) {
            final room = layout.rooms[ref.roomId];
            if (room == null) return false;
            return room.doors.any((d) => d.targetRoomId == ref.targetRoomId);
          }

          if (layout.entranceRevealDoor != null) {
            expect(
              refExists(layout.entranceRevealDoor!),
              isTrue,
              reason: 'entranceRevealDoor must match an authored door',
            );
          }
          if (layout.finaleDoor != null) {
            expect(
              refExists(layout.finaleDoor!),
              isTrue,
              reason: 'finaleDoor must match an authored door',
            );
          }
          for (final spec in layout.stars) {
            for (final ref in spec.revealDoors) {
              expect(
                refExists(ref),
                isTrue,
                reason:
                    '${spec.name} reveal door ${ref.roomId} → '
                    '${ref.targetRoomId} must match an authored door',
              );
            }
          }
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
            if (room.brazierStarIndex != null) {
              nonGuardianStars.add(room.brazierStarIndex!);
            }
            if (room.vineStarIndex != null) {
              nonGuardianStars.add(room.vineStarIndex!);
            }
            if (room.sealStarIndex != null) {
              nonGuardianStars.add(room.sealStarIndex!);
            }
            if (room.eddyStarIndex != null) {
              nonGuardianStars.add(room.eddyStarIndex!);
            }
            if (room.ribStarIndex != null) {
              nonGuardianStars.add(room.ribStarIndex!);
            }
            if (room.pillarStarIndex != null) {
              nonGuardianStars.add(room.pillarStarIndex!);
            }
            if (room.circuitStarIndex != null) {
              nonGuardianStars.add(room.circuitStarIndex!);
            }
            if (room.molten?.starIndex != null) {
              nonGuardianStars.add(room.molten!.starIndex!);
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

        // §6.11 REWORK: the wind graph is the SOLVER'S model of the spire, and
        // the collision map is what the player actually walks. If they can
        // drift apart, the no-strand proof proves nothing — so every claim the
        // graph makes is checked against the authored geometry here.
        test('the wind graph and the room geometry agree', () {
          final galeRects = <String, List<Rect>>{};
          for (final room in layout.rooms.values) {
            for (final c in room.currents) {
              final id = c.galeId;
              if (id != null) (galeRects[id] ??= []).add(c.rect);
            }
          }
          bool covers(List<Rect> rects, Rect path) {
            // A swept path must be fully inside the union; with axis-aligned
            // rects, sampling the path's corners and centre is sufficient for
            // the single-rect covers used here, so require one rect to hold it.
            return rects.any(
              (r) =>
                  r.left <= path.left + 0.01 &&
                  r.right >= path.right - 0.01 &&
                  r.top <= path.top + 0.01 &&
                  r.bottom >= path.bottom - 0.01,
            );
          }

          for (final room in layout.rooms.values) {
            final ledges = {for (final l in room.windLedges) l.id: l};
            for (final l in room.windLedges) {
              expect(
                room.platforms.any((p) => p == l.rect),
                isTrue,
                reason: '${room.id}: ledge ${l.id} is not standable footing',
              );
            }
            for (final r in room.windRoutes) {
              expect(ledges.containsKey(r.from), isTrue,
                  reason: '${room.id}: route ${r.id} leaves nowhere');
              expect(ledges.containsKey(r.to), isTrue,
                  reason: '${room.id}: route ${r.id} arrives nowhere');
              final rides = r.ridesGale;
              if (rides == null) {
                expect(
                  room.platforms.any((p) => p == r.path),
                  isTrue,
                  reason:
                      '${room.id}: walkway ${r.id} is not standable footing',
                );
              } else {
                final rects = galeRects[rides];
                expect(rects, isNotNull,
                    reason: '${room.id}: route ${r.id} rides an unauthored '
                        'gale "$rides"');
                expect(
                  rects!.any((g) => g.overlaps(ledges[r.from]!.rect)) &&
                      rects.any((g) => g.overlaps(ledges[r.to]!.rect)),
                  isTrue,
                  reason:
                      '${room.id}: gale "$rides" does not actually connect '
                      '${r.from} to ${r.to}',
                );
              }
              for (final g in r.sweptBy) {
                expect(
                  covers(galeRects[g] ?? const [], r.path),
                  isTrue,
                  reason:
                      '${room.id}: route ${r.id} claims gale "$g" scours it, '
                      'but no rect of that gale covers its path',
                );
              }
              if (r.costly) {
                expect(
                  galeRects.values.any(
                    (rects) => rects.any((g) => g.overlaps(r.path)),
                  ),
                  isTrue,
                  reason:
                      '${room.id}: route ${r.id} claims to cost a fall, but '
                      'no gale touches it',
                );
              }
            }
            for (final s in room.gustShrines) {
              expect(ledges.containsKey(s.ledgeId), isTrue,
                  reason: '${room.id}: shrine ${s.id} stands on no ledge');
              expect(
                ledges[s.ledgeId]!.rect.contains(s.position),
                isTrue,
                reason: '${room.id}: shrine ${s.id} is off its own ledge',
              );
              expect(
                galeRects.containsKey(s.wakesGale),
                isTrue,
                reason: '${room.id}: shrine ${s.id} wakes nothing',
              );
              // THE SOFTLOCK GUARD, at the geometry level: a shrine standing
              // inside a gale that blows through ITS OWN ROOM would become
              // unusable the moment that gale woke — permanently. (A shrine
              // may wake a gale in a distant room; only local wind can bar it.)
              for (final c in room.currents) {
                final id = c.galeId;
                if (id == null) continue;
                expect(
                  c.rect.contains(s.position),
                  isFalse,
                  reason:
                      '${room.id}: shrine ${s.id} stands inside gale "$id" — '
                      'waking it would bar the shrine for the rest of the run',
                );
              }
            }
          }
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

        // §6.11 REWORK: no conduit is arc-lit by hand any more. A conduit the
        // player cannot channel must be one the STORM can reach — and the
        // storm must never be able to reach it without a rod staircase, or
        // there is no puzzle at all.
        test('storm-struck conduits stand in a rod field, out of the '
            'cell\'s own reach', () {
          for (final room in layout.rooms.values) {
            for (final c in room.conduits) {
              if (c.requiredFamily != null) continue; // channelled by hand
              expect(
                c.struckByStorm,
                isTrue,
                reason:
                    'conduit ${c.id} in ${room.id} answers neither a hand nor '
                    'the storm — nothing can ever light it',
              );
              expect(room.stormRods, isNotEmpty,
                  reason: '${room.id}: nothing for the bolt to climb');
              final orbit = room.stormOrbit;
              expect(orbit, isNotNull,
                  reason: '${room.id}: a struck conduit with no storm');
              final gap =
                  (c.position - orbit!.center).distance - orbit.radius;
              expect(
                gap,
                greaterThan(kStormHopReach),
                reason:
                    '${room.id}: the cell passes within a single leap of '
                    'conduit ${c.id} — it would light itself',
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

    test('Fire dungeon has its three star chambers and full 3 stars', () {
      final fire = kPlanetDungeonLayouts['Fire']!;
      expect(
        fire.rooms.keys,
        containsAll([
          'narthex',
          'nave',
          'scriptorium',
          'choir',
          'cloister',
          'reliquary',
          'vestry',
          'bell_gallery',
          'high_altar',
          'sanctum',
        ]),
      );
      expect(fire.starIndices, {0, 1, 2});
      // Star 1: the choir owns the ritual braziers (order is non-spatial).
      final choir = fire.rooms['choir']!;
      expect(choir.braziers.length, 6);
      expect(choir.brazierStarIndex, 0);
      // Star 2: the cloister owns the six-bed garth and its wind-cross.
      final cloister = fire.rooms['cloister']!;
      expect(cloister.vineBeds.length, 6);
      expect(cloister.windVane, isNotNull,
          reason: 'the garth turns its own crosswind');
      expect(cloister.vineStarIndex, 1);
      // Star 3: three bells in the gallery; Simurgh roosts in the sanctum.
      expect(fire.rooms['bell_gallery']!.incenseChains.length, 3);
      final guardian = fire.rooms['sanctum']!.guardian;
      expect(guardian, isNotNull);
      expect(guardian!.encounter?.mysticId, 'Simurgh');
      // The narthex hearth is a standalone entry rite, not a star source.
      expect(fire.rooms['narthex']!.braziers.length, 1);
      expect(fire.rooms['narthex']!.brazierStarIndex, isNull);
    });

    test('Water dungeon has its three star chambers and full 3 stars', () {
      final water = kPlanetDungeonLayouts['Water']!;
      expect(
        water.rooms.keys,
        containsAll([
          'tide_gate',
          'drowned_court',
          'tide_works',
          'ghost_gallery',
          'pearl_vault',
          'reflection_court',
          'moon_hall',
          'moon_well',
          'leviathan_depths',
        ]),
      );
      expect(water.starIndices, {0, 1, 2});
      // Star 1: the tide-works owns the valves and the three sluice seals —
      // one per stand of water.
      final works = water.rooms['tide_works']!;
      expect(works.tideValves.length, 3);
      expect(works.tideSeals.length, 3);
      expect(works.sealStarIndex, 0);
      expect(
        {for (final s in works.tideSeals) s.tides.single},
        {0, 1, 2},
        reason: 'the three seals cover the three tide stands',
      );
      // Star 2: the ghost gallery owns the current — five eddies strung on a
      // network of carved channels between a spring and a sea drain.
      final gallery = water.rooms['ghost_gallery']!;
      expect(gallery.ghostEddies.length, 5);
      expect(gallery.ghostMouths.length, 2);
      expect(gallery.ghostChannels.length, 12);
      expect(gallery.eddyStarIndex, 1);
      // The Leviathan's arena answers the same tide as every other chamber
      // (§7 retrofit) — without tide zones there is nothing for its roar to
      // turn.
      expect(
        water.rooms['leviathan_depths']!.tideZones,
        isNotEmpty,
        reason: 'the depths must flood and drain on the guardian\'s roar',
      );
      // Star 3: four moon-pools, exactly two true; Leviathan in the depths.
      final well = water.rooms['moon_well']!;
      expect(well.moonPools.length, 4);
      expect(well.moonPools.where((p) => p.isTrue).length, 2);
      expect(
        well.tideValves.single.pipOnly,
        isTrue,
        reason: 'the well\'s pipe-mouth is a Pip shortcut',
      );
      final guardian = water.rooms['leviathan_depths']!.guardian;
      expect(guardian, isNotNull);
      expect(guardian!.encounter?.mysticId, 'Leviathan');
    });

    test('Earth dungeon has its three star chambers and full 3 stars', () {
      final earth = kPlanetDungeonLayouts['Earth']!;
      expect(
        earth.rooms.keys,
        containsAll([
          'barrow_gate',
          'sternum_court',
          'rib_hall',
          'marrow_vault',
          'pillar_crypt',
          'palm_hollow',
          'skull_antechamber',
          'eye_chamber',
          'heart_chamber',
        ]),
      );
      expect(earth.starIndices, {0, 1, 2});
      // Star 1: three ribs, a chasm, and the plate beyond it.
      final ribHall = earth.rooms['rib_hall']!;
      expect(ribHall.fossilRibs.length, 3);
      expect(ribHall.ribStarIndex, 0);
      expect(ribHall.ribChasm, isNotNull);
      expect(ribHall.sternumPlate, isNotNull);
      // Star 2: four buried sockets.
      final crypt = earth.rooms['pillar_crypt']!;
      expect(crypt.fossilPillars.length, 4);
      expect(crypt.pillarStarIndex, 1);
      // Star 3: the stone scale with a two-sided solution; Terradon beyond.
      final eye = earth.rooms['eye_chamber']!.stoneScale;
      expect(eye, isNotNull);
      expect(eye!.weights.length, 4);
      final guardian = earth.rooms['heart_chamber']!.guardian;
      expect(guardian, isNotNull);
      expect(guardian!.encounter?.mysticId, 'Terradon');
    });

    test('Lightning dungeon has its three star chambers and full 3 stars', () {
      final lightning = kPlanetDungeonLayouts['Lightning']!;
      expect(
        lightning.rooms.keys,
        containsAll([
          'arc_gate',
          'dynamo_court',
          'pylon_hall',
          'capacitor_vault',
          'cloud_works',
          'mirror_gallery',
          'overload_maze',
          'storm_core',
        ]),
      );
      expect(lightning.starIndices, {0, 1, 2});
      // Star 1 (rework): FOUR mirrors, three terminals, and the fulminate
      // vats the bolt must never cross (the negative constraints).
      final pylon = lightning.rooms['pylon_hall']!;
      expect(pylon.circuitStarIndex, 0);
      expect(pylon.beamEmitters.length, 1); // the pylon
      expect(pylon.beamMirrors.length, 4);
      expect(pylon.beamReceivers.length, 3); // the three terminals
      expect(pylon.beamConverters, isEmpty, reason: 'no Fire conversion in S1');
      expect(pylon.fulminateVats.length, 2,
          reason: 'the negative constraints that make it unique');
      // Star 2: three sockets (one needs heat) fed by storm-cells.
      final works = lightning.rooms['cloud_works']!;
      expect(works.circuitStarIndex, 1);
      expect(works.cellSockets.length, 3);
      expect(works.cellSockets.where((s) => s.requiresHeat).length, 1);
      expect(lightning.rooms['mirror_gallery']!.stormCells.length, 3);
      // Star 3: the Storm Spire beam puzzle + Raikuma beyond the gate.
      final maze = lightning.rooms['overload_maze']!;
      expect(maze.beamEmitters.length, 4); // Wind Vents (incl. the decoy VD)
      expect(maze.beamConverters.length, 4); // converters (incl. the decoy FD)
      expect(maze.beamMirrors.length, 5);
      expect(maze.beamReceiver, isNotNull); // the Storm Tower
      expect(maze.poweredBarriers.length, 1, reason: 'just the core gate');
      final guardian = lightning.rooms['storm_core']!.guardian;
      expect(guardian, isNotNull);
      expect(guardian!.encounter?.mysticId, 'Raikuma');
      // The Raikuma feed retrofit needs the grounding spike in the arena.
      expect(lightning.rooms['storm_core']!.coreBreaker, isNotNull);
    });

    test('Lightning zero-sum dynamo is well-formed', () {
      final lightning = kPlanetDungeonLayouts['Lightning']!;
      final hubId = lightning.dynamoRoomId;
      expect(hubId, isNotNull, reason: 'the dynamo hub must be declared');
      final hub = lightning.rooms[hubId];
      expect(hub, isNotNull);
      expect(lightning.dynamoTrunks.length, 4,
          reason: 'pylon / cloud / vault / core');
      final ids = lightning.dynamoTrunks.map((t) => t.id).toSet();
      expect(ids.length, 4, reason: 'trunk ids must be unique');
      expect(ids, contains(lightning.initialTrunkId),
          reason: 'the initial trunk must exist');
      // The treasury hoards the storm: the run starts on the VAULT trunk so
      // every star wing begins dark and the vault begins sealed.
      final initial = lightning.dynamoTrunks
          .firstWhere((t) => t.id == lightning.initialTrunkId);
      expect(
        initial.roomIds.any((r) => lightning.rooms[r]!.vaultBolt != null),
        isTrue,
        reason: 'the initial trunk must be the vault trunk',
      );
      final claimed = <String>{};
      for (final t in lightning.dynamoTrunks) {
        expect(t.roomIds, isNotEmpty);
        for (final rid in t.roomIds) {
          expect(lightning.rooms.containsKey(rid), isTrue,
              reason: 'trunk ${t.id} feeds unknown room $rid');
          expect(claimed.add(rid), isTrue,
              reason: '$rid must belong to exactly one trunk');
        }
        // Breakers stand inside the hub, off its walls.
        expect(hub!.bounds.contains(t.breakerPosition), isTrue,
            reason: 'breaker of ${t.id} must stand inside the dynamo court');
        expect(
          hub.walls.any((w) => w.inflate(16).contains(t.breakerPosition)),
          isFalse,
          reason: 'breaker of ${t.id} must not stand in a wall',
        );
        // A frozen-lit trunk must freeze on ITS wing's own star.
        final freeze = t.freezeLitStarIndex;
        if (freeze != null) {
          final wingStars = <int>{
            for (final rid in t.roomIds) ...[
              if (lightning.rooms[rid]!.circuitStarIndex != null)
                lightning.rooms[rid]!.circuitStarIndex!,
              if (lightning.rooms[rid]!.guardian != null)
                lightning.rooms[rid]!.guardian!.starIndex,
            ],
          };
          expect(wingStars, contains(freeze),
              reason: '${t.id} freezes on a star its wing does not award');
        }
      }
      // The hub and the entrance are the always-lit spine — on no trunk.
      expect(claimed, isNot(contains(hubId)));
      expect(claimed, isNot(contains(lightning.entranceRoomId)));
      // Every star wing rides a trunk (the zero-sum question touches all).
      for (final room in lightning.rooms.values) {
        if (room.circuitStarIndex != null ||
            room.guardian != null ||
            room.vaultBolt != null) {
          expect(claimed, contains(room.id),
              reason: '${room.id} must belong to a trunk');
        }
      }
      // The vault sanctum: the bolt is the sole mouth, and the cache sits
      // inside (unreachable while the trunk burns — collision-enforced).
      final vaultRoom =
          lightning.rooms.values.firstWhere((r) => r.vaultBolt != null);
      expect(vaultRoom.vaultCache, isNotNull);
      expect(vaultRoom.walls, isNotEmpty,
          reason: 'the sanctum needs its walls');
      // No gate:<element>_<family> id is declared for Lightning — the planet
      // stays hard-gate free after the rework (element-only at full power).
    });

    test(
      'Lightning S1 threading is PROVABLY UNIQUE (brute-forced against the '
      'real beam engine)',
      () {
        final game = _lightningProbe();
        final result = game.solvePylonThreading();
        expect(result.searched, 16, reason: '4 mirrors → 2^4 configurations');
        expect(
          result.satisfying,
          1,
          reason: 'exactly ONE orientation set may thread all three '
              'terminals without crossing a fulminate vat',
        );
        expect(
          result.solution,
          {'pa': 1, 'pb': 0, 'pc': 0, 'pd': 1},
          reason: 'the authored solution: pa=\\ pd=\\ pc=/ pb=/',
        );
      },
    );

    test(
      'Lightning S3 decoy pair is geometrically impossible; the true pair '
      'is not',
      () {
        final game = _lightningProbe();
        // The decoy: vent VD (index 3) + converter FD (index 3) — dead-
        // aligned, and a lie in every one of the 32 conductor configurations.
        final decoy = game.solveStormSpire(ventIndex: 3, converterIndex: 3);
        expect(decoy.searched, 32, reason: '5 mirrors → 2^5 configurations');
        expect(decoy.satisfying, 0,
            reason: 'no conductor waits beyond FD — the bolt dies in the '
                'ceiling under every configuration');
        // The viable chain: vent VA (0) + converter FA (0) reaches the tower.
        final viable = game.solveStormSpire(ventIndex: 0, converterIndex: 0);
        expect(viable.satisfying, greaterThan(0),
            reason: 'VA + FA must remain routable');
      },
    );

    test(
      'Water S2: EVERY current the gallery can run is PROVABLY DEDUCIBLE '
      'from its spins alone',
      () {
        final game = _waterProbe();
        final routes = game.ghostRoutes();
        expect(
          routes.length,
          6,
          reason: 'the twelve carved channels allow exactly six spring→sea '
              'routes through all five eddies',
        );
        // Every route: adopt it, read back ONLY the spins it puts on the
        // water, and hand those to the solver. The solver must recover that
        // route and no other — which is exactly the reasoning the player
        // does, run against the same code the game plays with.
        for (final route in routes) {
          game.adoptGhostRoute(route);
          final spins = {
            for (final e in game.layout.rooms['ghost_gallery']!.ghostEddies)
              e.id: game.eddySpinSunwise(e.id)!,
          };
          final result = game.solveGhostCurrent(spins);
          expect(result.searched, 6);
          expect(
            result.satisfying,
            1,
            reason: 'the spins of ${route.join('→')} must single it out — a '
                'current two routes could explain is a coin toss, not a '
                'deduction',
          );
          expect(
            result.order,
            route.sublist(1, route.length - 1),
            reason: 'the derived wade must BE the authored course',
          );
        }
      },
    );

    test('Water S2: the run rolls a real current, and only a deducible one',
        () {
      // Twenty fresh descents: each rolls one of the six routes, every roll
      // is a legal spring→sea course, and every roll survives its own solver.
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        final game = _waterProbe();
        final order = game.ghostWadeOrder;
        expect(order.length, 5, reason: 'the current runs through all five');
        expect(order.toSet().length, 5, reason: 'no eddy twice');
        final result = game.solveGhostCurrent();
        expect(result.satisfying, 1);
        expect(result.order, order);
        seen.add(order.join('>'));
      }
      expect(
        seen.length,
        greaterThan(1),
        reason: 'the current is rolled per run — a wiki must never spoil it',
      );
    });

    test('Steam dungeon has its three star chambers and full 3 stars', () {
      final steam = kPlanetDungeonLayouts['Steam']!;
      expect(
        steam.rooms.keys,
        containsAll([
          'boiler_gate',
          'manifold_south',
          'ember_causeway',
          'manifold_north',
          'cinder_forge',
          'crucible',
          'burst_vault',
          'boiler_heart',
        ]),
      );
      expect(steam.starIndices, {0, 1, 2});
      // Star 0: the Ember Causeway grid banks star 0.
      expect(steam.rooms['ember_causeway']!.molten?.starIndex, 0);
      // Star 1: the Cinder Forge grid banks star 1.
      expect(steam.rooms['cinder_forge']!.molten?.starIndex, 1);
      // Rite: the Crucible grid wakes the guardian (null star index).
      final crucible = steam.rooms['crucible']!.molten;
      expect(crucible, isNotNull);
      expect(crucible!.starIndex, isNull);
      // Star 2: Boilrog beyond, in the furnace-heart.
      final sg = steam.rooms['boiler_heart']!.guardian;
      expect(sg, isNotNull);
      expect(sg!.encounter?.mysticId, 'Boilrog');
    });

    test('Steam ring-main is a true loop with a budget that cannot buy it all',
        () {
      final steam = kPlanetDungeonLayouts['Steam']!;
      // Every seal is declared on BOTH sides of its junction with one cost,
      // and guards a real authored door.
      final junctionCosts = <String, int>{};
      for (final room in steam.rooms.values) {
        for (final seal in room.pressureSeals) {
          expect(
            room.doors.any((d) => d.targetRoomId == seal.targetRoomId),
            isTrue,
            reason: '${room.id} seals a door to ${seal.targetRoomId} that '
                'does not exist',
          );
          final other = steam.rooms[seal.targetRoomId]!;
          expect(
            other.pressureSeals.any(
                (s) => s.targetRoomId == room.id && s.cost == seal.cost),
            isTrue,
            reason: 'junction ${room.id}↔${seal.targetRoomId} must be '
                'declared on both sides with one cost',
          );
          final key = ([room.id, seal.targetRoomId]..sort()).join('|');
          junctionCosts[key] = seal.cost;
        }
      }
      // The ring: four junctions, forming the closed south→west→north→east
      // loop around the crucible.
      expect(junctionCosts.keys.toSet(), {
        'ember_causeway|manifold_south',
        'ember_causeway|manifold_north',
        'cinder_forge|manifold_north',
        'cinder_forge|manifold_south',
      });
      // THE STRATEGIC INVARIANT: the starting head cannot unclamp the whole
      // ring — the player must choose, condense, or stoke.
      final totalCost = junctionCosts.values.fold<int>(0, (a, b) => a + b);
      expect(totalCost, greaterThan(kSteamStartPressure));
      // The burst-disc guards the vault-cache room, and demands more than
      // the starting head (the dump must be EARNED).
      final south = steam.rooms['manifold_south']!;
      expect(south.burstDisc, isNotNull);
      expect(south.burstDisc!.targetRoomId, 'burst_vault');
      expect(steam.rooms['burst_vault']!.vaultCache, isNotNull);
      expect(south.burstDisc!.threshold, greaterThan(kSteamStartPressure));
      // Fireboxes exist so an empty main is never a softlock.
      expect(
        steam.rooms.values.any((r) => r.stokePort != null),
        isTrue,
        reason: 'at least one stoke firebox must exist',
      );
    });

    test('Steam molten grids are well-formed and solvable in shape', () {
      final steam = kPlanetDungeonLayouts['Steam']!;
      const legal = {'.', '#', 'X', 'L', 'P'};
      for (final room in steam.rooms.values) {
        final g = room.molten;
        if (g == null) continue;
        // Rectangular: every row the same width.
        for (final line in g.rows) {
          expect(line.length, g.cols,
              reason: '${room.id} molten rows must be equal-length');
          for (final ch in line.split('')) {
            expect(legal.contains(ch), isTrue,
                reason: '${room.id} has illegal molten cell "$ch"');
          }
        }
        // A star grid has exactly one pedestal; so does the rite grid.
        final pedestals =
            g.rows.fold<int>(0, (n, line) => n + 'P'.allMatches(line).length);
        expect(pedestals, 1,
            reason: '${room.id} must have exactly one pedestal');
      }
    });

    test('Lightning circuit graphs are well-formed', () {
      final lightning = kPlanetDungeonLayouts['Lightning']!;
      for (final room in lightning.rooms.values) {
        final ids = {for (final n in room.circuitNodes) n.id};
        // Every wired link + mirror orientation points at a real node.
        for (final n in room.circuitNodes) {
          for (final l in n.links) {
            expect(ids.contains(l), isTrue,
                reason: '${room.id}/${n.id} links unknown node $l');
          }
          for (final orient in n.orientationLinks) {
            for (final l in orient) {
              expect(ids.contains(l), isTrue,
                  reason: '${room.id}/${n.id} orientation links unknown $l');
            }
          }
          if (n.kind == CircuitNodeKind.mirror) {
            expect(n.orientationLinks.length, greaterThanOrEqualTo(2),
                reason: 'a mirror needs at least two orientations to route');
          }
        }
        // Every powered barrier + cell socket references a real node. (The
        // beam maze's gate is driven by the beam engine, not a graph node.)
        for (final bar in room.poweredBarriers) {
          if (room.beamEmitters.isNotEmpty) continue;
          expect(ids.contains(bar.nodeId), isTrue,
              reason: '${room.id} barrier references unknown ${bar.nodeId}');
        }
        for (final sock in room.cellSockets) {
          expect(ids.contains(sock.energizesNodeId), isTrue,
              reason: '${room.id} socket energizes unknown node');
        }
      }
    });
  });
}

/// A bare Lightning game used only to drive the public brute-force solvers —
/// they exercise the REAL beam engine over the authored layout, so the
/// uniqueness proof can never drift from what the game actually computes.
PlanetDungeonGame _waterProbe() => PlanetDungeonGame(
      element: 'Water',
      party: const [],
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
    );

PlanetDungeonGame _lightningProbe() => PlanetDungeonGame(
      element: 'Lightning',
      party: const [],
      initialStarMask: 0,
      onStarEarned: (_) {},
      onPlayerDown: () {},
      onChanged: () {},
    );
