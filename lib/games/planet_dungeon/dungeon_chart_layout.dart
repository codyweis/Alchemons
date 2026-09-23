// lib/games/planet_dungeon/dungeon_chart_layout.dart
//
// WHERE EACH ROOM GOES ON THE EXPANDED MAP — derived from the doors.
//
// The chart used to be two things at once, neither of them the dungeon: six
// hand-placed atlases of dots, and for the other eleven planets a breadth-
// first "rows by distance from the entrance" fallback. The fallback knew
// which rooms joined but not WHICH WALL they joined on, so a room you reach
// by walking east could be drawn below-left of where you stood, and every
// thread crossed the whole canvas. Played, it read as *"every mini map looks
// kind of weird"*.
//
// A door already says where the next room is: leave through the east wall
// and it is to the east; drop through a floor hatch and it is below. So the
// chart walks the doors from the entrance and puts each room where its door
// says, as a box the shape of the room, lined up so the door you left by and
// the door you arrive at sit on one straight corridor. It is the same compass
// `dungeon_door_compass_test` holds every planet to, so the map and the
// walking can never disagree.
//
// Pure geometry, no Flutter widgets and no game state: the painter asks this
// once per planet and caches it.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';

/// One chart unit in canvas pixels.
const double kChartUnit = 100;

/// Gap between two joined rooms, in units — the length of the corridor.
const double _kGap = 0.5;

/// Clear space kept around every placed room, in units.
const double _kClearance = 0.22;

/// Margin around the whole chart, in units.
const double _kMargin = 0.7;

/// The expanded map for one planet: each room's box and the canvas it sits
/// on, both in canvas pixels.
class DungeonChart {
  final Map<String, Rect> rooms;
  final Size size;

  /// Canvas y of the gap between one level and the next below it (a drowned
  /// fane under the fen, a cellar under the streets), for a faint divider.
  final List<double> levelBreaks;

  /// Placed by hand, with every link kept short on purpose — so even a way
  /// through the floor (Air's updrafts) draws its thread.
  final bool handPlaced;
  const DungeonChart(
    this.rooms,
    this.size, [
    this.levelBreaks = const [],
    this.handPlaced = false,
  ]);
}

/// Which wall of [bounds] a door sits on: 'N' 'E' 'S' 'W', or 'I' for a floor
/// hatch or other interior opening.
String chartDoorWall(Rect bounds, Rect door) {
  const e = 30.0;
  if (door.left <= bounds.left + e && door.height >= door.width) return 'W';
  if (door.right >= bounds.right - e && door.height >= door.width) return 'E';
  if (door.top <= bounds.top + e) return 'N';
  if (door.bottom >= bounds.bottom - e) return 'S';
  return 'I';
}

/// Which side of [bounds] an arrival point is near, or 'I' for the middle.
String _arrivalSide(Rect bounds, Offset p) {
  final d = {
    'W': p.dx - bounds.left,
    'E': bounds.right - p.dx,
    'N': p.dy - bounds.top,
    'S': bounds.bottom - p.dy,
  };
  final m = d.entries.reduce((a, c) => a.value <= c.value ? a : c);
  return m.value < 140 ? m.key : 'I';
}

const _opposite = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'};

/// The direction a door leads, as a compass letter. A wall door leads the way
/// its wall faces; a hatch leads away from the side you land on, and a hatch
/// that lands you in the middle of a room leads DOWN (south), which is what a
/// hole in the floor does.
String chartDoorDirection(DungeonRoom from, DungeonDoor door, DungeonRoom to) {
  final wall = chartDoorWall(from.bounds, door.rect);
  if (wall != 'I') return wall;
  final landed = _arrivalSide(to.bounds, door.targetSpawn);
  return landed == 'I' ? 'S' : _opposite[landed]!;
}

