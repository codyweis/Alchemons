// THE MAP HAS TO MAKE SENSE WHILE YOU WALK IT.
//
// Reported from play: *"I walked right into a door and kept walking right and
// it would put me in a loop."* Mud's cairn and lotus knolls both carried
// their crossing to each other on their EAST walls, and each arrived on the
// other's east side — so walking right out of one came out of the other
// walking left, and walking right again went straight back. Plant's pollen
// stair and crypt niche did the same thing on their WEST walls.
//
// Two rules, over every door of every planet:
//
//  1. NO MIRRORED ARRIVALS. Leave through an east wall and you arrive on the
//     WEST side of the next room (and so on for each wall). Arriving on the
//     SAME side you left from is the ping-pong: the next step in the same
//     direction goes straight back through.
//  2. NO COMPASS LOOPS. "B is east of A" whenever A's east door (or B's west
//     door) joins them; the same for south. Following east doors must never
//     bring you back to a room you already passed. Three planets are RINGS
//     by design and are exempted by name — the ring IS the map there, and
//     the minimap draws it as one.
//
// A corner transition (leave south, arrive on the west side) is allowed: it
// is a turn, and walking back the way you came still returns you.

import 'dart:ui';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which wall a door sits on, or 'I' for a floor hatch / interior opening.
String _wall(Rect b, Rect r) {
  const e = 30.0;
  if (r.left <= b.left + e && r.height >= r.width) return 'W';
  if (r.right >= b.right - e && r.height >= r.width) return 'E';
  if (r.top <= b.top + e) return 'N';
  if (r.bottom >= b.bottom - e) return 'S';
  return 'I';
}

/// Which side of a room an arrival lands near, or 'I' for the interior.
String _side(Rect b, Offset p) {
  final d = {
    'W': p.dx - b.left,
    'E': b.right - p.dx,
    'N': p.dy - b.top,
    'S': b.bottom - p.dy,
  };
  final m = d.entries.reduce((a, c) => a.value <= c.value ? a : c);
  return m.value < 140 ? m.key : 'I';
}

/// Rings by design: walking one way round them is supposed to come back.
const _rings = {'Spirit', 'Light', 'Blood'};

/// Doors that exist only to satisfy the reciprocal-door invariant and are
/// never walkable in play (Mud's sunken bowl is entered by riding the knoll
/// down, and left by its own south door).
const _deadPairs = {('Mud', 'drowned_fane', 'sunken_lotus')};

String? _cycle(Map<String, Set<String>> g) {
  final state = <String, int>{};
  final stack = <String>[];
  String? found;
  void dfs(String v) {
    state[v] = 1;
    stack.add(v);
    for (final w in g[v] ?? const <String>{}) {
      if (found != null) return;
      if (state[w] == 1) {
        found = [...stack.sublist(stack.indexOf(w)), w].join(' > ');
        return;
      }
      if (state[w] == null) dfs(w);
    }
    stack.removeLast();
    state[v] = 2;
  }

  for (final v in g.keys) {
    if (found != null) break;
    if (state[v] == null) dfs(v);
  }
  return found;
}

void main() {
  for (final entry in kPlanetDungeonLayouts.entries) {
    final planet = entry.key;
    final layout = entry.value;
    group(planet, () {
      final east = <String, Set<String>>{};
      final south = <String, Set<String>>{};
      final mirrored = <String>[];
      for (final room in layout.rooms.values) {
        for (final d in room.doors) {
          final t = layout.rooms[d.targetRoomId];
          if (t == null) continue;
          if (_deadPairs.contains((planet, room.id, t.id)) ||
              _deadPairs.contains((planet, t.id, room.id))) {
            continue;
          }
          final w = _wall(room.bounds, d.rect);
          if (w != 'I' && _side(t.bounds, d.targetSpawn) == w) {
            mirrored.add('${room.id} leaves $w and arrives on ${t.id}\'s $w');
          }
          switch (w) {
            case 'E':
              east.putIfAbsent(room.id, () => {}).add(t.id);
            case 'W':
              east.putIfAbsent(t.id, () => {}).add(room.id);
            case 'S':
              south.putIfAbsent(room.id, () => {}).add(t.id);
            case 'N':
              south.putIfAbsent(t.id, () => {}).add(room.id);
          }
        }
      }

      test('no door arrives on the same side it left from', () {
        expect(mirrored, isEmpty);
      });

      test('walking one way never comes back round', () {
        expect(_cycle(south), isNull, reason: 'south');
        if (_rings.contains(planet)) return;
        expect(_cycle(east), isNull, reason: 'east');
      });
    });
  }
}
