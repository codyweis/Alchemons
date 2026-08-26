// lib/games/planet_dungeon/dungeon_minimap.dart
//
// Room-scale dungeon minimap. Shows the current chamber, walls, doorways, star
// markers and live creature positions in the dark/alchemical palette. Modeled
// on the cosmic mini-map but fed dungeon-room data.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter/material.dart';

/// Short display labels per room — shared by the full map nodes and the
/// minimap caption.
const Map<String, String> kDungeonRoomLabels = {
  // Earth — The Buried Giant.
  'barrow_gate': 'BARROW',
  'sternum_court': 'STERNUM',
  'rib_hall': 'RIBS',
  'marrow_vault': 'MARROW',
  'pillar_crypt': 'CRYPT',
  'palm_hollow': 'PALM',
  'skull_antechamber': 'SKULL',
  'eye_chamber': 'EYE',
  'heart_chamber': 'HEART',
  // Water — Mirror-Tide Temple.
  'tide_gate': 'TIDE GATE',
  'drowned_court': 'COURT',
  'tide_works': 'SLUICES',
  'ghost_gallery': 'CURRENTS',
  'pearl_vault': 'PEARL',
  'reflection_court': 'MIRROR',
  'moon_hall': 'MOON HALL',
  'moon_well': 'WELL',
  'leviathan_depths': 'DEPTHS',
  // Fire — Cinder Cathedral.
  'narthex': 'NARTHEX',
  'nave': 'NAVE',
  'scriptorium': 'MURAL',
  'choir': 'CHOIR',
  'cloister': 'GARDEN',
  'reliquary': 'RELIQUARY',
  'vestry': 'VESTRY',
  'bell_gallery': 'BELLS',
  'high_altar': 'ALTAR',
  'sanctum': 'SANCTUM',
  // Air — Wind-Crown Spire.
  'entry': 'ENTRY',
  'hub': 'HUB',
  'spiral_cloud': 'SPIRAL',
  'ring_cloud': 'RING',
  'lower_spire': 'SPIRE',
  'feather_cloud': 'FEATHER',
  'crosswind_hall': 'GUST',
  'cloud_platforms': 'CLOUDS',
  'spire_summit': 'WIND STAR',
  'sky_loom': 'LOOM',
  'anvil_cloud': 'ANVIL',
  'veil_cloud': 'VEIL',
  'relic_chamber': 'RELIC',
  'storm_rune_hall': 'RUNES',
  'twin_conduit': 'CONDUITS',
  'storm_altar': 'ALTAR',
  'guardian_summit': 'GUARDIAN',
};

const Size _fullMapCanvasSize = Size(880, 980);
const double _fullMapPadding = 8;