/// Whether two rooms are joined through a FLOOR — a hatch on either side. A
/// fane that climbs back up through its wall to wallows that go down is one
/// hatch, not a wall door and a hatch.
bool chartPairIsHatch(DungeonLayout layout, String a, String b) {
  bool hatchFrom(String x, String y) {
    final r = layout.rooms[x];
    if (r == null) return false;
    return r.doors.any(
      (d) => d.targetRoomId == y && chartDoorWall(r.bounds, d.rect) == 'I',
    );
  }

  return hatchFrom(a, b) || hatchFrom(b, a);
}

/// A room's box size in chart units: its real proportions, clamped so a vast
/// hall does not swallow the chart and a closet can still hold its name.
Size _boxSize(Rect bounds) => Size(
  (bounds.width / 540).clamp(1.0, 1.9),
  (bounds.height / 540).clamp(0.7, 1.5),
);

final Map<String, DungeonChart> _chartCache = {};

/// The chart for [element], cached.
DungeonChart dungeonChartFor(String element) {
  final cached = _chartCache[element];
  if (cached != null) return cached;
  final layout = kPlanetDungeonLayouts[element];
  final chart = layout == null
      ? const DungeonChart({}, Size(400, 400))
      : buildDungeonChart(layout);
  return _chartCache[element] = chart;
}

/// Lay [layout] out from its doors. See the file header.
///
/// LEVELS. Rooms joined by doors in their WALLS are one level, laid out as a
/// floor plan; rooms you can only reach by dropping through a floor (Mud's
/// drowned fane under the fen, a cellar under a street) are another level,
/// laid out on its own and hung underneath. Drawing a wallow as a thread from
/// a knoll across the whole map to a room that is really BELOW it put the
/// fane in the fen's own column with seven lines running to it.
DungeonChart buildDungeonChart(DungeonLayout layout) {
  final hand = _kHandCharts[layout.element];
  if (hand != null) return _handChart(layout, hand);
  final rooms = layout.rooms;
  if (!rooms.containsKey(layout.entranceRoomId)) {
    return const DungeonChart({}, Size(400, 400));
  }
  // Wall-door components.
  final level = <String, int>{};
  final levels = <List<String>>[];
  final roots = <String>[];
  // Visit in the order the player could reach rooms, through any door, so
  // the entrance's level comes first and deeper levels follow.
  final order = <String>[layout.entranceRoomId];
  final seenOrder = {layout.entranceRoomId};
  for (var i = 0; i < order.length; i++) {
    for (final d in rooms[order[i]]!.doors) {
      if (rooms.containsKey(d.targetRoomId) && seenOrder.add(d.targetRoomId)) {
        order.add(d.targetRoomId);
      }
    }
  }
  for (final id in rooms.keys) {
    if (seenOrder.add(id)) order.add(id);
  }
  final wallNeighbours = <String, Set<String>>{};
  for (final room in rooms.values) {
    for (final d in room.doors) {
      if (!rooms.containsKey(d.targetRoomId)) continue;
      if (chartPairIsHatch(layout, room.id, d.targetRoomId)) continue;
      wallNeighbours.putIfAbsent(room.id, () => {}).add(d.targetRoomId);
      wallNeighbours.putIfAbsent(d.targetRoomId, () => {}).add(room.id);
    }
  }
  for (final id in order) {
    if (level.containsKey(id)) continue;
    final members = <String>[id];
    level[id] = levels.length;
    for (var i = 0; i < members.length; i++) {
      for (final n in wallNeighbours[members[i]] ?? const <String>{}) {
        if (level.containsKey(n)) continue;
        level[n] = levels.length;
        members.add(n);
      }
    }
    levels.add(members);
    roots.add(id);
  }

  // Lay each level out, then stack them, each centred under the first.
  final laid = [
    for (var i = 0; i < levels.length; i++)
      _layoutLevel(layout, roots[i], levels[i].toSet()),
  ];
  final widths = [
    for (final l in laid) l.values.map((r) => r.right).reduce(math.max),
  ];
  final heights = [
    for (final l in laid) l.values.map((r) => r.bottom).reduce(math.max),
  ];
  final totalW = widths.reduce(math.max);
  final placed = <String, Rect>{};
  final breaks = <double>[];
  var y = 0.0;
  for (var i = 0; i < laid.length; i++) {
    final dx = (totalW - widths[i]) / 2;
    laid[i].forEach((id, r) => placed[id] = r.shift(Offset(dx, y)));
    y += heights[i];
    if (i < laid.length - 1) {
      // A lone room is a side pocket, not a floor: a thinner gap.
      final gap = levels[i + 1].length == 1 ? _kGap + 0.2 : _kGap + 0.5;
      breaks.add(y + gap / 2);
      y += gap;
    }
  }

  final minX = placed.values.map((r) => r.left).reduce(math.min);
  final minY = placed.values.map((r) => r.top).reduce(math.min);
  final maxX = placed.values.map((r) => r.right).reduce(math.max);
  final maxY = placed.values.map((r) => r.bottom).reduce(math.max);
  return DungeonChart(
    {
      for (final e in placed.entries)
        e.key: Rect.fromLTWH(
          (e.value.left - minX + _kMargin) * kChartUnit,
          (e.value.top - minY + _kMargin) * kChartUnit,
          e.value.width * kChartUnit,
          e.value.height * kChartUnit,
        ),
    },
    Size(
      (maxX - minX + _kMargin * 2) * kChartUnit,
      (maxY - minY + _kMargin * 2) * kChartUnit,
    ),
    [
      // Only the breaks between real floors are drawn.
      for (var i = 0; i < breaks.length; i++)
        if (levels[i + 1].length > 1)
          (breaks[i] - minY + _kMargin) * kChartUnit,
    ],
  );
}

