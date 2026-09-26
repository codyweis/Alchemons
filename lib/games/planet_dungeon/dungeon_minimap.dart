import 'package:alchemons/audio/audio.dart';
// lib/games/planet_dungeon/dungeon_minimap.dart
//
// Room-scale dungeon minimap. Shows the current chamber, walls, doorways, star
// markers and live creature positions in the dark/alchemical palette. Modeled
// on the cosmic mini-map but fed dungeon-room data.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_chart_layout.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_popup_chrome.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dust.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_mud.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter/material.dart';

/// Short display labels per room — shared by the full map nodes and the
/// minimap caption.
const Map<String, String> kDungeonRoomLabels = {
  // EVERY ROOM IS NAMED. 124 of the 169 rooms had no label at all, so the
  // minimap caption was blank for three quarters of the game — which is half
  // of why a player reported walking through a door and not knowing where
  // they were. The other half was the room-entry line, which had stopped
  // appearing (see `_announceRoomEntry`). A room's label is its IDENTITY and
  // is always available; its objective line is its GOAL and only exists when
  // the room has one.
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
  // Lightning — Storm Circuit.
  'arc_gate': 'ARC GATE',
  'dynamo_court': 'DYNAMO',
  'pylon_hall': 'PYLONS',
  'capacitor_vault': 'VAULT',
  'cloud_works': 'CLOUD WORKS',
  'overload_maze': 'OVERLOAD',
  'storm_core': 'CORE',
  // Steam — Molten Labyrinth.
  'boiler_gate': 'BOILER GATE',
  'manifold_south': 'S MANIFOLD',
  'ember_causeway': 'CAUSEWAY',
  'cinder_forge': 'FORGE',
  'manifold_north': 'N MANIFOLD',
  'scald_cellar': 'CELLAR',
  'crucible': 'CRUCIBLE',
  'burst_vault': 'BURST VAULT',
  'boiler_heart': 'HEART',
  // Lava — Molten Reliquary.
  'tap_head': 'TAP HEAD',
  'switch_yard': 'SWITCH YARD',
  'chill_house': 'CHILL HOUSE',
  'stamp_mill': 'STAMP MILL',
  'mold_floor': 'MOULD FLOOR',
  'slag_reliquary': 'SLAG VAULT',
  'pour_heart': 'POUR HEART',
  // Poison — Venom Monastery.
  'lazar_gate': 'LAZAR GATE',
  'ambulatory': 'AMBULATORY',
  'apothecary': 'APOTHECARY',
  'ward_bell': 'BELL WARD',
  'ward_scriptorium': 'SCRIPTORIUM',
  'ward_refectory': 'REFECTORY',
  'ward_charnel': 'CHARNEL',
  'lazar_crypt': 'CRYPT',
  // Ice — Frozen Observatory.
  // NOTE: this map is keyed by ROOM ID ALONE, so two planets that use the
  // same id share one label. `mirror_gallery` is the only such collision
  // today — Lightning's and Ice's are both mirror galleries, so one name
  // serves — but a future planet reusing an existing id will silently
  // inherit its caption.
  'mirror_gallery': 'MIRRORS',
  'rime_head': 'RIME HEAD',
  'shelf_glass': 'GLASS SHELF',
  'shelf_lens': 'LENS SHELF',
  'orrery_floor': 'ORRERY',
  'cold_sump': 'SUMP',
  'star_font': 'STAR FONT',
  'frowyrm_hollow': 'HOLLOW',
  // Mud — The Sinking Altar.
  'mire_gate': 'MIRE GATE',
  'hag_knoll': 'HAG KNOLL',
  'reed_knoll': 'REED KNOLL',
  'altar_knoll': 'THE ALTAR',
  'sedge_knoll': 'SEDGE KNOLL',
  'cairn_knoll': 'CAIRN KNOLL',
  'lotus_knoll': 'LOTUS KNOLL',
  'sunken_lotus': 'SUNKEN LOTUS',
  'drowned_fane': 'DROWNED FANE',
  'bogdrya_hollow': 'HOLLOW',
  // Dust — Ruins of Time.
  'ashen_gate': 'ASHEN GATE',
  'seal_street': 'SEAL STREET',
  'roof_walk': 'ROOF WALK',
  'high_terrace': 'TERRACE',
  'sand_court': 'SAND COURT',
  'windcatch': 'WINDCATCH',
  'undercity': 'UNDERCITY',
  'granary': 'GRANARY',
  'observatory': 'OBSERVATORY',
  'kiln_cellar': 'KILN',
  'sunken_house': 'SUNKEN HOUSE',
  'ashdjinn_hollow': 'HOLLOW',
  // Crystal — Prism Labyrinth.
  'facet_gate': 'FACET GATE',
  'keep_nw': 'NW CELL',
  'keep_n': 'N CELL',
  'keep_ne': 'NE CELL',
  'keep_w': 'W CELL',
  'keep_core': 'CORE',
  'keep_e': 'E CELL',
  'keep_sw': 'SW CELL',
  'keep_s': 'S CELL',
  'keep_se': 'SE CELL',
  'tuning_hall': 'TUNING HALL',
  'prismalith_choir': 'CHOIR',
  // Plant — Verdant Crypt.
  'root_porch': 'ROOT PORCH',
  'mosswalk': 'MOSSWALK',
  'fern_gallery': 'FERNS',
  'pollen_stair': 'POLLEN STAIR',
  'crypt_niche': 'NICHE',
  'lantern_court': 'LANTERNS',
  'islet': 'ISLET',
  'gourd_hollow': 'GOURD',
  'bloom_hall': 'BLOOM HALL',
  'botanica_heart': 'HEART',
  // Spirit — The Echo Grave.
  'lych_gate': 'LYCH GATE',
  'barrow_urn': 'URN BARROW',
  'barrow_bell': 'BELL BARROW',
  'barrow_veil': 'VEIL BARROW',
  'barrow_mere': 'MERE BARROW',
  'barrow_cairn': 'CAIRN BARROW',
  'barrow_ash': 'ASH BARROW',
  'barrow_watch': 'WATCH BARROW',
  'hollow_grave': 'HOLLOW GRAVE',
  'mourners_walk': 'MOURNERS',
  'wraithord_grave': 'THE GRAVE',
  // Dark — Eclipse Vault.
  'pall_porch': 'PALL PORCH',
  'analemma_court': 'ANALEMMA',
  'shade_gallery': 'SHADE GALLERY',
  'penumbral_walk': 'PENUMBRA',
  'gnomon_stair': 'GNOMON STAIR',
  'ossuary_ring': 'OSSUARY',
  'abyssal_font': 'FONT',
  'umbral_reliquary': 'UMBRAL VAULT',
  'eclipse_nave': 'NAVE',
  'noctryos_totality': 'TOTALITY',
  // Light — Beacon Archive.
  'lumen_threshold': 'THRESHOLD',
  'shadow_court': 'SHADOW COURT',
  'moth_gallery': 'MOTH GALLERY',
  'dark_stacks': 'DARK STACKS',
  'catalogue_walk': 'CATALOGUE',
  'oculus_stair': 'OCULUS STAIR',
  'sunless_reliquary': 'SUNLESS VAULT',
  'reading_floor': 'READING FLOOR',
  'solarin_oculus': 'THE OCULUS',
  // Blood — Hemavorn.
  'pericard_gate': 'PERICARD GATE',
  'arterial_run': 'ARTERIAL RUN',
  'aortic_arch': 'AORTIC ARCH',
  'vena_crossing': 'VENA CROSSING',
  'pulmonic_stair': 'PULMONIC STAIR',
  'capillary_weave': 'CAPILLARIES',
  'atrial_gallery': 'ATRIUM',
  'myocardium': 'MYOCARDIUM',
  'auricle_reliquary': 'AURICLE VAULT',
  'sanguorath_systole': 'SYSTOLE',
};