/// Authored full-map atlases per planet element — hand-placed, not an
/// auto-layout graph. They follow each dungeon's room-door geography closely
/// enough that the full map feels like the dungeon the player is walking
/// through.
const Map<String, Map<String, Offset>> _fullMapNodePositionsByElement = {
  'Air': {
    'entry': Offset(0.10, 0.26),
    'hub': Offset(0.28, 0.26),
    'spiral_cloud': Offset(0.21, 0.09),
    'ring_cloud': Offset(0.36, 0.09),
    'lower_spire': Offset(0.48, 0.28),
    'feather_cloud': Offset(0.36, 0.43),
    'crosswind_hall': Offset(0.66, 0.18),
    'cloud_platforms': Offset(0.83, 0.18),
    'spire_summit': Offset(0.83, 0.06),
    'sky_loom': Offset(0.63, 0.52),
    'anvil_cloud': Offset(0.47, 0.67),
    'veil_cloud': Offset(0.73, 0.67),
    'relic_chamber': Offset(0.86, 0.46),
    'storm_rune_hall': Offset(0.82, 0.62),
    'twin_conduit': Offset(0.94, 0.70),
    'storm_altar': Offset(0.94, 0.88),
    'guardian_summit': Offset(0.80, 0.82),
  },
  'Fire': {
    'narthex': Offset(0.10, 0.56),
    'nave': Offset(0.34, 0.56),
    'scriptorium': Offset(0.22, 0.34),
    'choir': Offset(0.58, 0.64),
    'cloister': Offset(0.38, 0.80),
    'reliquary': Offset(0.60, 0.86),
    'vestry': Offset(0.44, 0.32),
    'bell_gallery': Offset(0.66, 0.22),
    'high_altar': Offset(0.86, 0.30),
    'sanctum': Offset(0.86, 0.10),
  },
  'Water': {
    'tide_gate': Offset(0.10, 0.54),
    'drowned_court': Offset(0.34, 0.54),
    'tide_works': Offset(0.26, 0.30),
    'ghost_gallery': Offset(0.60, 0.62),
    'pearl_vault': Offset(0.84, 0.66),
    'reflection_court': Offset(0.40, 0.80),
    'moon_hall': Offset(0.48, 0.28),
    'moon_well': Offset(0.70, 0.20),
    'leviathan_depths': Offset(0.86, 0.08),
  },
  'Earth': {
    'barrow_gate': Offset(0.10, 0.54),
    'sternum_court': Offset(0.34, 0.54),
    'rib_hall': Offset(0.28, 0.28),
    'marrow_vault': Offset(0.50, 0.16),
    'pillar_crypt': Offset(0.62, 0.62),
    'palm_hollow': Offset(0.40, 0.80),
    'skull_antechamber': Offset(0.52, 0.32),
    'eye_chamber': Offset(0.74, 0.22),
    'heart_chamber': Offset(0.88, 0.08),
  },
  'Lightning': {
    'arc_gate': Offset(0.10, 0.52),
    'dynamo_court': Offset(0.34, 0.52),
    'pylon_hall': Offset(0.28, 0.26),
    'capacitor_vault': Offset(0.46, 0.14),
    'cloud_works': Offset(0.58, 0.62),
    'mirror_gallery': Offset(0.44, 0.82),
    'overload_maze': Offset(0.66, 0.30),
    'storm_core': Offset(0.88, 0.16),
  },
  // The Steam full map draws its true topology: a RING around the crucible.
  'Steam': {
    'boiler_gate': Offset(0.08, 0.82),
    'manifold_south': Offset(0.50, 0.82),
    'ember_causeway': Offset(0.22, 0.48),
    'manifold_north': Offset(0.50, 0.14),
    'cinder_forge': Offset(0.78, 0.48),
    'crucible': Offset(0.50, 0.46),
    'boiler_heart': Offset(0.50, 0.64),
    'burst_vault': Offset(0.78, 0.86),
  },
};

/// Full-map section auras (wing groupings) per planet element.
const Map<String, List<(List<String>, Color)>> _fullMapSectionsByElement = {
  'Air': [
    (
      ['lower_spire', 'crosswind_hall', 'cloud_platforms', 'spire_summit'],
      Color(0xFF5BC8E8),
    ),
    (
      [
        'spiral_cloud',
        'ring_cloud',
        'feather_cloud',
        'sky_loom',
        'anvil_cloud',
        'veil_cloud',
        'relic_chamber',
      ],
      Color(0xFFE4C16A),
    ),
    (
      ['storm_rune_hall', 'twin_conduit', 'storm_altar', 'guardian_summit'],
      Color(0xFFFFFF8A),
    ),
  ],
  'Fire': [
    // The ritual wing (Ember Star).
    (['scriptorium', 'choir'], Color(0xFFFF8A50)),
    // The ash garden (Ash Star).
    (['cloister', 'reliquary'], Color(0xFF9CCC65)),
    // The vesper wing beyond the chancel gate (Pyre Star).
    (
      ['vestry', 'bell_gallery', 'high_altar', 'sanctum'],
      Color(0xFFFFD27A),
    ),
  ],
  'Water': [
    // The tide-works (Tide Star).
    (['tide_works'], Color(0xFF4AB8D8)),
    // The ghost wing (Current Star).
    (['ghost_gallery', 'pearl_vault'], Color(0xFFB8D8E8)),
    // Beyond the mirror gate (Deep Star).
    (
      ['moon_hall', 'moon_well', 'leviathan_depths'],
      Color(0xFFDCE8F0),
    ),
  ],
  'Earth': [
    // The rib hall + its vault (Marrow Star).
    (['rib_hall', 'marrow_vault'], Color(0xFFD8B878)),
    // The pillar crypt (Crystal Star).
    (['pillar_crypt'], Color(0xFFB8E0D8)),
    // Beyond the skull's jaw (Heart Star).
    (
      ['skull_antechamber', 'eye_chamber', 'heart_chamber'],
      Color(0xFFE4A86A),
    ),
  ],
  'Lightning': [
    // The pylon hall + capacitor vault (Circuit Star).
    (['pylon_hall', 'capacitor_vault'], Color(0xFF6BA8FF)),
    // The cloud works + mirror gallery (Storm Star).
    (['cloud_works', 'mirror_gallery'], Color(0xFFBFE6FF)),
    // Beyond the breaker gate (Overload Star).
    (['overload_maze', 'storm_core'], Color(0xFFE9D27A)),
  ],
  'Steam': [
    // The west arc (Causeway Star).
    (['ember_causeway'], Color(0xFF8FE0EC)),
    // The east arc (Cinder Star).
    (['cinder_forge'], Color(0xFFFFB46B)),
    // The ring's centre — the rite and the heart (Crucible Star).
    (['crucible', 'boiler_heart'], Color(0xFFD8B878)),
  ],
};