/// One level's floor plan, in chart units with its top-left at the origin.
Map<String, Rect> _layoutLevel(
  DungeonLayout layout,
  String rootId,
  Set<String> members,
) {
  final placed = <String, Rect>{}; // chart units

  bool clear(Rect r, String except) {
    final probe = r.inflate(_kClearance);
    for (final e in placed.entries) {
      if (e.key == except) continue;
      if (probe.overlaps(e.value)) return false;
    }
    return true;
  }

  /// Where [to] goes when reached from placed [from] through [door].
  Rect place(DungeonRoom from, DungeonDoor door, DungeonRoom to) {
    final a = placed[from.id]!;
    final size = _boxSize(to.bounds);
    final dir = chartDoorDirection(from, door, to);
    // How far along its wall the door sits in each room, in units, so the
    // door you leave by and the door you arrive at share one straight line.
    final fb = from.bounds, tb = to.bounds;
    final alongAx = (door.rect.center.dx - fb.center.dx) / fb.width * a.width;
    final alongAy = (door.rect.center.dy - fb.center.dy) / fb.height * a.height;
    final alongBx =
        (door.targetSpawn.dx - tb.center.dx) / tb.width * size.width;
    final alongBy =
        (door.targetSpawn.dy - tb.center.dy) / tb.height * size.height;
    Rect at(double gap) {
      switch (dir) {
        case 'E':
          return Rect.fromLTWH(
            a.right + gap,
            a.center.dy + alongAy - alongBy - size.height / 2,
            size.width,
            size.height,
          );
        case 'W':
          return Rect.fromLTWH(
            a.left - gap - size.width,
            a.center.dy + alongAy - alongBy - size.height / 2,
            size.width,
            size.height,
          );
        case 'N':
          return Rect.fromLTWH(
            a.center.dx + alongAx - alongBx - size.width / 2,
            a.top - gap - size.height,
            size.width,
            size.height,
          );
        default: // 'S'
          return Rect.fromLTWH(
            a.center.dx + alongAx - alongBx - size.width / 2,
            a.bottom + gap,
            size.width,
            size.height,
          );
      }
    }

    // Where it wants to be is taken: fan it out SIDEWAYS first (three doors
    // on one wall become three rooms side by side, not a queue), and only
    // then push it further out along the door's own direction — a longer
    // corridor, never a room on top of a room. Cheapest clear spot wins.
    final horizontal = dir == 'E' || dir == 'W';
    Rect? best;
    var bestCost = double.infinity;
    for (var g = 0; g < 24; g++) {
      for (var k = 0; k <= 12; k++) {
        final side = (k + 1) ~/ 2 * (k.isOdd ? 1 : -1) * 0.3;
        final cost = g * 0.35 + side.abs() * 0.8;
        if (cost >= bestCost) continue;
        final r = at(
          _kGap + g * 0.35,
        ).shift(horizontal ? Offset(0, side) : Offset(side, 0));
        if (clear(r, to.id)) {
          best = r;
          bestCost = cost;
        }
      }
      if (best != null && bestCost <= (g + 1) * 0.35) break;
    }
    return best ?? at(_kGap + 24 * 0.35);
  }

  final root = layout.rooms[rootId]!;
  final s0 = _boxSize(root.bounds);
  placed[root.id] = Rect.fromLTWH(0, 0, s0.width, s0.height);

  // Two sweeps: walk the WALL doors first, so the floor plan comes from the
  // doorways a player sees; only then hang whatever is reached solely by a
  // hatch (drowned levels, vaults under floors) below what it drops from.
  for (final hatches in [false, true]) {
    var grew = true;
    while (grew) {
      grew = false;
      final frontier = [...placed.keys];
      for (final id in frontier) {
        final from = layout.rooms[id];
        if (from == null) continue;
        for (final door in from.doors) {
          final to = layout.rooms[door.targetRoomId];
          if (to == null || placed.containsKey(to.id)) continue;
          if (!members.contains(to.id)) continue;
          final isHatch = chartPairIsHatch(layout, from.id, to.id);
          if (isHatch != hatches) continue;
          placed[to.id] = place(from, door, to);
          grew = true;
        }
      }
      // A hatch sweep places one level at a time, then goes back to walls so
      // a drowned level lays itself out by its own doors.
      if (hatches && grew) {
        var walls = true;
        while (walls) {
          walls = false;
          for (final id in [...placed.keys]) {
            final from = layout.rooms[id]!;
            for (final door in from.doors) {
              final to = layout.rooms[door.targetRoomId];
              if (to == null || placed.containsKey(to.id)) continue;
              if (!members.contains(to.id)) continue;
              if (chartPairIsHatch(layout, from.id, to.id)) continue;
              placed[to.id] = place(from, door, to);
              walls = true;
            }
          }
        }
      }
    }
  }

  _layerIntoColumns(layout, placed, rootId);

  // Anything in this level no door reached still gets a spot, underneath.
  final bottom = placed.values.map((r) => r.bottom).reduce(math.max);
  var x = placed.values.map((r) => r.left).reduce(math.min);
  for (final id in members) {
    if (placed.containsKey(id)) continue;
    final s = _boxSize(layout.rooms[id]!.bounds);
    placed[id] = Rect.fromLTWH(x, bottom + _kGap, s.width, s.height);
    x += s.width + _kGap;
  }
  final minX = placed.values.map((r) => r.left).reduce(math.min);
  final minY = placed.values.map((r) => r.top).reduce(math.min);
  return {
    for (final e in placed.entries) e.key: e.value.shift(Offset(-minX, -minY)),
  };
}