/// Test-only view of a room's centre on the expanded map, scaled onto
/// [size]. The invariant worth guarding is that two rooms never land on the
/// same point — see test/dungeon_full_map_chart_test.dart, which is the check
/// that would have caught eleven charts collapsing into a single dot.
@visibleForTesting
Offset debugFullMapNodePoint(String element, String roomId, Size size) {
  final chart = dungeonChartFor(element);
  final box = chart.rooms[roomId];
  if (box == null) return size.center(Offset.zero);
  final k = math.min(
    size.width / chart.size.width,
    size.height / chart.size.height,
  );
  return box.center * k;
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
        color: CosmicScreenStyles.bg1.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CosmicScreenStyles.borderAccent.withValues(alpha: 0.7),
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
                color: CosmicScreenStyles.amberBright.withValues(alpha: 0.9),
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
              color: CosmicScreenStyles.amber.withValues(alpha: 0.7),
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
    canvas.drawRect(floor, Paint()..color = CosmicScreenStyles.bg2);
    canvas.drawRect(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = CosmicScreenStyles.borderAccent.withValues(alpha: 0.6),
    );

    // Walls.
    final wallPaint = Paint()..color = CosmicScreenStyles.bg3;
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
      // A chromeless way through is not painted as a door in the room, and
      // must not be painted as one here either — the chart would give away
      // a secret the room deliberately does not.
      if (d.chromeless) continue;
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
        // A LISTENING basin, not a "true" one — and only the ones this run
        // actually rolled, so the marker cannot point at a deaf basin.
        if (game.poolWants.containsKey(pool.id) &&
            (game.poolStates[pool.id] ?? 0) != 1) {
          objective = pool.position;
          break;
        }
      }
    } else if (room.ribStarIndex != null && !game.hasStar(room.ribStarIndex!)) {
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
          objective = Offset(
            room.bounds.left + (i + 0.5) * cw,
            room.bounds.top + (r + 0.5) * ch,
          );
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

  /// The opening zoom: the whole chart if it fits at a readable size, and
  /// never smaller than that — a map you have to squint at is not a map.
  double _openingScale(Size viewport, Size chart) {
    final fit = math.min(
      viewport.width / chart.width,
      viewport.height / chart.height,
    );
    return fit.clamp(_kReadableScale, 1.0);
  }

  void _centerOnCurrentRoom(Size viewport, DungeonChart chart) {
    final roomId = widget.game.currentRoomId;
    // (Re-centres whenever you have moved room since the map last opened.)
    if (_centeredRoomId == roomId && _centeredViewport == viewport) return;
    _centeredRoomId = roomId;
    _centeredViewport = viewport;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Open on what you KNOW: rooms behind undiscovered doors are not drawn,
      // and fitting the whole canvas early in a run showed one room lost in
      // an empty chart.
      final known = _knownRoomsOf(widget.game);
      Rect? area;
      for (final id in known) {
        final r = chart.rooms[id];
        if (r == null) continue;
        area = area == null ? r : area.expandToInclude(r);
      }
      area = (area ?? Offset.zero & chart.size).inflate(kChartUnit * 0.6);
      final scale = _openingScale(viewport, area.size);
      final box = chart.rooms[roomId];
      final focus =
          area.width * scale <= viewport.width &&
              area.height * scale <= viewport.height
          ? area.center
          : (box?.center ?? area.center);
      // Centre on you, but never scroll past the chart's own edge when the
      // whole thing fits — a map that opens hanging off one side looks lost.
      // Centre on the focus, but keep the known area filling the panel on
      // any axis where it is bigger than the panel (no dark gutter above a
      // wide chart), and centred on any axis where it fits.
      double axis(double view, double lo, double hi, double f) {
        final len = (hi - lo) * scale;
        if (len <= view) return view / 2 - (lo + hi) / 2 * scale;
        return (view / 2 - f * scale).clamp(view - hi * scale, -lo * scale);
      }

      final tx = axis(viewport.width, area.left, area.right, focus.dx);
      final ty = axis(viewport.height, area.top, area.bottom, focus.dy);
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
    final width = math.min(screen.width - 28, 460.0);
    final height = math.min(screen.height - 70, 660.0);
    final chart = dungeonChartFor(widget.game.layout.element);

    // The survival plate: near-black, bracket corners, monospace head.
    return CustomPaint(
      painter: DungeonBracketPainter(
        color: CosmicScreenStyles.amber.withValues(alpha: 0.7),
        bracketSize: 14,
        strokeWidth: 1.2,
      ),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: CosmicScreenStyles.bg0.withValues(alpha: 0.96),
          border: Border.all(
            color: CosmicScreenStyles.amber.withValues(alpha: 0.30),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.map_rounded,
                  color: CosmicScreenStyles.amberBright,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.game.layout.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: CosmicScreenStyles.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'DUNGEON MAP',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: CosmicScreenStyles.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: context.soundAction(widget.onClose),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CosmicScreenStyles.bg2,
                      border: Border.all(
                        color: CosmicScreenStyles.borderAccent,
                      ),
                    ),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: CosmicScreenStyles.amberBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ColoredBox(
                  color: CosmicScreenStyles.bg0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      _centerOnCurrentRoom(viewport, chart);
                      final fit = math.min(
                        viewport.width / chart.size.width,
                        viewport.height / chart.size.height,
                      );
                      return InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(60),
                        minScale: math.min(fit, _kReadableScale) * 0.9,
                        maxScale: 1.8,
                        transformationController: _mapController,
                        child: CustomPaint(
                          size: chart.size,
                          painter: _DungeonFullMapPainter(widget.game),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _FullMapLegend(
              fen: widget.game.layout.element == 'Mud',
              vault: widget.game.layout.element == 'Dark',
              archive: widget.game.layout.element == 'Light',
            ),
          ],
        ),
      ),
    );
  }
}