/// Derived chart positions, cached per element.
///
/// The authored atlases above cover the six planets that existed when the full
/// map was built. Every dungeon authored since had NO atlas, and the lookup
/// fell back to Offset(0.5, 0.5) PER ROOM — so all eleven charts drew every
/// room stacked on the exact same point in the middle. The map was not
/// mis-scaled, it was every node on top of every other one.
///
/// Rather than hand-place eleven more atlases (and a twelfth the next time
/// someone authors a planet), this lays the door graph out automatically:
/// breadth-first from the entrance, one row per step away from it. It is not
/// as pretty as a hand-tuned chart — it cannot know that Blood is a
/// figure-eight or Crystal a 3×3 — but it is honest about connectivity, which
/// is what the map is for, and it can never silently produce a single point.
final Map<String, Map<String, Offset>> _derivedNodeCache = {};

Map<String, Offset> _derivedNodePositions(String element) {
  final cached = _derivedNodeCache[element];
  if (cached != null) return cached;

  final out = <String, Offset>{};
  final layout = kPlanetDungeonLayouts[element];
  if (layout == null) return _derivedNodeCache[element] = out;

  // BFS from the entrance: depth becomes the row, so a chart reads top-down
  // as "how far in am I".
  final rows = <List<String>>[];
  final seen = <String>{layout.entranceRoomId};
  var frontier = <String>[layout.entranceRoomId];
  while (frontier.isNotEmpty) {
    rows.add(frontier);
    final next = <String>[];
    for (final id in frontier) {
      for (final door in layout.rooms[id]?.doors ?? const []) {
        if (layout.rooms.containsKey(door.targetRoomId) &&
            seen.add(door.targetRoomId)) {
          next.add(door.targetRoomId);
        }
      }
    }
    frontier = next;
  }
  // Anything the doors never reach still needs a spot — a room drawn off the
  // chart is worse than one on an extra row.
  final orphans = layout.rooms.keys.where((id) => !seen.contains(id)).toList();
  if (orphans.isNotEmpty) rows.add(orphans);

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    final y = (r + 0.5) / rows.length;
    for (var i = 0; i < row.length; i++) {
      out[row[i]] = Offset((i + 0.5) / row.length, y);
    }
  }
  return _derivedNodeCache[element] = out;
}

/// Test-only view of the placement above. The invariant worth guarding is
/// that two rooms never land on the same point — see
/// test/dungeon_full_map_chart_test.dart, which is the check that would have
/// caught eleven charts collapsing into a single dot.
@visibleForTesting
Offset debugFullMapNodePoint(String element, String roomId, Size size) =>
    _fullMapNodePoint(element, roomId, size);

Offset _fullMapNodePoint(String element, String roomId, Size size) {
  var atlas = _fullMapNodePositionsByElement[element] ?? const {};
  if (!atlas.containsKey(roomId)) atlas = _derivedNodePositions(element);
  final normalised = atlas[roomId] ?? const Offset(0.5, 0.5);
  final chart = (Offset.zero & size).deflate(_fullMapPadding);
  return Offset(
    chart.left + chart.width * normalised.dx,
    chart.top + chart.height * normalised.dy,
  );
}

class DungeonMiniMap extends StatelessWidget {
  const DungeonMiniMap({super.key, required this.game, this.boxSize = 132});