/// COLUMNS, when the dungeon allows them.
///
/// Placing rooms one door at a time commits early: Palusia's reed knoll was
/// set down beside the hag knoll by the gate's door before the hag's own east
/// door — which says the reed is further EAST than the hag — was ever read,
/// and everything after it was drawn around the mistake. So once every room
/// has a rough spot, the east-west order is solved for the whole chart at
/// once: a room's column is the longest run of east doors from the west edge
/// of the map to it, which honours every "east of" at the same time. Rooms
/// joined only up and down share their neighbour's column. Heights come from
/// the doors again (one door you leave by, the one you arrive at, level with
/// each other), and a column that would stack two rooms pushes the lower one
/// down.
///
/// A dungeon whose east doors run in a circle (Spirit, Light, Blood are rings
/// by design) has no such order, and keeps the one-door-at-a-time chart.
void _layerIntoColumns(
  DungeonLayout layout,
  Map<String, Rect> placed,
  String rootId,
) {
  // Horizontal "u is west of v" edges, from wall doors only.
  final east = <String, Set<String>>{};
  for (final room in layout.rooms.values) {
    if (!placed.containsKey(room.id)) continue;
    for (final d in room.doors) {
      if (!placed.containsKey(d.targetRoomId)) continue;
      if (chartPairIsHatch(layout, room.id, d.targetRoomId)) continue;
      switch (chartDoorWall(room.bounds, d.rect)) {
        case 'E':
          east.putIfAbsent(room.id, () => {}).add(d.targetRoomId);
        case 'W':
          east.putIfAbsent(d.targetRoomId, () => {}).add(room.id);
      }
    }
  }
  // A ring has no west-to-east order.
  final state = <String, int>{};
  bool cyclic = false;
  void dfs(String v) {
    state[v] = 1;
    for (final w in east[v] ?? const <String>{}) {
      if (state[w] == 1) cyclic = true;
      if (state[w] == null) dfs(w);
      if (cyclic) return;
    }
    state[v] = 2;
  }

  for (final v in east.keys) {
    if (state[v] == null) dfs(v);
    if (cyclic) return;
  }

  // Longest path from the west edge.
  final inEast = <String>{...east.keys, for (final s in east.values) ...s};
  final rank = <String, int>{for (final id in inEast) id: 0};
  for (var i = 0; i < inEast.length; i++) {
    var moved = false;
    east.forEach((u, vs) {
      for (final v in vs) {
        if (rank[v]! < rank[u]! + 1) {
          rank[v] = rank[u]! + 1;
          moved = true;
        }
      }
    });
    if (!moved) break;
  }
  // Rooms with no east-west door share the column of the nearest room that
  // has one, by where the rough chart put them.
  for (final id in placed.keys) {
    if (rank.containsKey(id)) continue;
    final c = placed[id]!.center.dx;
    String? near;
    var best = double.infinity;
    for (final o in inEast) {
      final d = (placed[o]!.center.dx - c).abs();
      if (d < best) {
        best = d;
        near = o;
      }
    }
    rank[id] = near == null ? 0 : rank[near]!;
  }

  // Column x.
  final maxRank = rank.values.fold(0, math.max);
  final colW = List<double>.filled(maxRank + 1, 0);
  for (final e in placed.entries) {
    colW[rank[e.key]!] = math.max(colW[rank[e.key]!], e.value.width);
  }
  final colX = List<double>.filled(maxRank + 1, 0);
  for (var r = 1; r <= maxRank; r++) {
    colX[r] = colX[r - 1] + colW[r - 1] + _kGap + 0.25;
  }

  // Heights from the doors, breadth-first from the entrance: walls first,
  // hatches after, exactly as the rough chart did.
  final cy = <String, double>{rootId: 0};
  for (final hatches in [false, true]) {
    var grew = true;
    while (grew) {
      grew = false;
      for (final id in [...cy.keys]) {
        final from = layout.rooms[id]!;
        final a = placed[id]!;
        for (final door in from.doors) {
          final to = layout.rooms[door.targetRoomId];
          if (to == null || cy.containsKey(to.id)) continue;
          if (!placed.containsKey(to.id)) continue;
          if (chartPairIsHatch(layout, from.id, to.id) != hatches) continue;
          final b = placed[to.id]!;
          final dir = chartDoorDirection(from, door, to);
          final alongA =
              (door.rect.center.dy - from.bounds.center.dy) /
              from.bounds.height *
              a.height;
          final alongB =
              (door.targetSpawn.dy - to.bounds.center.dy) /
              to.bounds.height *
              b.height;
          cy[to.id] = switch (dir) {
            'E' || 'W' => cy[id]! + alongA - alongB,
            'N' => cy[id]! - a.height / 2 - _kGap - b.height / 2,
            _ => cy[id]! + a.height / 2 + _kGap + b.height / 2,
          };
          grew = true;
        }
      }
    }
  }

  // Heights came from whichever door reached a room FIRST. A later door on
  // a north or south wall must still hold: relax every up/down door until
  // the room below is below. (South doors never loop — the compass test.)
  final down = <(String, String)>[];
  for (final room in layout.rooms.values) {
    if (!placed.containsKey(room.id)) continue;
    for (final d in room.doors) {
      if (!placed.containsKey(d.targetRoomId)) continue;
      if (chartPairIsHatch(layout, room.id, d.targetRoomId)) continue;
      switch (chartDoorWall(room.bounds, d.rect)) {
        case 'S':
          down.add((room.id, d.targetRoomId));
        case 'N':
          down.add((d.targetRoomId, room.id));
      }
    }
  }
  for (var i = 0; i < placed.length + 2; i++) {
    var moved = false;
    for (final (u, v) in down) {
      if (!cy.containsKey(u) || !cy.containsKey(v)) continue;
      final need =
          cy[u]! + placed[u]!.height / 2 + _kGap + placed[v]!.height / 2;
      if (cy[v]! < need - 1e-6) {
        cy[v] = need;
        moved = true;
      }
    }
    if (!moved) break;
  }

  // Seat everyone in their column, then un-stack each column top to bottom.
  final next = <String, Rect>{};
  for (final e in placed.entries) {
    final r = rank[e.key]!;
    final w = e.value.width, h = e.value.height;
    final y = cy[e.key] ?? e.value.center.dy;
    next[e.key] = Rect.fromLTWH(colX[r] + (colW[r] - w) / 2, y - h / 2, w, h);
  }
  for (var r = 0; r <= maxRank; r++) {
    final col = next.entries.where((e) => rank[e.key] == r).toList()
      ..sort((x, y) => x.value.top.compareTo(y.value.top));
    for (var i = 1; i < col.length; i++) {
      final prev = next[col[i - 1].key]!;
      final cur = next[col[i].key]!;
      final minTop = prev.bottom + _kClearance * 2;
      if (cur.top < minTop) {
        next[col[i].key] = cur.shift(Offset(0, minTop - cur.top));
      }
    }
  }
  placed
    ..clear()
    ..addAll(next);
}