/// The smallest zoom the map opens at: room names stay about 7-8 real
/// pixels tall on the canvas's 11px label.
const double _kReadableScale = 0.62;

class _FullMapLegend extends StatelessWidget {
  const _FullMapLegend({
    this.fen = false,
    this.vault = false,
    this.archive = false,
  });

  /// Palusia adds the basin mark to the key.
  final bool fen;

  /// Nythralor adds its quarter marks and its portals.
  final bool vault;

  /// The archive adds its bay-light marks.
  final bool archive;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 5,
      children: [
        const _LegendChip(color: _kMapCurrent, label: 'YOU'),
        const _LegendChip(color: _kMapVisited, label: 'VISITED'),
        const _LegendChip(color: _kMapUnvisited, label: 'NOT YET'),
        const _LegendChip(color: _kMapStarDone, label: 'STAR WON', star: true),
        const _LegendChip(color: _kMapStarOpen, label: 'STAR HERE', star: true),
        if (fen) ...const [
          _LegendChip(
            color: CosmicScreenStyles.teal,
            label: 'BASIN NEEDS',
            ring: true,
          ),
          _LegendChip(
            color: CosmicScreenStyles.danger,
            label: 'WOULD DROWN',
            ring: true,
          ),
        ],
        if (vault) ...const [
          _LegendChip(color: Color(0xFFA884E0), label: 'IN SHADOW', ring: true),
          _LegendChip(color: Color(0xFFD9D2BC), label: 'IN LIGHT', ring: true),
          _LegendChip(color: Color(0xFFA884E0), label: 'PORTAL'),
        ],
        if (archive) ...const [
          _LegendChip(color: Color(0xFFFFE082), label: 'BAY LIT', ring: true),
          _LegendChip(
            color: Color(0xFF5C6270),
            label: 'BAY DARK',
            ring: true,
          ),
        ],
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    this.star = false,
    this.ring = false,
  });

  /// A round mark, as the fen's crossing marks are drawn.
  final bool ring;

  final Color color;
  final String label;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        star
            ? Icon(Icons.star_rounded, size: 11, color: color)
            : ring
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.8),
                ),
              )
            : Container(
                width: 10,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: color, width: 1.4),
                ),
              ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: CosmicScreenStyles.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// THE SURVIVAL PALETTE. The map was warm brown on brown (panel 12100C, rooms