  final PlanetDungeonGame game;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boxSize,
      height: boxSize,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF080808).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF74613A).withValues(alpha: 0.7),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DungeonMiniMapPainter(game)),
          ),
          // Room caption so the chamber map reads at a glance.
          Positioned(
            left: 0,
            right: 0,
            bottom: 1,
            child: Text(
              kDungeonRoomLabels[game.currentRoomId] ??
                  game.currentRoomId.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFE4C16A).withValues(alpha: 0.85),
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          // Expand affordance — the minimap opens the full chart on tap.
          Positioned(
            top: 1,
            right: 1,
            child: Icon(
              Icons.open_in_full_rounded,
              size: 9,
              color: const Color(0xFFC4A35A).withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _DungeonMiniMapPainter extends CustomPainter {
  _DungeonMiniMapPainter(this.game);

  final PlanetDungeonGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final room = game.currentRoom;
    final b = room.bounds;
    final scale = (size.width / b.width).clamp(0.0, size.height / b.height);
    final drawW = b.width * scale;
    final drawH = b.height * scale;
    final ox = (size.width - drawW) / 2;
    final oy = (size.height - drawH) / 2;

    Offset map(Offset world) => Offset(
      ox + (world.dx - b.left) * scale,
      oy + (world.dy - b.top) * scale,
    );

    // Floor.
    final floor = Rect.fromLTWH(ox, oy, drawW, drawH);
    canvas.drawRect(floor, Paint()..color = const Color(0xFF14120E));
    canvas.drawRect(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF74613A).withValues(alpha: 0.6),
    );

    // Walls.
    final wallPaint = Paint()..color = const Color(0xFF2E2A23);
    for (final w in room.walls) {
      canvas.drawRect(
        Rect.fromPoints(map(w.topLeft), map(w.bottomRight)),
        wallPaint,
      );
    }

    // Doors (teal; star-locked doors render amber-dim).
    final doorPaint = Paint()
      ..color = const Color(0xFF5BC8E8).withValues(alpha: 0.85);
    final lockedPaint = Paint()
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.45);
    for (final d in room.doors) {
      if (game.isDoorHidden(room, d)) continue;
      canvas.drawRect(
        Rect.fromPoints(map(d.rect.topLeft), map(d.rect.bottomRight)),
        game.isDoorLocked(room, d) ? lockedPaint : doorPaint,
      );
    }

    // Star markers.
    for (final s in room.stars) {
      final earned = game.hasStar(s.starIndex);
      canvas.drawCircle(
        map(s.position),
        earned ? 2.0 : 3.0,
        Paint()
          ..color = const Color(
            0xFFE4C16A,
          ).withValues(alpha: earned ? 0.35 : 0.95),
      );
    }

    // Objective beacon: this chamber's unfinished business, so no room
    // ever reads as stale on the map.
    Offset? objective;
    if (room.anchors.isEmpty &&
        room.clouds.length == 1 &&
        !game.discoveredClouds.contains(room.clouds.first.id)) {
      objective = room.clouds.first.position; // sealed wonder trial
    } else if (room.summit != null && !game.hasStar(room.summit!.starIndex)) {
      objective = room.summit!.rect.center;
    } else if (room.loomStarIndex != null &&
        !game.hasStar(room.loomStarIndex!)) {
      objective = room.bounds.center;
    } else if (room.guardian != null &&
        !game.hasStar(room.guardian!.starIndex)) {
      objective = room.guardian!.position;
    } else if (room.conduits.isNotEmpty && !game.hasStar(2)) {
      objective = room.conduits.first.position;
    } else if (room.gustShrines.isNotEmpty && !game.hasStar(0)) {
      // The next sleeping gust shrine in this room (§6.11 REWORK — the sky
      // rings retired with Star 1's execution ascent).
      final sleeping = room.gustShrines
          .where((s) => !game.wokenGales.contains(s.wakesGale))
          .firstOrNull;
      if (sleeping != null) objective = sleeping.position;
    } else if (room.braziers.isNotEmpty &&
        room.brazierStarIndex == null &&
        !game.entryDoorRevealed) {
      objective = room.braziers.first.position; // the cold narthex hearth
    } else if (room.brazierStarIndex != null &&
        !game.hasStar(room.brazierStarIndex!)) {
      // The next brazier in the remembered order.
      for (final b in room.braziers) {
        if (b.order == game.ritualProgress) {
          objective = b.position;
          break;
        }
      }
    } else if (room.vineStarIndex != null &&
        !game.hasStar(room.vineStarIndex!)) {
      // The garth as a whole — its wind-cross, never "the next bed". Which bed
      // to work is the puzzle (cf. Water's course-ends rule); a beacon on it
      // would hand over a step of the plan for free.
      objective = room.windVane ?? room.bounds.center;
    } else if (room.incenseChains.isNotEmpty && !game.hasStar(2)) {
      for (final chain in room.incenseChains) {
        if (game.bellsRung.contains(chain.id)) continue;
        objective =
            game.vesperFlamePosition(chain.id) ??
            game.chainIgnitionPoint(chain);
        break;
      }
    } else if (room.sealStarIndex != null &&
        !game.hasStar(room.sealStarIndex!)) {
      for (final seal in room.tideSeals) {
        if (game.openedSeals.contains(seal.id)) continue;
        objective = seal.position;
        break;
      }
    } else if (room.canalStarIndex != null &&
        !game.hasStar(room.canalStarIndex!)) {
      // NEVER the next basin: which groove the water takes is the whole
      // puzzle, and a marker that answered it would hand the route over for
      // free. The marker names the network's ENDS instead — both carved
      // stone, both already in plain sight: the spring you set the lantern
      // in, then the sea drain you are steering it toward.
      final wantSpring = game.lanternNodeId == null || !game.lanternLit;
      for (final node in room.canalNodes) {
        if (wantSpring ? node.isSpring : node.isSea) {
          objective = node.position;
          break;
        }
      }
    } else if (room.moonPools.isNotEmpty && !game.hasStar(2)) {
      for (final pool in room.moonPools) {
        if (pool.isTrue && (game.poolStates[pool.id] ?? 0) != 1) {
          objective = pool.position;
          break;
        }
      }
    } else if (room.ribStarIndex != null &&
        !game.hasStar(room.ribStarIndex!)) {
      for (final rib in room.fossilRibs) {
        if ((game.ribNotches[rib.id] ?? 0) < rib.notches.length - 1) {
          objective = rib.notches[(game.ribNotches[rib.id] ?? 0)];
          break;
        }
      }
      objective ??= room.sternumPlate?.center; // bridged — go claim it
    } else if (room.pillarStarIndex != null &&
        !game.hasStar(room.pillarStarIndex!)) {
      for (final pillar in room.fossilPillars) {
        if (!game.lockedPillars.contains(pillar.id)) {
          objective = pillar.position;
          break;
        }
      }
    } else if (room.stoneScale != null && !game.hasStar(2)) {
      objective = room.stoneScale!.position;
    } else if (room.cellSockets.isNotEmpty &&
        room.circuitStarIndex != null &&
        !game.hasStar(room.circuitStarIndex!)) {
      // Storm Star: the next un-energized socket.
      for (final sock in room.cellSockets) {
        if (game.energizedSockets.contains(sock.id)) continue;
        objective = sock.position;
        break;
      }
    } else if (room.beamEmitters.isNotEmpty &&
        room.circuitStarIndex != null &&
        !game.hasStar(room.circuitStarIndex!)) {
      // Circuit Star (pylon beam): the pylon to charge + route from.
      objective = room.beamEmitters.first.position;
    } else if (room.circuitStarIndex != null &&
        !game.hasStar(room.circuitStarIndex!)) {
      // Circuit Star: the source pylon to charge.
      for (final n in room.circuitNodes) {
        if (n.kind == CircuitNodeKind.source) {
          objective = n.position;
          break;
        }
      }
    } else if (room.poweredBarriers.isNotEmpty && !game.hasStar(2)) {
      // Overload maze: the maze pylon to charge + route.
      for (final n in room.circuitNodes) {
        if (n.kind == CircuitNodeKind.source) {
          objective = n.position;
          break;
        }
      }
    } else if (room.stormCells.isNotEmpty) {
      // Mirror gallery: the next hidden storm-cell to bare.
      for (final cell in room.stormCells) {
        if (game.discoveredClouds.contains(cell.id)) continue;
        objective = cell.position;
        break;
      }
    } else if (room.molten != null) {
      // Molten Labyrinth: the goal pedestal, until the room is solved.
      final g = room.molten!;
      final done = g.starIndex != null
          ? game.hasStar(g.starIndex!)
          : game.moltenRiteDone;
      if (!done) {
        for (var r = 0; r < g.rowCount; r++) {
          final i = g.rows[r].indexOf('P');
          if (i < 0) continue;
          final cw = room.bounds.width / g.cols;
          final ch = room.bounds.height / g.rowCount;
          objective = Offset(room.bounds.left + (i + 0.5) * cw,
              room.bounds.top + (r + 0.5) * ch);
          break;
        }
      }
    }
    if (objective != null) {
      final p = map(objective);
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFFE4C16A).withValues(alpha: 0.8),
      );
      canvas.drawCircle(
        p,
        1.6,
        Paint()..color = const Color(0xFFE4C16A).withValues(alpha: 0.95),
      );
    }

    // Creatures (active = amber, others element-tinted).
    for (var i = 0; i < game.creatures.length; i++) {
      final c = game.creatures[i];
      final isActive = i == game.activeIndex;
      canvas.drawCircle(
        map(c.position),
        isActive ? 3.0 : 2.0,
        Paint()
          ..color = isActive
              ? const Color(0xFFE4C16A)
              : elementColor(c.member.element).withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DungeonMiniMapPainter oldDelegate) => true;
}