// ─────────────────────────────────────────────────────────
// HAND-PLACED CHARTS
// ─────────────────────────────────────────────────────────
//
// The derived chart is right for most planets. Four are knotted enough that
// it is merely legal — every door points the right way, but corridors run
// long and cross: Plant's crypt (one geometry at two sizes, and nearly every
// room touches nearly every other), Steam's ring round the crucible, Poison's
// row of wards over a cloister, and Air's climbing spire. Those are placed by
// hand on a grid, cell by cell, from their door walls. They are held to the
// same rule as the derived ones (test/dungeon_full_map_chart_test.dart: a
// room through an east door is drawn to the east), so a hand chart cannot
// drift from the dungeon either.

/// One hand chart: each room's CENTRE in grid cells, plus the rows under
/// which a new level starts (a basement, a crypt), for the divider.
class _HandChart {
  final Map<String, Offset> cells;
  final List<double> levelRows;
  const _HandChart(this.cells, [this.levelRows = const []]);
}

/// Grid cell size, in chart units.
const double _kCellW = 2.3;
const double _kCellH = 1.75;

const Map<String, _HandChart> _kHandCharts = {
  // Two sizes, one crypt. The niche and lantern court on top, the porch and
  // fern gallery under them, the pollen stair below those and the moss walk
  // under the stair (its north door climbs to it); the islet road then runs
  // east and down to the heart.
  'Plant': _HandChart({
    'crypt_niche': Offset(1, 0),
    'lantern_court': Offset(2.1, 0),
    'root_porch': Offset(0, 1.35),
    'fern_gallery': Offset(2.1, 1.1),
    'pollen_stair': Offset(1, 2.1),
    'mosswalk': Offset(1, 3.15),
    'islet': Offset(2.6, 4.2),
    'gourd_hollow': Offset(3.6, 4.2),
    'bloom_hall': Offset(3.4, 5.25),
    'botanica_heart': Offset(3.4, 6.35),
  }),
  // A ring round the crucible: the north and south manifolds are the rim,
  // the causeway and the forge its two arcs, the heart under the rite.
  'Steam': _HandChart({
    'manifold_north': Offset(2, 0),
    'scald_cellar': Offset(3.9, 0),
    'ember_causeway': Offset(1, 1.35),
    'crucible': Offset(2, 1.35),
    'cinder_forge': Offset(3, 1.35),
    'boiler_heart': Offset(2, 2.6),
    'boiler_gate': Offset(0, 3.5),
    'manifold_south': Offset(1.9, 3.5),
    'burst_vault': Offset(1.9, 4.5),
  }),
  // Four wards in a row over the cloister walk; the apothecary off its
  // south side; the crypt is a level down, under the wards.
  'Poison': _HandChart(
    {
      'ward_bell': Offset(0.6, 0),
      'ward_scriptorium': Offset(1.5, 0),
      'ward_refectory': Offset(2.4, 0),
      'ward_charnel': Offset(3.3, 0),
      'lazar_gate': Offset(0, 1.2),
      'ambulatory': Offset(1.95, 1.2),
      'apothecary': Offset(1.95, 2.3),
      'lazar_crypt': Offset(1.95, 3.6),
    },
    [2.95],
  ),
  // The spire climbs up the right: lower spire, crosswind, platforms,
  // summit. The loom sits south of the hub and east of the summit's drop,
  // and the storm wing runs on east from it to the guardian.
  'Air': _HandChart({
    'spiral_cloud': Offset(0.95, 0),
    'ring_cloud': Offset(1.9, 0),
    'spire_summit': Offset(2.85, -0.25),
    'cloud_platforms': Offset(4.05, 0.2),
    'entry': Offset(0, 1.2),
    'hub': Offset(1.45, 1.2),
    'lower_spire': Offset(2.85, 1.45),
    'crosswind_hall': Offset(4.05, 1.4),
    'feather_cloud': Offset(1.45, 2.45),
    'sky_loom': Offset(2.95, 3.0),
    'anvil_cloud': Offset(2.45, 4.1),
    'veil_cloud': Offset(3.45, 4.1),
    'relic_chamber': Offset(4.15, 2.6),
    'storm_rune_hall': Offset(4.2, 3.45),
    'twin_conduit': Offset(5.3, 3.45),
    'storm_altar': Offset(6.4, 3.45),
    'guardian_summit': Offset(6.4, 2.25),
  }),
};