// 1C1912, lines B8A57A) — the house style from before cosmic and survival
// moved to cool near-black grounds with bright ink, and next to them it read
// as a screen from an older game. Same tokens as the survival dialogs now.
const Color _kMapCurrent = CosmicScreenStyles.amberBright;
const Color _kMapVisited = CosmicScreenStyles.amber;
const Color _kMapUnvisited = CosmicScreenStyles.borderMid;
const Color _kMapStarDone = CosmicScreenStyles.success;
const Color _kMapStarOpen = CosmicScreenStyles.amberBright;

/// Test seam: run the REAL full-map painter over a canvas.
///
/// `debugFullMapNodePoint` proves the placement helper, and the placement
/// helper was never the thing that was broken — the painter was, by not
/// calling it. Anything that claims the map draws has to go through this.
/// The chart is scaled to fit [size].
@visibleForTesting
void debugPaintFullMap(PlanetDungeonGame game, Canvas canvas, Size size) {
  final chart = dungeonChartFor(game.layout.element);
  final k = math.min(
    size.width / chart.size.width,
    size.height / chart.size.height,
  );
  canvas.save();
  canvas.scale(k);
  _DungeonFullMapPainter(game).paint(canvas, chart.size);
  canvas.restore();
}

/// How Palusia's chart draws one crossing. See `_fenEdgeState`.
enum _FenEdge { mire, sod, drowned, plank }

/// Every star a room holds, across all seventeen planets' fixtures. Each
/// planet keeps its star on a different object; the map needs one answer.
List<int> _roomStars(DungeonRoom room) => [
  ?room.summit?.starIndex,
  ?room.loomStarIndex,
  ?room.brazierStarIndex,
  ?room.vineStarIndex,
  ?room.sealStarIndex,
  ?room.canalStarIndex,
  ?room.ribStarIndex,
  ?room.pillarStarIndex,
  ?room.circuitStarIndex,
  ?room.garth?.starIndex,
  ?room.capstone?.starIndex,
  ?room.molten?.starIndex,
  ?room.foundryStar?.starIndex,
  ?room.priorsSeal?.diagnosisStarIndex,
  ?room.priorsSeal?.triageStarIndex,
  ?room.rime?.starIndex,
  ?room.fen?.altar?.sarsenStarIndex,
  ?room.fen?.altar?.moorStarIndex,
  ?room.grove?.starIndex,
  ?room.eclipse?.starIndex,
  ?room.hall?.starIndex,
  ?room.sanguine?.starIndex,
  ?room.ruins?.starIndex,
  ?room.prism?.keep?.spectrumStarIndex,
  ?room.prism?.keep?.throneStarIndex,
  ?room.grave?.vigil?.roadStarIndex,
  ?room.grave?.vigil?.sigilStarIndex,
  ?room.guardian?.starIndex,
];

/// The rooms the map is allowed to show: everywhere you have stood, and
/// everything reachable from there through doors you can SEE (the whole
/// map is still a planning tool — Palusia's strategy is the shape of the
/// fen — so this is not fog of war). A room that only a
/// hidden door reaches — a vault behind a false wall, a crossing under
/// weed — stays off the chart until it is found, instead of floating on it
/// unconnected and giving the secret away.
Set<String> _knownRoomsOf(PlanetDungeonGame game) {
  final layout = game.layout;
  final known = <String>{
    layout.entranceRoomId,
    game.currentRoomId,
    ...game.visitedRooms,
  };
  final frontier = [...known];
  while (frontier.isNotEmpty) {
    final id = frontier.removeLast();
    final room = layout.rooms[id];
    if (room == null) continue;
    for (final d in room.doors) {
      if (d.chromeless || game.isDoorHidden(room, d)) continue;
      final to = layout.rooms[d.targetRoomId];
      if (to == null || known.contains(to.id)) continue;
      // Seen from this side, but is it hidden from the far side too?
      if (to.doors.any(
        (b) => b.targetRoomId == id && game.isDoorHidden(to, b),
      )) {
        continue;
      }
      known.add(to.id);
      frontier.add(to.id);
    }
  }
  return known;
}

class _DungeonFullMapPainter extends CustomPainter {
  _DungeonFullMapPainter(this.game);

