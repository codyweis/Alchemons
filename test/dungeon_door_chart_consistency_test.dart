// EVERY DOOR POINTS AT ITS ROOM ON THE MAP.
//
// `dungeon_door_compass_test` forbids the ping-pong and loops made of one
// direction (east, east, east… back to the start). It cannot see a loop made
// of MIXED directions: Plant's crypt had a way north from the moss walk to the
// pollen stair, north again to the fern gallery, and west from there back to
// the moss walk — three steps no real building can take (2026-09-27 review).
//
// So this holds every wall door to ONE set of room positions, the expanded
// map's own: leave through a north wall and the room you arrive in must be
// drawn above the one you left. A map that contradicts itself anywhere fails
// here, whichever directions the contradiction is made of.

import 'package:alchemons/games/planet_dungeon/dungeon_chart_layout.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rings by design (the compass test's own list): a ring cannot be drawn
/// with every east door pointing east, and the minimap draws it as a ring.
const _rings = {'Spirit', 'Light', 'Blood'};

/// Planets whose doors have been audited against their chart, held to the
/// tighter rule. Air, Fire, Dust and Dark each draw one or two rooms mostly
/// diagonal to the door that reaches them (2026-09-27) — add them here once
/// their charts are straightened.
const _audited = {'Plant'};

/// Known and not yet fixed, each with its reason. Remove a line when fixed.
const _known = {
  // The sunken lotus's south wall climbs back UP to the drowned fane, which
  // the chart draws above it (found 2026-09-27; Mud is polished, so it is
  // flagged rather than rewired in the Plant pass).
  'Mud': {'sunken_lotus S -> drowned_fane'},
};

void main() {
  for (final entry in kPlanetDungeonLayouts.entries) {
    if (_rings.contains(entry.key)) continue;
    test('${entry.key}: every wall door leads the way its wall faces', () {
      final layout = entry.value;
      final chart = dungeonChartFor(entry.key);
      final wrong = <String>{};
      for (final room in layout.rooms.values) {
        final from = chart.rooms[room.id];
        if (from == null) continue;
        for (final d in room.doors) {
          final wall = chartDoorWall(room.bounds, d.rect);
          if (wall == 'I') continue;
          if (chartPairIsHatch(layout, room.id, d.targetRoomId)) continue;
          final to = chart.rooms[d.targetRoomId];
          if (to == null) continue;
          final v = to.center - from.center;
          // Every planet: the room is on the side the wall faces. Audited
          // planets: and within ~63° of it — a room reached through an east
          // door may sit a little up or down the chart, never mostly above.
          final strict = _audited.contains(entry.key);
          final ok = switch (wall) {
            'E' => v.dx > 0 && (!strict || v.dx * 2 > v.dy.abs()),
            'W' => v.dx < 0 && (!strict || -v.dx * 2 > v.dy.abs()),
            'N' => v.dy < 0 && (!strict || -v.dy * 2 > v.dx.abs()),
            _ => v.dy > 0 && (!strict || v.dy * 2 > v.dx.abs()),
          };
          if (!ok) wrong.add('${room.id} $wall -> ${d.targetRoomId}');
        }
      }
      wrong.removeAll(_known[entry.key] ?? const <String>{});
      expect(wrong, isEmpty);
    });
  }
}