DungeonChart _handChart(DungeonLayout layout, _HandChart hand) {
  final placed = <String, Rect>{};
  for (final room in layout.rooms.values) {
    final c = hand.cells[room.id];
    if (c == null) continue;
    final s = _boxSize(room.bounds);
    placed[room.id] = Rect.fromCenter(
      center: Offset(c.dx * _kCellW, c.dy * _kCellH),
      width: s.width,
      height: s.height,
    );
  }
  // A room added to the layout later and never charted still gets a spot.
  var x = 0.0;
  final bottom = placed.values.map((r) => r.bottom).fold(0.0, math.max);
  for (final room in layout.rooms.values) {
    if (placed.containsKey(room.id)) continue;
    final s = _boxSize(room.bounds);
    placed[room.id] = Rect.fromLTWH(x, bottom + _kGap, s.width, s.height);
    x += s.width + _kGap;
  }
  final minX = placed.values.map((r) => r.left).reduce(math.min);
  final minY = placed.values.map((r) => r.top).reduce(math.min);
  final maxX = placed.values.map((r) => r.right).reduce(math.max);
  final maxY = placed.values.map((r) => r.bottom).reduce(math.max);
  return DungeonChart(
    {
      for (final e in placed.entries)
        e.key: Rect.fromLTWH(
          (e.value.left - minX + _kMargin) * kChartUnit,
          (e.value.top - minY + _kMargin) * kChartUnit,
          e.value.width * kChartUnit,
          e.value.height * kChartUnit,
        ),
    },
    Size(
      (maxX - minX + _kMargin * 2) * kChartUnit,
      (maxY - minY + _kMargin * 2) * kChartUnit,
    ),
    [
      for (final r in hand.levelRows)
        (r * _kCellH - minY + _kMargin) * kChartUnit,
    ],
    true,
  );
}