  final PlanetDungeonGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = dungeonChartFor(game.layout.element);
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CosmicScreenStyles.bg1, CosmicScreenStyles.bg0],
        ).createShader(rect),
    );
    _drawGrid(canvas, size);
    // Each level below the first gets a faint rule above it.
    for (final y in chart.levelBreaks) {
      _drawDashed(
        canvas,
        Path()
          ..moveTo(24, y)
          ..lineTo(size.width - 24, y),
        Paint()
          ..strokeWidth = 1.2
          ..color = CosmicScreenStyles.amber.withValues(alpha: 0.2),
      );
    }
    final known = _knownRoomsOf(game);
    final hatches = <String, Color>{};
    final fenMarks = <(Offset, BogFord)>[];
    final ruinsMarks = <(Offset, MoundState)>[];
    _drawCorridors(canvas, chart, hatches, known, fenMarks, ruinsMarks);
    for (final e in chart.rooms.entries) {
      if (!known.contains(e.key)) continue;
      final room = game.layout.rooms[e.key];
      if (room != null) _drawRoom(canvas, e.value, room);
    }
    if (game.layout.element == 'Dark') _drawVaultPortals(canvas, chart, known);
    // Hatches sit INSIDE their rooms, so they go on after the room fills.
    _drawFenMarks(canvas, fenMarks);
    _drawRuinsMarks(canvas, ruinsMarks);
    hatches.forEach((id, color) {
      final box = chart.rooms[id];
      if (box == null || !known.contains(id)) return;
      _drawHatch(canvas, Offset(box.left + 14, box.bottom - 14), color);
    });
  }

  /// A faint surveyor's grid, so the empty space reads as parchment and not
  /// as a void — drawn once as lines, no blur.
  void _drawGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 1
      ..color = CosmicScreenStyles.teal.withValues(alpha: 0.035);
    for (var x = kChartUnit / 2; x < size.width; x += kChartUnit / 2) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = kChartUnit / 2; y < size.height; y += kChartUnit / 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  /// Where a door sits on its room's box on the chart. A wall door is pinned
  /// to that wall; a hatch sits inside the box where it sits in the room.
  Offset _doorPoint(Rect box, DungeonRoom room, Rect door) {
    final b = room.bounds;
    final fx = ((door.center.dx - b.left) / b.width).clamp(0.08, 0.92);
    final fy = ((door.center.dy - b.top) / b.height).clamp(0.12, 0.88);
    return switch (chartDoorWall(b, door)) {
      'W' => Offset(box.left, box.top + box.height * fy),
      'E' => Offset(box.right, box.top + box.height * fy),
      'N' => Offset(box.left + box.width * fx, box.top),
      'S' => Offset(box.left + box.width * fx, box.bottom),
      _ => Offset(box.left + box.width * fx, box.top + box.height * fy),
    };
  }

  /// Where a door lands in the next room, on the chart: the arrival point,
  /// pushed to the wall it is nearest.
  Offset _arrivalPoint(Rect box, DungeonRoom room, Offset spawn) {
    final b = room.bounds;
    final fx = ((spawn.dx - b.left) / b.width).clamp(0.08, 0.92);
    final fy = ((spawn.dy - b.top) / b.height).clamp(0.12, 0.88);
    final d = {
      'W': spawn.dx - b.left,
      'E': b.right - spawn.dx,
      'N': spawn.dy - b.top,
      'S': b.bottom - spawn.dy,
    };
    final m = d.entries.reduce((a, c) => a.value <= c.value ? a : c);
    if (m.value > 160) {
      return Offset(box.left + box.width * fx, box.top + box.height * fy);
    }
    return switch (m.key) {
      'W' => Offset(box.left, box.top + box.height * fy),
      'E' => Offset(box.right, box.top + box.height * fy),
      'N' => Offset(box.left + box.width * fx, box.top),
      _ => Offset(box.left + box.width * fx, box.bottom),
    };
  }

  void _drawCorridors(
    Canvas canvas,
    DungeonChart chart,
    Map<String, Color> hatches,
    Set<String> known,
    List<(Offset, BogFord)> fenMarks,
    List<(Offset, MoundState)> ruinsMarks,
  ) {
    final seen = <String>{};
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final room in game.layout.rooms.values) {
      final boxA = chart.rooms[room.id];
      if (boxA == null) continue;
      for (final door in room.doors) {
        if (door.chromeless) continue; // secret ways draw no corridor
        if (game.isDoorHidden(room, door)) continue; // not found yet
        final to = game.layout.rooms[door.targetRoomId];
        final boxB = chart.rooms[door.targetRoomId];
        if (to == null || boxB == null) continue;
        if (!known.contains(room.id) || !known.contains(to.id)) continue;
        // Hidden from EITHER side is hidden: the gate's crossings are under
        // weed until Water clears them, and the knolls' ends of them must not
        // give the game away.
        if (to.doors.any(
          (d) => d.targetRoomId == room.id && game.isDoorHidden(to, d),
        )) {
          continue;
        }
        final key = room.id.compareTo(to.id) < 0
            ? '${room.id}:${to.id}:${door.rect.center.dy.round()}'
            : '${to.id}:${room.id}:${door.targetSpawn.dy.round()}';
        if (!seen.add(key)) continue;
        // The reciprocal is drawn by this same line; skip it by its own key.
        final back = to.doors.where((d) => d.targetRoomId == room.id);
        for (final d in back) {
          seen.add(
            to.id.compareTo(room.id) < 0
                ? '${to.id}:${room.id}:${d.rect.center.dy.round()}'
                : '${room.id}:${to.id}:${d.targetSpawn.dy.round()}',
          );
        }

        final a = _doorPoint(boxA, room, door.rect);
        final b = _arrivalPoint(boxB, to, door.targetSpawn);
        // A way through the FLOOR, in either direction, is a hatch — Mud's
        // fane climbs back up through wall doors to wallows that go down.
        final hatchHere = chartDoorWall(room.bounds, door.rect) == 'I';
        final hatchBack = back.where(
          (d) => chartDoorWall(to.bounds, d.rect) == 'I',
        );
        final hatch = hatchHere || hatchBack.isNotEmpty;
        final touchesYou =
            room.id == game.currentRoomId || to.id == game.currentRoomId;

        var color = touchesYou ? _kMapCurrent : _kMapVisited;
        var width = 3.0;
        var alpha = touchesYou ? 0.55 : 0.30;
        // PALUSIA'S CORRIDORS ARE THE PUZZLE: every crossing is authored by
        // the player, so the chart shows what each one is right now.
        final fenFord = _chartFordFor(room, door);
        if (fenFord != null) fenMarks.add((Offset.lerp(a, b, 0.5)!, fenFord));
        switch (_isChartPlank(room, door)
            ? _FenEdge.plank
            : _fenEdgeState(room.id, to.id)) {
          case _FenEdge.mire:
            color = const Color(0xFF8A7350);
            width = 2.2;
            alpha = 0.6;
          case _FenEdge.sod:
            color = const Color(0xFF9BB05A);
            width = 4.0;
            alpha = 0.9;
          case _FenEdge.drowned:
            color = const Color(0xFF2E5A66);
            width = 2.0;
            alpha = 0.55;
          case _FenEdge.plank:
            color = const Color(0xFF6E5B3A);
            width = 2.0;
            alpha = 0.7;
          case null:
            break;
        }
        // SABLIS'S STREETS ARE ITS LEDGER: a crossing over a dug-out square is
        // a trench and one under a heap is a dune, and both are shut. The
        // chart says which, so a plan can be made without walking every
        // street to find out (checklist item 6).
        final street = _ruinsStreetState(room.id, to.id);
        if (street != null && street != MoundState.buried) {
          color = street == MoundState.bared
              ? const Color(0xFF8A6A40)
              : const Color(0xFFE2CFA4);
          width = street == MoundState.bared ? 2.0 : 5.0;
          alpha = 0.9;
          ruinsMarks.add((Offset.lerp(a, b, 0.5)!, street));
        }
        paint
          ..strokeWidth = width
          ..color = color.withValues(alpha: alpha);

        final path = Path()..moveTo(a.dx, a.dy);
        final dir = chartDoorDirection(room, door, to);
        final horizontal = dir == 'E' || dir == 'W';
        // Out of the wall a short stub, then straight across, then a stub
        // into the far wall. Elbows bunched every off-axis corridor into one
        // shared vertical run between two columns of rooms; a direct line
        // keeps each corridor its own.
        const stub = 12.0;
        final out = switch (dir) {
          'E' => const Offset(stub, 0),
          'W' => const Offset(-stub, 0),
          'N' => const Offset(0, -stub),
          _ => const Offset(0, stub),
        };
        final aligned =
            (horizontal && (a.dy - b.dy).abs() < 2) ||
            (!horizontal && (a.dx - b.dx).abs() < 2);
        // The stubs only make sense when the far door really is further
        // along the way this one faces; otherwise they fold back into a
        // little arrowhead.
        final ahead = switch (dir) {
          'E' => b.dx - a.dx > stub * 2.5,
          'W' => a.dx - b.dx > stub * 2.5,
          'N' => a.dy - b.dy > stub * 2.5,
          _ => b.dy - a.dy > stub * 2.5,
        };
        if (aligned || hatch || !ahead) {
          path.lineTo(b.dx, b.dy);
        } else {
          final a1 = a + out, b1 = b - out;
          path
            ..lineTo(a1.dx, a1.dy)
            ..lineTo(b1.dx, b1.dy)
            ..lineTo(b.dx, b.dy);
        }
        if (hatch) {
          // A hatch whose room hangs right under this one draws its drop as
          // a short dashed line. One that lands far away (Mud has a wallow
          // on every knoll, all into the one drowned fane) draws a DOWN mark
          // in the room instead — seven dashed threads across the whole
          // chart said nothing but "clutter".
          final near =
              (boxB.top - boxA.bottom).abs() < kChartUnit * 0.9 &&
              boxA.left < boxB.right &&
              boxB.left < boxA.right;
          if (near || chart.handPlaced) {
            _drawDashed(canvas, path, paint);
          }
          final mark = color.withValues(alpha: alpha + 0.3);
          // One mark per room with a way down, in its corner — not one per
          // hatch across its name.
          if (hatchHere) hatches[room.id] = mark;
          if (hatchBack.isNotEmpty) hatches[to.id] = mark;
        } else {
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  /// A way DOWN through the floor: a small ring with a chevron under it.
  void _drawHatch(Canvas canvas, Offset at, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(at, 6, p);
    canvas.drawLine(at + const Offset(-3, -1), at + const Offset(0, 2), p);
    canvas.drawLine(at + const Offset(0, 2), at + const Offset(3, -1), p);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 7, metric.length)),
          paint,
        );
        d += 12;
      }
    }
  }

  /// The peat-cutters' plank road shares its two knolls with a ford; on the
  /// chart it is the SECOND door of the pair, as in the engine.
  bool _isChartPlank(DungeonRoom room, DungeonDoor door) {
    if (game.layout.element != 'Mud') return false;
    if (room.id != kPlankFromKnoll && room.id != kPlankToKnoll) return false;
    final want = room.id == kPlankFromKnoll ? kPlankToKnoll : kPlankFromKnoll;
    final pair = room.doors.where((d) => d.targetRoomId == want).toList();
    return pair.length >= 2 && identical(door, pair.last);
  }

  /// The ford this chart corridor IS, on Palusia (null elsewhere, and for
  /// the plank, the wallows and the drowned level's doors).
  BogFord? _chartFordFor(DungeonRoom room, DungeonDoor door) {
    if (game.layout.element != 'Mud' || _isChartPlank(room, door)) {
      return null;
    }
    for (final f in kBogFords) {
      if (f.touches(room.id) && f.other(room.id) == door.targetRoomId) {
        return f;
      }
    }
    return null;
  }

  /// WHAT THE BASINS ASK FOR, AND WHAT A DRAG WOULD COST — on the chart.
  ///
  /// The Moor Star's whole clue is that the three basin knolls between them
  /// name the four crossings to firm — and that had to be pieced together
  /// from three rooms you never see at once (*"what's the clue to know which
  /// paths to do?"*). Every moor knoll you have visited marks its crossings
  /// here: a filled teal basin on a crossing already firm, a hollow one on a
  /// crossing still to firm, and a red cross where the crossing has drowned
  /// and that basin can never fill in this fen. Visit all three and the four
  /// marked crossings are the road.
  ///
  /// And standing at a crossing you could firm, every crossing that drag
  /// would drown is ringed in red here as well as in the room — the price,
  /// on the map, before it is paid.
  void _drawFenMarks(Canvas canvas, List<(Offset, BogFord)> marks) {
    if (marks.isEmpty) return;
    final field = game.bog.field;
    final altar = game.layout.rooms[kSarsenSocketKnoll]?.fen?.altar;
    final moorWon = altar != null && game.hasStar(altar.moorStarIndex);
    final doomed = game.bogDoomedByHand;
    const teal = CosmicScreenStyles.teal;
    const red = CosmicScreenStyles.danger;
    for (final (at, ford) in marks) {
      if (doomed.contains(ford.id)) {
        canvas.drawCircle(
          at,
          13,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = red.withValues(alpha: 0.9),
        );
      }
      if (moorWon) continue;
      final needed = kMoorKnollIds.any(
        (k) => ford.touches(k) && game.visitedRooms.contains(k),
      );
      if (!needed) continue;
      final state = field.stateOf(ford.id);
      if (state == BogFordState.drowned) {
        final p = Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = red;
        canvas.drawLine(at + const Offset(-6, -6), at + const Offset(6, 6), p);
        canvas.drawLine(at + const Offset(6, -6), at + const Offset(-6, 6), p);
        continue;
      }
      // A little basin: a bowl with water in it.
      canvas.drawCircle(at, 8.5, Paint()..color = CosmicScreenStyles.bg0);
      canvas.drawCircle(
        at,
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = teal,
      );
      if (state == BogFordState.sod) {
        canvas.drawCircle(at, 5, Paint()..color = teal);
      } else {
        canvas.drawLine(
          at + const Offset(-4, 1),
          at + const Offset(4, 1),
          Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = teal.withValues(alpha: 0.8),
        );
      }
    }
  }

  /// What the buried city has made of the street between two rooms, or null
  /// when this is not Sablis or the corridor is not a mound's crossing (the
  /// holes, ramps and drift tunnels only draw when they are open anyway).
  MoundState? _ruinsStreetState(String from, String to) {
    if (game.layout.element != 'Dust') return null;
    for (final m in kDustMounds) {
      if ((m.crossFrom == from && m.crossTo == to) ||
          (m.crossFrom == to && m.crossTo == from)) {
        return game.ruins.stateOf(m.id);
      }
    }
    return null;
  }

  /// A shut street's mark at the middle of its corridor: a dark pit for a
  /// trench, a pale crested heap for a dune — the same two shapes the rooms
  /// draw, at map size.
  void _drawRuinsMarks(Canvas canvas, List<(Offset, MoundState)> marks) {
    for (final (at, state) in marks) {
      if (state == MoundState.bared) {
        final pit = Rect.fromCenter(center: at, width: 24, height: 14);
        canvas.drawOval(pit, Paint()..color = const Color(0xFF0B0806));
        canvas.drawOval(
          pit,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFB08A55),
        );
      } else {
        final heap = Path()
          ..moveTo(at.dx - 14, at.dy + 7)
          ..quadraticBezierTo(at.dx - 4, at.dy - 13, at.dx + 5, at.dy - 9)
          ..quadraticBezierTo(at.dx + 11, at.dy - 3, at.dx + 14, at.dy + 7)
          ..close();
        canvas.drawPath(heap, Paint()..color = const Color(0xFFE2CFA4));
        canvas.drawPath(
          heap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xFF6A5031),
        );
      }
    }
  }

  /// What the fen makes of the crossing between two knolls, or null when
  /// this is not Palusia or not a crossing (the wallows, the plank, the
  /// founder hole and the drowned level's own doors).
  _FenEdge? _fenEdgeState(String from, String to) {
    if (game.layout.element != 'Mud') return null;
    for (final ford in kBogFords) {
      if (!ford.touches(from) || ford.other(from) != to) continue;
      return switch (game.bog.field.stateOf(ford.id)) {
        BogFordState.mire => _FenEdge.mire,
        BogFordState.sod => _FenEdge.sod,
        BogFordState.drowned => _FenEdge.drowned,
      };
    }
    // The peat-cutters' boardwalk joins the same two knolls as `add_tail`,
    // and it is not a crossing: it carries a walker and moors nothing.
    if ((from == kPlankFromKnoll && to == kPlankToKnoll) ||
        (from == kPlankToKnoll && to == kPlankFromKnoll)) {
      return _FenEdge.plank;
    }
    return null;
  }

  void _drawRoom(Canvas canvas, Rect box, DungeonRoom room) {
    final current = room.id == game.currentRoomId;
    final visited = current || game.visitedRooms.contains(room.id);
    final rrect = RRect.fromRectAndRadius(box, const Radius.circular(10));

    if (current) {
      // A soft halo from two widened strokes — no MaskFilter blur.
      for (final (w, a) in [(14.0, 0.07), (7.0, 0.12)]) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = _kMapCurrent.withValues(alpha: a),
        );
      }
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = current
            ? Color.lerp(CosmicScreenStyles.bg2, _kMapCurrent, 0.16)!
            : visited
            ? CosmicScreenStyles.bg2
            : CosmicScreenStyles.bg1,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = current ? 2.6 : 1.6
        ..color =
            (current
                    ? _kMapCurrent
                    : visited
                    ? _kMapVisited
                    : _kMapUnvisited)
                .withValues(
                  alpha: current
                      ? 1.0
                      : visited
                      ? 0.75
                      : 0.6,
                ),
    );

    // Stars held here: filled green when won, outlined gold while open.
    final stars = _roomStars(room).toSet().toList()..sort();
    for (var i = 0; i < stars.length; i++) {
      final won = game.hasStar(stars[i]);
      _drawStar(
        canvas,
        Offset(box.right - 13 - i * 16, box.top + 13),
        6.5,
        won ? _kMapStarDone : _kMapStarOpen,
        filled: won,
      );
    }

    final leaf = room.eclipse?.leaf;
    if (leaf != null) _drawEclipseBadge(canvas, box, leaf);
    final sector = room.hall?.sector;
    if (sector != null) _drawArchiveBadge(canvas, box, sector);

    final label = kDungeonRoomLabels[room.id] ?? room.id.toUpperCase();
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: (current ? _kMapCurrent : CosmicScreenStyles.textPrimary)
              .withValues(
                alpha: current
                    ? 1.0
                    : visited
                    ? 0.85
                    : 0.45,
              ),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: box.width - 14);
    tp.paint(
      canvas,
      box.center - Offset(tp.width / 2, tp.height / 2 - (current ? 0 : 0)),
    );
    if (current) {
      final y = box.center.dy + tp.height / 2 + 8;
      canvas.drawCircle(
        Offset(box.center.dx, y),
        3.2,
        Paint()..color = _kMapCurrent,
      );
    }
  }

  /// NYTHRALOR: a portal a Spirit hand has read (or the party has walked)
  /// stays on the chart between its two rooms, so where a ring comes out is
  /// not something to remember across rooms. Dotted violet; brighter while
  /// both its ends are in shadow and it would carry you now.
  void _drawVaultPortals(Canvas canvas, DungeonChart chart, Set<String> known) {
    final v = game.vault;
    final leaves = vaultLeafOfRoom(game.layout);
    for (final an in kVaultAnchors) {
      if (!v.anchorsRead.contains(an.id) && !v.portalsWalked.contains(an.id)) {
        continue;
      }
      final a = chart.rooms[an.near], b = chart.rooms[an.far];
      if (a == null || b == null) continue;
      if (!known.contains(an.near) || !known.contains(an.far)) continue;
      final live = v.portalOpen(an, leaves);
      final p0 = a.center, p1 = b.center;
      final mid = (p0 + p1) / 2;
      final n = Offset(-(p1 - p0).dy, (p1 - p0).dx) / (p1 - p0).distance;
      final ctrl = mid + n * 28;
      _drawDashed(
        canvas,
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, p1.dx, p1.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = live ? 2.4 : 1.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFA884E0).withValues(alpha: live ? 0.9 : 0.4),
      );
      for (final e in [p0, p1]) {
        canvas.drawCircle(
          e,
          live ? 5 : 4,
          Paint()..color = const Color(0xFF2A1E44),
        );
        canvas.drawCircle(
          e,
          live ? 5 : 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = const Color(0xFFA884E0).withValues(alpha: live ? 1 : 0.5),
        );
      }
    }
  }

  /// NYTHRALOR: whether the room's quarter is in shadow NOW — an eclipsed
  /// disc (dark, with its corona) or a full pale one — so the chart reads as
  /// the vault in its current shape.
  void _drawEclipseBadge(Canvas canvas, Rect box, EclipseLeaf leaf) {
    final dark = game.vault.isDark(leaf);
    final c = Offset(box.left + 13, box.top + 13);
    if (dark) {
      canvas.drawCircle(
        c,
        6.5,
        Paint()..color = const Color(0xFFA884E0).withValues(alpha: 0.55),
      );
      canvas.drawCircle(c, 5.2, Paint()..color = const Color(0xFF120E1C));
    } else {
      canvas.drawCircle(
        c,
        6,
        Paint()..color = const Color(0xFFD9D2BC).withValues(alpha: 0.9),
      );
    }
  }

  /// THE ARCHIVE: how much of this bay's sector the beacons light now — a
  /// full gold disc (rim and inward), a half one (the rim only, a low beam
  /// broken on a stack), or a dark one.
  void _drawArchiveBadge(Canvas canvas, Rect box, HallSector sector) {
    final a = game.archive;
    final rim = a.isLit(HallCell(sector, HallBand.rim));
    final inward = a.isLit(HallCell(sector, HallBand.inward));
    final c = Offset(box.left + 13, box.top + 13);
    const gold = Color(0xFFFFE082);
    canvas.drawCircle(c, 6, Paint()..color = const Color(0xFF1A1D26));
    if (rim) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 6),
        math.pi,
        math.pi,
        true,
        Paint()..color = gold,
      );
    }
    if (inward) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 6),
        0,
        math.pi,
        true,
        Paint()..color = gold,
      );
    }
    canvas.drawCircle(
      c,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = gold.withValues(alpha: 0.6),
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    required bool filled,
  }) {
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
    canvas.drawPath(
      path,
      filled
          ? (Paint()..color = color)
          : (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = color.withValues(alpha: 0.85)),
    );
  }

  @override
  bool shouldRepaint(covariant _DungeonFullMapPainter oldDelegate) => true;
}