class DungeonFullMap extends StatefulWidget {
  const DungeonFullMap({super.key, required this.game, required this.onClose});

  final PlanetDungeonGame game;
  final VoidCallback onClose;

  @override
  State<DungeonFullMap> createState() => _DungeonFullMapState();
}

class _DungeonFullMapState extends State<DungeonFullMap> {
  final TransformationController _mapController = TransformationController();
  String? _centeredRoomId;
  Size? _centeredViewport;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _centerOnCurrentRoom(Size viewport) {
    final roomId = widget.game.currentRoomId;
    if (_centeredRoomId == roomId && _centeredViewport == viewport) return;
    _centeredRoomId = roomId;
    _centeredViewport = viewport;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scale = (viewport.width / 540).clamp(0.56, 0.78).toDouble();
      final node = _fullMapNodePoint(
        widget.game.layout.element,
        roomId,
        _fullMapCanvasSize,
      );
      final tx = viewport.width / 2 - node.dx * scale;
      final ty = viewport.height / 2 - node.dy * scale;
      _mapController.value = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(0, 3, tx)
        ..setEntry(1, 3, ty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 28, 410.0);
    final height = math.min(screen.height - 70, 620.0);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080808).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFC4A35A).withValues(alpha: 0.68),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5BC8E8).withValues(alpha: 0.16),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.game.layout.title,
                  style: const TextStyle(
                    color: Color(0xFFE8DFC8),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14120E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF74613A).withValues(alpha: 0.7),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Color(0xFFE4C16A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _centerOnCurrentRoom(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  return InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(140),
                    minScale: 0.46,
                    maxScale: 1.7,
                    transformationController: _mapController,
                    child: CustomPaint(
                      size: _fullMapCanvasSize,
                      painter: _DungeonFullMapPainter(widget.game),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DRAG / PINCH MAP',
            style: TextStyle(
              color: const Color(0xFFE8DFC8).withValues(alpha: 0.46),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const _FullMapLegend(),
        ],
      ),
    );
  }
}

