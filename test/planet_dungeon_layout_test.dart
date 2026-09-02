import 'dart:math' show min;
import 'dart:ui' show Rect;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart'
    show
        PlanetDungeonGame,
        MirrorTide,
        StormCircuit,
        kSteamStartPressure,
        kScaleClueRooms;
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
            // The canal network: ids unique, every groove's endpoints real,
            // exactly one spring and one sea drain, the whole thing a DAG
            // (the stone only falls one way), and — the readability rule —
            // never two grooves of the same sill leaving one basin, so the
            // SPILL rule is never a coin toss the player cannot see.
            final nodeIds = <String, CanalNode>{
              for (final n in room.canalNodes) n.id: n,
            };
            expect(
              nodeIds.length,
              room.canalNodes.length,
              reason: '${room.id}: canal node ids must be unique',
            );
            if (room.canalNodes.isNotEmpty) {
              expect(
                room.canalNodes.where((n) => n.isSpring).length,
                1,
                reason: '${room.id}: the canals need exactly one spring mouth',
              );
              expect(
                room.canalNodes.where((n) => n.isSea).length,
                1,
                reason: '${room.id}: the canals need exactly one sea drain',
              );
              expect(
                room.canalChannels,
                isNotEmpty,
                reason: '${room.id}: basins with no grooves between them',
              );
              // Nothing may run INTO the spring or OUT of the sea: those are
              // the two fixed ends the whole network hangs from.
              for (final ch in room.canalChannels) {
                expect(
                  nodeIds[ch.to]!.isSpring,
                  isFalse,
                  reason:
                      '${room.id}: ${ch.from}→${ch.to} runs into the '
                      'spring — the source never takes water back',
                );
                expect(
                  nodeIds[ch.from]!.isSea,
                  isFalse,
                  reason:
                      '${room.id}: ${ch.from}→${ch.to} runs out of the '
                      'sea drain',
                );
              }
            }
            for (final ch in room.canalChannels) {
              expect(
                nodeIds.containsKey(ch.from) && nodeIds.containsKey(ch.to),
                isTrue,
                reason:
                    '${room.id}: groove ${ch.from}→${ch.to} names a node '
                    'that does not exist',
              );
              expect(
                (nodeIds[ch.from]!.position - nodeIds[ch.to]!.position)
                    .distance,
                greaterThanOrEqualTo(120.0),
                reason:
                    '${room.id}: groove ${ch.from}→${ch.to} is too short '
                    'to read its chevrons, its sill notches, or the lantern '
                    'crossing it',
              );
            }
            // No two grooves out of one basin may share a sill.
            for (final node in room.canalNodes) {
              final sills = [
                for (final ch in room.canalChannels)
                  if (ch.from == node.id) ch.sill,
              ];
              expect(
                sills.toSet().length,
                sills.length,
                reason:
                    '${room.id}/${node.id}: two grooves share a sill — '
                    'the spill would be a coin toss the player cannot read',
              );
            }
            // Acyclic: the stone only ever falls seaward.
            if (room.canalNodes.isNotEmpty) {
              final onward = <String, List<String>>{};
              for (final ch in room.canalChannels) {
                onward.putIfAbsent(ch.from, () => []).add(ch.to);
              }
              final state = <String, int>{}; // 1 = on the stack, 2 = done
              bool cyclic(String at) {
                final mark = state[at];
                if (mark == 1) return true;
                if (mark == 2) return false;
                state[at] = 1;
                for (final next in onward[at] ?? const <String>[]) {
                  if (cyclic(next)) return true;
                }
                state[at] = 2;
                return false;
              }

              for (final node in room.canalNodes) {
                expect(
                  cyclic(node.id),
                  isFalse,
                  reason:
                      '${room.id}: the canals loop — water that can circle '
                      'is water the player can never finish steering',
                );
              }
            }
            for (final n in room.canalNodes) {
              expect(
                room.bounds.contains(n.position),
                isTrue,
                reason: '${room.id}/${n.id}: canal node outside the room',
              );
            }
            final poolIds = room.moonPools.map((p) => p.id).toSet();
            expect(
              poolIds.length,
              room.moonPools.length,
              reason: '${room.id}: moon-pool ids must be unique',
            );
            if (room.moonPools.isNotEmpty) {
              // WHICH basins listen is rolled per run now, so the data cannot
              // say. What it must still guarantee is that there are enough of
              // them to roll a pair out of, and somewhere to work the moon.
              expect(
                room.moonPools.length,
                greaterThanOrEqualTo(2),
                reason: '${room.id}: two basins are rolled, so two must exist',
              );
              expect(
                room.moonDial,
                isNotNull,
                reason: '${room.id}: basins with no dial can never be filled',
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

        test(
          'every dungeon hides exactly one vault cache, inside its room',
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
          },
        );

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
            if (room.canalStarIndex != null) {
              nonGuardianStars.add(room.canalStarIndex!);
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
            // The 2026-08-14 reworks carry their star on the object: Fire's
            // burnable garth and Steam's geyser capstone.
            if (room.garth != null) {
              nonGuardianStars.add(room.garth!.starIndex);
            }
            if (room.capstone != null) {
              nonGuardianStars.add(room.capstone!.starIndex);
            }
            // Poison declares BOTH of its non-guardian stars on the prior's
            // seal: a cure can bank Star 1 in any of the four wards, so no
            // ward owns it.
            // Lava carries each non-guardian star on the room the line
            // leaves you standing in.
            if (room.foundryStar != null) {
              nonGuardianStars.add(room.foundryStar!.starIndex);
            }
            if (room.priorsSeal != null) {
              nonGuardianStars.add(room.priorsSeal!.diagnosisStarIndex);
              nonGuardianStars.add(room.priorsSeal!.triageStarIndex);
            }
            // Ice's two puzzle levels carry their star on the room's shaft
            // content (the orrery floor and the mirror gallery).
            if (room.rime?.starIndex != null) {
              nonGuardianStars.add(room.rime!.starIndex!);
            }
            // Mud declares BOTH of its non-guardian stars on the Sinking
            // Altar's socket: the Moor Star completes in whichever of the
            // three moor knolls is dried last, so no knoll owns it.
            if (room.fen?.altar != null) {
              nonGuardianStars.add(room.fen!.altar!.sarsenStarIndex);
              nonGuardianStars.add(room.fen!.altar!.moorStarIndex);
            }
            // Dust does the same across its two Z-layers: the seal street
            // above and the observatory below.
            if (room.ruins?.starIndex != null) {
              nonGuardianStars.add(room.ruins!.starIndex!);
            }
            // Crystal declares BOTH of its non-guardian stars on the oriel:
            // neither belongs to a room — one is a fact about the sliding
            // keep's middle ROW, the other about its heart cell's four faces.
            if (room.prism?.keep != null) {
              nonGuardianStars.add(room.prism!.keep!.spectrumStarIndex);
              nonGuardianStars.add(room.prism!.keep!.throneStarIndex);
            }
            // Plant does the same across its one geometry at two sizes: the
            // lantern court and the islet.
            if (room.grove?.starIndex != null) {
              nonGuardianStars.add(room.grove!.starIndex!);
            }
            // Spirit declares BOTH of its non-guardian stars on the lych
            // gate: one is a fact about the LIVING crossings of the whole
            // grave-field, the other about two halves of a sigil that lie in
            // different worlds.
            if (room.grave?.vigil != null) {
              nonGuardianStars.add(room.grave!.vigil!.roadStarIndex);
              nonGuardianStars.add(room.grave!.vigil!.sigilStarIndex);
            }
            // Dark declares its two non-guardian stars on the hall a room
            // is: the analemma court in the pall quarter, the ossuary ring
            // in the bones.
            if (room.eclipse?.starIndex != null) {
              nonGuardianStars.add(room.eclipse!.starIndex!);
            }
            // Light does the same with the sector a bay of the one great hall
            // lies in: the shadow court in the court bay, the dark stacks out
            // past both great stacks.
            if (room.hall?.starIndex != null) {
              nonGuardianStars.add(room.hall!.starIndex!);
            }
            // Blood carries its two non-guardian stars on the chamber a room
            // is: the vena crossing where the figure-eight crosses itself,
            // and the capillary weave at the far end of the lung.
            if (room.sanguine?.starIndex != null) {
              nonGuardianStars.add(room.sanguine!.starIndex!);
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
              expect(
                ledges.containsKey(r.from),
                isTrue,
                reason: '${room.id}: route ${r.id} leaves nowhere',
              );
              expect(
                ledges.containsKey(r.to),
                isTrue,
                reason: '${room.id}: route ${r.id} arrives nowhere',
              );
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
                expect(
                  rects,
                  isNotNull,
                  reason:
                      '${room.id}: route ${r.id} rides an unauthored '
                      'gale "$rides"',
                );
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
              expect(
                ledges.containsKey(s.ledgeId),
                isTrue,
                reason: '${room.id}: shrine ${s.id} stands on no ledge',
              );
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
              // Hand-channelled is `!struckByStorm`, NOT `requiredFamily !=
              // null`: a conduit with no family is ELEMENT-ONLY and perfectly
              // reachable by hand. Filtering on the family used to hide that
              // distinction, and dropping a gate to make a rite element-only
              // then read as "the storm must light it" and failed here.
              if (!c.struckByStorm) {
                // It must ask for SOMETHING. An element, a family, or both —
                // a verb-only rite (Dust, Crystal) names no element on
                // purpose, and that is fine. Naming neither is not.
                expect(
                  c.requireElement.isNotEmpty || c.requiredFamily != null,
                  isTrue,
                  reason:
                      'conduit ${c.id} in ${room.id} is hand-channelled but '
                      'asks for neither an element nor a family, so nothing '
                      'can ever light it',
                );
                continue;
              }
              expect(
                room.stormRods,
                isNotEmpty,
                reason: '${room.id}: nothing for the bolt to climb',
              );
              final orbit = room.stormOrbit;
              expect(
                orbit,
                isNotNull,
                reason: '${room.id}: a struck conduit with no storm',
              );
              final gap = (c.position - orbit!.center).distance - orbit.radius;
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
      // Star 2: the cloister owns THE BURN — a field you route a fire across.
      final cloister = fire.rooms['cloister']!;
      final garth = cloister.garth;
      expect(garth, isNotNull, reason: 'the cloister is a burnable field now');
      expect(garth!.starIndex, 1);
      expect(
        garth.coverageGoal,
        greaterThan(0),
        reason: 'the ember pool is the win condition',
      );
      expect(
        cloister.windVane,
        isNotNull,
        reason: 'the garth turns its own crosswind',
      );
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
      // Star 2: the gallery owns the canal network — a spring, five basins,
      // a sea drain, ten carved grooves.
      final gallery = water.rooms['ghost_gallery']!;
      expect(gallery.canalNodes.length, 7);
      expect(gallery.canalNodes.where((n) => n.isBasin).length, 5);
      expect(gallery.canalChannels.length, 10);
      expect(gallery.canalStarIndex, 1);
      // THE SLUICE-BANK LIVES IN THE COURT, one door west. It used to be in
      // the gallery so that steering the water was a walk taken against the
      // lantern's drift; the lantern only ticks while you are in the gallery,
      // so the trip freezes it and the canal is a planning puzzle now.
      //
      // What still has to hold is REACH: every stand must be settable from
      // somewhere a player standing in the canal can walk to without passing
      // a locked door, or a route that needs a stand becomes unfloatable.
      final bank = water.rooms['drowned_court']!;
      expect(
        bank.tideValves.map((v) => v.level).toSet(),
        {0, 1, 2},
        reason: 'every stand must be reachable from beside the canal',
      );
      expect(
        gallery.doors.any((d) => d.targetRoomId == 'drowned_court'),
        isTrue,
        reason: 'and the wheels must be ONE door from the water',
      );
      expect(
        water.rooms['drowned_court']!.doors.any(
          (d) => d.targetRoomId == 'ghost_gallery',
        ),
        isTrue,
        reason: 'both ways — the walk back cannot be the long way round',
      );
      // Every sill kind is authored, or the tide is only half a verb.
      expect(
        gallery.canalChannels.map((c) => c.sill).toSet(),
        CanalSill.values.toSet(),
      );
      // The Leviathan's arena answers the same tide as every other chamber
      // (§7 retrofit) — without tide zones there is nothing for its roar to
      // turn.
      expect(
        water.rooms['leviathan_depths']!.tideZones,
        isNotEmpty,
        reason: 'the depths must flood and drain on the guardian\'s roar',
      );
      // Star 3, THE MOON WELL: four basins (which two listen, and at what
      // phase, is rolled per run — see the game test), a dial for Spirit and
      // the pip's pipe-mouth as the still. Leviathan in the depths.
      final well = water.rooms['moon_well']!;
      expect(well.moonPools.length, 4);
      expect(
        well.moonDial,
        isNotNull,
        reason: 'Spirit needs somewhere to stand and wane the moon',
      );
      expect(
        well.tideValves.single.pipOnly,
        isTrue,
        reason: 'the well\'s pipe-mouth is the still, and Pip-only',
      );
      // The dial must not sit on top of the well mouth or a basin — three
      // stations in one place is one station.
      for (final p in [
        well.bounds.center,
        ...well.moonPools.map((m) => m.position),
        well.tideValves.single.position,
      ]) {
        expect(
          (well.moonDial! - p).distance,
          greaterThan(70),
          reason: 'the dial must be its own place in the room',
        );
      }
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
      expect(eye!.weights.length, 5);
      // EVERY STONE MUST HAVE A MARK, and every mark a room. A stone with no
      // clue carved anywhere is a coin-flip the player cannot reason about,
      // which is the whole thing this star was built to avoid.
      for (final w in eye.weights) {
        final clueRoom = kScaleClueRooms[w.id];
        expect(
          clueRoom,
          isNotNull,
          reason: '${w.id} has no chamber carrying its mark',
        );
        expect(
          earth.rooms.keys,
          contains(clueRoom),
          reason: '${w.id}\'s mark is in "$clueRoom", which does not exist',
        );
      }
      expect(
        kScaleClueRooms.values.toSet(),
        hasLength(eye.weights.length),
        reason: 'two marks in one room would be two arrows to tell apart',
      );
      final guardian = earth.rooms['heart_chamber']!.guardian;
      expect(guardian, isNotNull);
      expect(guardian!.encounter?.mysticId, 'Terradon');
    });

    test('you never arrive at the far end from the door back', () {
      // THE LOOP THIS FIXES. A door's `targetSpawn` is where you land in the
      // next room. If the way BACK is on a wall, you have to land in the half
      // of the room nearest that wall — otherwise you step through a doorway
      // and appear at the opposite end of somewhere else, with no way to tell
      // which opening you just used.
      //
      // Lightning's mirror gallery was the case that named this: its two
      // doors were on exactly the wrong walls. The hub lies north of it, so
      // the way home is UP — but the gallery's door to the hub sat at the
      // BOTTOM, and the door at the top went somewhere else entirely. You
      // walked south out of the court and every exit led further away.
      //
      // Interior doors are exempt: a door in the middle of an arena floor has
      // no near half to land in.
      final wrong = <String>[];
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final room in layout.rooms.values) {
          for (final d in room.doors) {
            final t = layout.rooms[d.targetRoomId];
            if (t == null) continue;
            final back =
                t.doors.where((x) => x.targetRoomId == room.id).toList();
            if (back.isEmpty) continue; // a genuine one-way drop
            final r = back.first.rect;
            final b = t.bounds;
            final onTop = r.top <= b.top + 2;
            final onBottom = r.bottom >= b.bottom - 2;
            final onLeft = r.left <= b.left + 2;
            final onRight = r.right >= b.right - 2;
            bool bad = false;
            if (onTop) bad = d.targetSpawn.dy > b.center.dy;
            if (onBottom) bad = d.targetSpawn.dy < b.center.dy;
            if (onLeft) bad = d.targetSpawn.dx > b.center.dx;
            if (onRight) bad = d.targetSpawn.dx < b.center.dx;
            if (bad) {
              wrong.add(
                '$element ${room.id} → ${t.id}: the way back is on one wall '
                'and you land in the other half of the room',
              );
            }
          }
        }
      });
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    test('and never outside the room you are arriving in', () {
      // Mud dropped you at x=680 in a room 460 wide.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final room in layout.rooms.values) {
          for (final d in room.doors) {
            final t = layout.rooms[d.targetRoomId];
            if (t == null) continue;
            expect(
              t.bounds.deflate(8).contains(d.targetSpawn),
              isTrue,
              reason:
                  '$element ${room.id} → ${t.id}: lands at ${d.targetSpawn}, '
                  'outside ${t.bounds}',
            );
          }
        }
      });
    });

    test('and a wall never seals a door — every door is WALKABLE from where '
        'you arrive in its room', () {
      // Lightning's Pylon Hall shipped a beam-hall floor whose border iron
      // ran straight across its only doorway. The walk clamps to 16px inside
      // the bounds and stands 16px off any wall, so the door had no reachable
      // point anywhere in it: the player walks into the opening and stops, and
      // it reads as a wall rather than a bug. Rect-vs-rect is not enough to
      // catch that — a pillar parked in front of a door seals it just as
      // dead — so this walks the room.
      const r = 16.0; // PlanetDungeonGame._radius
      const step = 4.0;
      final sealed = <String>[];
      for (final entry in kPlanetDungeonLayouts.entries) {
        final layout = entry.value;
        for (final room in layout.rooms.values) {
          if (room.walls.isEmpty) continue; // nothing can seal anything
          final b = room.bounds;
          bool free(double x, double y) {
            if (x < b.left + r || x > b.right - r) return false;
            if (y < b.top + r || y > b.bottom - r) return false;
            for (final w in room.walls) {
              if (x > w.left - r &&
                  x < w.right + r &&
                  y > w.top - r &&
                  y < w.bottom + r) {
                return false;
              }
            }
            return true;
          }

          // Where the player can be standing in this room to begin with.
          final arrivals = <Offset>[
            if (room.id == layout.entranceRoomId) layout.entranceSpawn,
            for (final other in layout.rooms.values)
              for (final d in other.doors)
                if (d.targetRoomId == room.id) d.targetSpawn,
          ];
          if (arrivals.isEmpty) continue;

          final cols = ((b.width - 2 * r) / step).floor() + 1;
          final rows = ((b.height - 2 * r) / step).floor() + 1;
          double px(int i) => b.left + r + i * step;
          double py(int j) => b.top + r + j * step;
          final seen = List.generate(cols, (_) => List.filled(rows, false));
          final queue = <int>[];
          void seed(Offset p) {
            // Snap to the nearest free cell — an arrival may sit a pixel
            // inside a wall's skin without the room being broken.
            var best = -1;
            var bestD = double.infinity;
            for (var i = 0; i < cols; i++) {
              for (var j = 0; j < rows; j++) {
                if (!free(px(i), py(j))) continue;
                final d = (Offset(px(i), py(j)) - p).distanceSquared;
                if (d < bestD) {
                  bestD = d;
                  best = i * rows + j;
                }
              }
            }
            if (best >= 0 && bestD <= 48 * 48) queue.add(best);
          }

          for (final a in arrivals) {
            seed(a);
          }
          while (queue.isNotEmpty) {
            final cell = queue.removeLast();
            final i = cell ~/ rows, j = cell % rows;
            if (i < 0 || j < 0 || i >= cols || j >= rows) continue;
            if (seen[i][j]) continue;
            if (!free(px(i), py(j))) continue;
            seen[i][j] = true;
            queue
              ..add((i + 1) * rows + j)
              ..add((i - 1) * rows + j)
              ..add(i * rows + j + 1)
              ..add(i * rows + j - 1);
          }

          for (final d in room.doors) {
            var reachable = false;
            for (var i = 0; i < cols && !reachable; i++) {
              for (var j = 0; j < rows && !reachable; j++) {
                if (seen[i][j] && d.rect.contains(Offset(px(i), py(j)))) {
                  reachable = true;
                }
              }
            }
            if (!reachable) {
              sealed.add(
                '${entry.key}/${room.id} → ${d.targetRoomId} ${d.rect}',
              );
            }
          }
        }
      }
      expect(
        sealed,
        isEmpty,
        reason: 'these doors cannot be walked into:\n${sealed.join('\n')}',
      );
    });

    test('and never inside another doorway', () {
      // The other half: land in a door's trigger and the next step bounces
      // you straight back out of the room you just entered.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final room in layout.rooms.values) {
          for (final d in room.doors) {
            final t = layout.rooms[d.targetRoomId];
            if (t == null) continue;
            for (final other in t.doors) {
              if (other.targetRoomId == room.id) continue;
              expect(
                other.rect.inflate(20).contains(d.targetSpawn),
                isFalse,
                reason:
                    '$element ${room.id} → ${t.id} lands inside ${t.id}\'s '
                    'door to ${other.targetRoomId}',
              );
            }
          }
        }
      });
    });

    test('Lightning: the hub reads — doors apart, breakers at their doors', () {
      // Two faults, both about being able to navigate the hub at a glance.
      //
      // The north wall carried the FINALE GATE at x 610-690 and the TREASURY
      // at 700-810: ten pixels apart, a locked endgame door and a reward room
      // reading as one doorway. And the four trunk breakers sat in a blob
      // around the rotor, so which switch woke which wing had to be traced
      // along a wire or memorised.
      final l = kPlanetDungeonLayouts['Lightning']!;
      final hub = l.rooms[l.dynamoRoomId]!;

      // Every pair of doorways on the same wall clears the other by a margin
      // no one could mistake for one opening.
      final top = hub.doors.where((d) => d.rect.top <= 1).toList();
      expect(top.length, greaterThanOrEqualTo(3));
      for (var i = 0; i < top.length; i++) {
        for (var j = i + 1; j < top.length; j++) {
          final gap = top[i].rect.left < top[j].rect.left
              ? top[j].rect.left - top[i].rect.right
              : top[i].rect.left - top[j].rect.right;
          expect(
            gap,
            greaterThan(100),
            reason:
                '${top[i].targetRoomId} and ${top[j].targetRoomId} are '
                '${gap.round()}px apart on the same wall',
          );
        }
      }

      // And each breaker stands nearer the door of the wing it feeds than to
      // any door it does not, so the geography IS the mapping.
      for (final t in l.dynamoTrunks) {
        final mine = hub.doors
            .where((d) => t.roomIds.contains(d.targetRoomId))
            .toList();
        if (mine.isEmpty) continue;
        final nearestMine = mine
            .map((d) => (d.rect.center - t.breakerPosition).distance)
            .reduce(min);
        for (final d in hub.doors) {
          if (t.roomIds.contains(d.targetRoomId)) continue;
          if (d.targetRoomId == l.entranceRoomId) continue;
          expect(
            (d.rect.center - t.breakerPosition).distance,
            greaterThan(nearestMine),
            reason:
                '${t.id} sits closer to ${d.targetRoomId} than to any wing '
                'it actually feeds',
          );
        }
      }
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
      // Star 1 (§9.2): the braid, taught small — three vents, three
      // converters, four conductors, ONE mast.
      final pylon = lightning.rooms['pylon_hall']!;
      expect(pylon.circuitStarIndex, 0);
      expect(pylon.beamEmitters.length, 3);
      expect(pylon.beamConverters.length, 3);
      expect(pylon.beamMirrors.length, 4);
      expect(pylon.beamReceiver, isNotNull);
      expect(pylon.beamReceivers, isEmpty, reason: 'one mast, not three');
      expect(pylon.walls, isNotEmpty, reason: 'the pillar that eats a bolt');
      // The Mirror Gallery (§9.3): three echoes, three panes, three DIFFERENT
      // wings — and never the gallery's own, which would light the room and
      // drown them.
      final gallery = lightning.rooms['mirror_gallery']!;
      expect(gallery.stormCells.length, 3);
      final galleryTrunk = lightning.dynamoTrunks
          .firstWhere((t) => t.roomIds.contains('mirror_gallery'))
          .id;
      final wings = gallery.stormCells
          .map((c) => c.showsUnderTrunk)
          .toList(growable: false);
      expect(
        wings.toSet().length,
        3,
        reason: 'each echo answers to its own wing: $wings',
      );
      expect(
        wings,
        isNot(contains(galleryTrunk)),
        reason:
            'an echo keyed to the gallery\'s own trunk could never be seen — '
            'that wing lights the room and drowns the glass',
      );
      for (final c in gallery.stormCells) {
        expect(
          lightning.dynamoTrunks.map((t) => t.id),
          contains(c.showsUnderTrunk),
          reason: '${c.id} names a wing that does not exist',
        );
        // The reflection must land somewhere the player can stand and read
        // it, and far enough from the truth that walking to one is a choice.
        expect(gallery.bounds.deflate(40).contains(c.reflection), isTrue);
        expect(gallery.bounds.deflate(40).contains(c.position), isTrue);
        expect(
          (c.reflection - c.position).distance,
          greaterThan(120),
          reason: '${c.id}: the two sides must not blur into one another',
        );
        for (final w in gallery.walls) {
          expect(w.inflate(16).contains(c.position), isFalse);
          expect(w.inflate(16).contains(c.reflection), isFalse);
        }
      }

      // Star 2: three sockets (one needs heat) fed by storm-cells.
      final works = lightning.rooms['cloud_works']!;
      expect(works.circuitStarIndex, 1);
      expect(works.cellSockets.length, 3);
      expect(works.cellSockets.where((s) => s.requiresHeat).length, 1);
      expect(lightning.rooms['mirror_gallery']!.stormCells.length, 3);
      // Star 3 (§9.2): the same braid at spire scale — seven conductors,
      // THREE masts to crown at once, and fulminate only the charged half
      // may not cross.
      final maze = lightning.rooms['overload_maze']!;
      expect(maze.beamEmitters.length, 4); // Wind Vents (incl. the decoy VD)
      expect(maze.beamConverters.length, 4); // converters (incl. the decoy FD)
      expect(maze.beamMirrors.length, 7);
      expect(maze.beamReceiver, isNull, reason: 'the Spire has masts, plural');
      expect(maze.beamReceivers.length, 3);
      expect(maze.fulminateVats.length, 3);
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
      expect(
        lightning.dynamoTrunks.length,
        4,
        reason: 'pylon / cloud / vault / core',
      );
      final ids = lightning.dynamoTrunks.map((t) => t.id).toSet();
      expect(ids.length, 4, reason: 'trunk ids must be unique');
      expect(
        ids,
        contains(lightning.initialTrunkId),
        reason: 'the initial trunk must exist',
      );
      // The treasury hoards the storm: the run starts on the VAULT trunk so
      // every star wing begins dark and the vault begins sealed.
      final initial = lightning.dynamoTrunks.firstWhere(
        (t) => t.id == lightning.initialTrunkId,
      );
      expect(
        initial.roomIds.any((r) => lightning.rooms[r]!.vaultBolt != null),
        isTrue,
        reason: 'the initial trunk must be the vault trunk',
      );
      final claimed = <String>{};
      for (final t in lightning.dynamoTrunks) {
        expect(t.roomIds, isNotEmpty);
        for (final rid in t.roomIds) {
          expect(
            lightning.rooms.containsKey(rid),
            isTrue,
            reason: 'trunk ${t.id} feeds unknown room $rid',
          );
          expect(
            claimed.add(rid),
            isTrue,
            reason: '$rid must belong to exactly one trunk',
          );
        }
        // Breakers stand inside the hub, off its walls.
        expect(
          hub!.bounds.contains(t.breakerPosition),
          isTrue,
          reason: 'breaker of ${t.id} must stand inside the dynamo court',
        );
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
          expect(
            wingStars,
            contains(freeze),
            reason: '${t.id} freezes on a star its wing does not award',
          );
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
          expect(
            claimed,
            contains(room.id),
            reason: '${room.id} must belong to a trunk',
          );
        }
      }
      // The vault sanctum: the bolt is the sole mouth, and the cache sits
      // inside (unreachable while the trunk burns — collision-enforced).
      final vaultRoom = lightning.rooms.values.firstWhere(
        (r) => r.vaultBolt != null,
      );
      expect(vaultRoom.vaultCache, isNotNull);
      expect(
        vaultRoom.walls,
        isNotEmpty,
        reason: 'the sanctum needs its walls',
      );
      // No gate:<element>_<family> id is declared for Lightning — the planet
      // stays hard-gate free after the rework (element-only at full power).
    });

    test('Lightning S1 — the small braid is PROVABLY UNIQUE: one pairing, one '
        'conductor set, brute-forced against the real beam engine', () {
      final game = _lightningProbe();
      final hall = game.layout.rooms['pylon_hall']!;
      final works = <String>[];
      ({int searched, int satisfying, Map<String, int>? solution})? only;
      for (var v = 0; v < hall.beamEmitters.length; v++) {
        for (var c = 0; c < hall.beamConverters.length; c++) {
          final r = game.solveBeamHall(
            roomId: 'pylon_hall',
            ventIndex: v,
            converterIndex: c,
          );
          expect(r.searched, 16, reason: '4 conductors → 2^4 configurations');
          if (r.satisfying > 0) {
            works.add('V$v+F$c×${r.satisfying}');
            only = r;
          }
        }
      }
      expect(
        works,
        ['V0+F0×1'],
        reason:
            'exactly one vent/converter pairing may be braided, in exactly '
            'one conductor set — every other pairing is eliminated by '
            'geometry alone',
      );
      expect(only!.solution, {
        'pa': 1,
        'pb': 0,
        'pc': 1,
        'pd': 1,
      }, reason: r'the authored answer: pa=\ pb=/ pc=\ pd=\');
    });

    test('Lightning S3 — the spire braid is PROVABLY UNIQUE too, and the '
        'dead-aligned east pair is impossible in all 128 configurations', () {
      final game = _lightningProbe();
      final spire = game.layout.rooms['overload_maze']!;
      final works = <String>[];
      ({int searched, int satisfying, Map<String, int>? solution})? only;
      for (var v = 0; v < spire.beamEmitters.length; v++) {
        for (var c = 0; c < spire.beamConverters.length; c++) {
          final r = game.solveBeamHall(
            roomId: 'overload_maze',
            ventIndex: v,
            converterIndex: c,
          );
          expect(r.searched, 128, reason: '7 conductors → 2^7 configurations');
          if (r.satisfying > 0) {
            works.add('V$v+F$c×${r.satisfying}');
            only = r;
          }
        }
      }
      expect(
        works,
        ['V0+F0×1'],
        reason:
            'one pairing, one conductor set — and in particular the decoy '
            'V3+F3 crowns nothing in any of the 128',
      );
      // Named explicitly: eliminating the decoy is geometry, not grinding.
      expect(
        game
            .solveBeamHall(
              roomId: 'overload_maze',
              ventIndex: 3,
              converterIndex: 3,
            )
            .satisfying,
        0,
      );
      expect(only!.solution, {
        'A': 1,
        'B': 0,
        'C': 1,
        'D': 1,
        'E': 0,
        'F': 0,
        'G': 1,
      });
    });

    test(
      'Water S2: the authored canal network is PROVED solvable, and the tide '
      'and the ice are both load-bearing',
      () {
        final game = _waterProbe();
        final proof = game.solveLanternDrift();
        expect(proof.basins, 5);
        expect(proof.channels, 10);
        expect(
          proof.solvable,
          isTrue,
          reason: 'the lantern must be floatable spring → sea at all',
        );
        expect(
          proof.route.first.from,
          'spring',
          reason: 'a proved route starts where the player sets the lantern',
        );
        expect(proof.route.last.to, 'sea');
        // THE TIDE IS THE PUZZLE: no single stand of water carries the
        // lantern out, however the player plugs the basins. Every road to
        // the sea has to cross a crest (high water only) AND a deep cut
        // (never at high water), so the stand must CHANGE mid-drift.
        expect(
          proof.singleStandSolvable,
          isEmpty,
          reason:
              'a stand that solved it alone would make the temple\'s own '
              'signature system decoration',
        );
        // THE ICE IS A VERB: the temple's natural fall never reaches the sea.
        expect(
          proof.damFree,
          isFalse,
          reason:
              'undammed, the water spills all the way into the blind '
              'sump — plugging a basin is required, not optional',
        );
        expect(
          proof.blindBasins,
          1,
          reason:
              'exactly one throatless basin: the fall the player must '
              'learn to fight',
        );
      },
    );

    test(
      'Water S2: the canal network CANNOT strand the player — strandable == 0',
      () {
        final game = _waterProbe();
        final proof = game.solveLanternDrift();
        // Checked exhaustively over every resting place the lantern can
        // reach, not assumed and not covered up by the death reset: from
        // each one the sea is still reachable with the real spill rule.
        expect(
          proof.strandable,
          0,
          reason:
              'every place the lantern can come to rest must still have a '
              'road to the sea',
        );
        expect(proof.states, 21, reason: '7 nodes x 3 stands');
        // And the blind sump is not a resting place at all: it has no groove
        // out of it, which is exactly why the backwash hands the lantern
        // back to the mouth before it.
        final gallery = game.layout.rooms['ghost_gallery']!;
        final blind = gallery.canalNodes
            .where((n) => n.isBasin && game.canalIsBlind(n.id))
            .single;
        expect(gallery.canalChannels.any((c) => c.from == blind.id), isFalse);
        expect(
          gallery.canalChannels.where((c) => c.to == blind.id).length,
          greaterThanOrEqualTo(2),
          reason:
              'the blind sump has to be somewhere the natural fall '
              'actually goes, or it teaches nothing',
        );
      },
    );

    test('Water S2: the solver walks the REAL spill rule, leg by leg', () {
      // The proof is only worth anything if it cannot drift away from what
      // the game plays. Replay the proved route through `canalSpillFrom` —
      // the same function the drift calls every frame — and it must land on
      // exactly the same grooves.
      final game = _waterProbe();
      final proof = game.solveLanternDrift();
      var at = 'spring';
      for (final leg in proof.route) {
        expect(leg.from, at, reason: 'the route must be connected');
        final spilled = game.canalSpillFrom(
          leg.from,
          water: leg.stand / 2,
          dammed: leg.dams.toSet(),
        );
        expect(
          spilled?.to,
          leg.to,
          reason:
              'leg $leg must be what the real rule does with that '
              'stand and those dams',
        );
        expect(
          game.canalChannelLive(leg.sill, leg.stand / 2),
          isTrue,
          reason: 'leg $leg must ride a groove that is actually running',
        );
        expect(
          game.canalChannelTorrent(leg.sill, leg.stand / 2),
          isFalse,
          reason: 'leg $leg must never be a drowned deep cut',
        );
        at = leg.to;
      }
      expect(at, 'sea');
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
      // Star 1 is the GEYSER FIELD now (the tile-lava causeway is retired).
      final causeway = steam.rooms['ember_causeway']!;
      expect(causeway.geysers.length, greaterThan(0));
      expect(causeway.capstone?.starIndex, 0);
      expect(
        causeway.geysers.where((g) => g.blockedAtStart).length,
        1,
        reason:
            'one mouth starts choked, so three bodies and one stone '
            'is exactly enough to shut the field',
      );
      // Star 2 is THE LAUNCH: risers throw the party over a chasm to the
      // pedestal on the far shore (the forge's tile-lava grid is retired).
      final forge = steam.rooms['cinder_forge']!;
      expect(forge.capstone?.starIndex, 1);
      expect(
        forge.geysers.where((g) => g.isRiser).length,
        2,
        reason: 'a long crossing and a short one — the ordering is the room',
      );
      expect(forge.platforms.length, 2, reason: 'two shores, one chasm');
      // Rite: the Crucible grid wakes the guardian (null star index).
      final crucible = steam.rooms['crucible']!.molten;
      expect(crucible, isNotNull);
      expect(crucible!.starIndex, isNull);
      // Star 2: Boilrog beyond, in the furnace-heart.
      final sg = steam.rooms['boiler_heart']!.guardian;
      expect(sg, isNotNull);
      expect(sg!.encounter?.mysticId, 'Boilrog');
    });

    test(
      'Steam ring-main is a true loop with a budget that cannot buy it all',
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
              reason:
                  '${room.id} seals a door to ${seal.targetRoomId} that '
                  'does not exist',
            );
            final other = steam.rooms[seal.targetRoomId]!;
            expect(
              other.pressureSeals.any(
                (s) => s.targetRoomId == room.id && s.cost == seal.cost,
              ),
              isTrue,
              reason:
                  'junction ${room.id}↔${seal.targetRoomId} must be '
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
      },
    );

    test('Steam molten grids are well-formed and solvable in shape', () {
      final steam = kPlanetDungeonLayouts['Steam']!;
      const legal = {'.', '#', 'X', 'L', 'P'};
      for (final room in steam.rooms.values) {
        final g = room.molten;
        if (g == null) continue;
        // Rectangular: every row the same width.
        for (final line in g.rows) {
          expect(
            line.length,
            g.cols,
            reason: '${room.id} molten rows must be equal-length',
          );
          for (final ch in line.split('')) {
            expect(
              legal.contains(ch),
              isTrue,
              reason: '${room.id} has illegal molten cell "$ch"',
            );
          }
        }
        // A star grid has exactly one pedestal; so does the rite grid.
        final pedestals = g.rows.fold<int>(
          0,
          (n, line) => n + 'P'.allMatches(line).length,
        );
        expect(
          pedestals,
          1,
          reason: '${room.id} must have exactly one pedestal',
        );
      }
    });

    test('Lightning circuit graphs are well-formed', () {
      final lightning = kPlanetDungeonLayouts['Lightning']!;
      for (final room in lightning.rooms.values) {
        final ids = {for (final n in room.circuitNodes) n.id};
        // Every wired link + mirror orientation points at a real node.
        for (final n in room.circuitNodes) {
          for (final l in n.links) {
            expect(
              ids.contains(l),
              isTrue,
              reason: '${room.id}/${n.id} links unknown node $l',
            );
          }
          for (final orient in n.orientationLinks) {
            for (final l in orient) {
              expect(
                ids.contains(l),
                isTrue,
                reason: '${room.id}/${n.id} orientation links unknown $l',
              );
            }
          }
          if (n.kind == CircuitNodeKind.mirror) {
            expect(
              n.orientationLinks.length,
              greaterThanOrEqualTo(2),
              reason: 'a mirror needs at least two orientations to route',
            );
          }
        }
        // Every powered barrier + cell socket references a real node. (The
        // beam maze's gate is driven by the beam engine, not a graph node.)
        for (final bar in room.poweredBarriers) {
          if (room.beamEmitters.isNotEmpty) continue;
          expect(
            ids.contains(bar.nodeId),
            isTrue,
            reason: '${room.id} barrier references unknown ${bar.nodeId}',
          );
        }
        for (final sock in room.cellSockets) {
          expect(
            ids.contains(sock.energizesNodeId),
            isTrue,
            reason: '${room.id} socket energizes unknown node',
          );
        }
      }
    });
  });

  // The reward popup names the star it is handing over, at the moment the
  // player is asking "what did I just get?". A blank name falls back to a
  // generic heading — not broken, but it wastes the one line they read.
  group('every star can name itself for the reward popup', () {
    test('no built dungeon has a blank or duplicated star name', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        final seen = <String>{};
        for (var i = 0; i < layout.stars.length; i++) {
          final name = layout.stars[i].name.trim();
          expect(
            name,
            isNotEmpty,
            reason: '$element star $i has no name for the reward popup',
          );
          expect(
            seen.add(name.toLowerCase()),
            isTrue,
            reason:
                '$element reuses the star name "$name" — the popup would '
                'read identically for two different accomplishments',
          );
        }
      });
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