class _FullMapLegend extends StatelessWidget {
  const _FullMapLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 5,
      children: const [
        _LegendChip(color: Color(0xFFE4C16A), label: 'CURRENT'),
        _LegendChip(color: Color(0xFF5BC8E8), label: 'DISCOVERED'),
        _LegendChip(color: Color(0xFF22C55E), label: 'STAR DONE'),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFE8DFC8).withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _DungeonFullMapPainter extends CustomPainter {
  _DungeonFullMapPainter(this.game);

  final PlanetDungeonGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final element = game.layout.element;
    final atlas = _fullMapNodePositionsByElement[element] ?? const {};
    final positions = {
      for (final entry in atlas.entries)
        if (game.layout.rooms.containsKey(entry.key))
          entry.key: _fullMapNodePoint(element, entry.key, size),
    };

    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF101928), Color(0xFF090B10)],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      background,
    );

    final sections =
        _fullMapSectionsByElement[element] ?? const <(List<String>, Color)>[];
    for (final (ids, color) in sections) {
      _drawSectionAura(canvas, positions, ids, color);
    }

    _drawEdges(canvas, positions);
    for (final id in positions.keys) {
      _drawNode(canvas, positions[id]!, id);
    }
  }

  void _drawSectionAura(
    Canvas canvas,
    Map<String, Offset> positions,
    List<String> ids,
    Color color,
  ) {
    final points = ids.map((id) => positions[id]).whereType<Offset>().toList();
    if (points.isEmpty) return;
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final aura = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(aura, const Radius.circular(28)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.10),
    );
  }

  void _drawEdges(Canvas canvas, Map<String, Offset> positions) {
    final seen = <String>{};
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    for (final room in game.layout.rooms.values) {
      final from = positions[room.id];
      if (from == null) continue;
      for (final door in room.doors) {
        final to = positions[door.targetRoomId];
        if (to == null) continue;
        final key = room.id.compareTo(door.targetRoomId) < 0
            ? '${room.id}:${door.targetRoomId}'
            : '${door.targetRoomId}:${room.id}';
        if (!seen.add(key)) continue;
        final active =
            room.id == game.currentRoomId ||
            door.targetRoomId == game.currentRoomId;
        paint.color =
            (active ? const Color(0xFF5BC8E8) : const Color(0xFF74613A))
                .withValues(alpha: active ? 0.62 : 0.34);
        final path = Path()..moveTo(from.dx, from.dy);
        final control = _edgeControl(room.id, door.targetRoomId, from, to);
        path.quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  Offset _edgeControl(String a, String b, Offset from, Offset to) {
    final mid = Offset.lerp(from, to, 0.5)!;
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final distance = (to - from).distance;
    if (distance < 95) return mid;

    final key = a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';
    final bend = switch (key) {
      'hub:sky_loom' => const Offset(-50, 22),
      'sky_loom:spire_summit' => const Offset(46, 64),
      'crosswind_hall:lower_spire' => const Offset(16, -42),
      'guardian_summit:storm_altar' => const Offset(-38, -30),
      _ => Offset(-dy, dx) / distance * 18,
    };
    return mid + bend;
  }

  void _drawNode(Canvas canvas, Offset c, String id) {
    final room = game.layout.rooms[id]!;
    final current = id == game.currentRoomId;
    final star =
        room.summit?.starIndex ??
        room.loomStarIndex ??
        room.brazierStarIndex ??
        room.vineStarIndex ??
        room.sealStarIndex ??
        room.canalStarIndex ??
        room.ribStarIndex ??
        room.pillarStarIndex ??
        room.guardian?.starIndex;
    final starDone = star != null && game.hasStar(star);
    final cloudTouched =
        room.clouds.isNotEmpty &&
        room.clouds.any(
          (cloud) =>
              game.discoveredClouds.contains(cloud.id) ||
              game.placedClouds.contains(cloud.id),
        );
    final stormLive =
        room.conduits.isNotEmpty &&
        (game.altarOpen || game.conduitEnergy.isNotEmpty);

    final color = current
        ? const Color(0xFFE4C16A)
        : starDone
        ? const Color(0xFF22C55E)
        : stormLive
        ? const Color(0xFFFFFF8A)
        : cloudTouched
        ? const Color(0xFF5BC8E8)
        : const Color(0xFF74613A);
    final radius = current ? 10.5 : 8.0;

    if (current || starDone || stormLive) {
      canvas.drawCircle(
        c,
        radius + 8,
        Paint()..color = color.withValues(alpha: current ? 0.18 : 0.10),
      );
    }
    canvas.drawCircle(c, radius, Paint()..color = const Color(0xFF14120E));
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = current ? 2.4 : 1.5
        ..color = color.withValues(alpha: current ? 0.95 : 0.72),
    );

    if (star != null) {
      _drawStar(canvas, c, starDone ? 4.2 : 3.5, color);
    } else if (room.clouds.isNotEmpty) {
      canvas.drawCircle(
        c,
        3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.8),
      );
    } else if (room.conduits.isNotEmpty || room.guardian != null) {
      canvas.drawLine(
        c + const Offset(-3, 3),
        c + const Offset(2, -4),
        Paint()
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.9),
      );
      canvas.drawLine(
        c + const Offset(2, -4),
        c + const Offset(5, 1),
        Paint()
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.9),
      );
    }

    _drawLabel(
      canvas,
      c + Offset(0, current ? 20 : 17),
      kDungeonRoomLabels[id] ?? id,
    );
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.86));
  }

  void _drawLabel(Canvas canvas, Offset center, String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFE8DFC8).withValues(alpha: 0.72),
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 62);
    tp.paint(canvas, center - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _DungeonFullMapPainter oldDelegate) => true;
}
