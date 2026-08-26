// A walker can get everywhere a run needs to go.
//
// Gliding is Wing-only, and in an open-sky room a walking creature may stand
// ONLY on a platform — everything between them is void. So a room whose
// platforms do not touch is a room that quietly requires a Wing, and nothing
// about it is declared: no gate, no chip on the descent panel, no line in the
// entrance verse. The player finds out by falling.
//
// Air is the planet this exists for. It is a SPIRE built out of floating
// ledges, its ideal trio opens with an Airwing, and it declares exactly one
// gate — a Lightning Horn. Its platforms turn out to overlap into a connected
// chain on purpose (the tall narrow ones are connector ramps) and its woken
// gales lift walkers by design, so it needs no Wing at all. That is easy to
// break by nudging one rect, and impossible to notice without this.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Footing tolerance — matches `_onSolidGround`, which inflates a platform by
/// 2 before testing a point, so two platforms within 4px are one surface.
const double _kStep = 4.0;

void main() {
  group('no room silently requires flight', () {
    test('every open-sky room is walkable end to end', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final room in layout.rooms.values) {
          final plats = room.platforms;
          if (plats.length < 2) continue;

          // Union-find over "close enough to step between".
          final parent = List<int>.generate(plats.length, (i) => i);
          int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
          for (var i = 0; i < plats.length; i++) {
            for (var j = i + 1; j < plats.length; j++) {
              if (plats[i].inflate(_kStep).overlaps(plats[j])) {
                parent[find(i)] = find(j);
              }
            }
          }
          final islands = {for (var i = 0; i < plats.length; i++) find(i)};

          // More than one island is fine IF the room carries some crossing a
          // walker can use. Two exist, and both are element-driven rather
          // than family-locked, which is the whole point:
          //
          //   an UPDRAFT is a ladder anyone can climb (Air's woken gales are
          //   authored as exactly this — "a ladder, not a flier perk");
          //   a RISER throws whoever stands on it across a void (Steam's
          //   cinder forge splits on purpose and has no bridge at all).
          final hasUpdraft = room.currents.any((c) {
            final len = c.dir.distance;
            return len > 0 && c.dir.dy / len <= -0.5;
          });
          final hasRiser = room.geysers.any((m) => m.isRiser);

          expect(
            islands.length == 1 || hasUpdraft || hasRiser,
            isTrue,
            reason:
                '$element/${room.id}: ${plats.length} platforms fall into '
                '${islands.length} unreachable groups, and the room offers no '
                'updraft and no riser to carry a walker between them — so it '
                'needs a Wing, and nothing declares one',
          );
        }
      });
    });

    test('a planet needing flight declares a Wing gate', () {
      // The backstop for the case above: if a layout ever does depend on
      // flight, it has to say so where the player can read it.
      kPlanetDungeonLayouts.forEach((element, layout) {
        final needsAir = layout.rooms.values.any((r) => r.gaps.isNotEmpty);
        if (!needsAir) return;
        expect(
          layout.familyGates.any((g) => g.family == 'Wing'),
          isTrue,
          reason:
              '$element has a room with a GAP in it — only a glide crosses '
              'that — but declares no Wing gate',
        );
      });
    });
  });

  group('Air, specifically', () {
    final air = kPlanetDungeonLayouts['Air']!;

    test('declares no Wing, and needs none', () {
      expect(
        air.familyGates.map((g) => g.family),
        isNot(contains('Wing')),
        reason: 'Air asks for a Lightning Horn and nothing else',
      );
      expect(
        air.riddle.join(' ').toLowerCase(),
        isNot(contains('wing')),
        reason: 'and its verse must not ask for one either',
      );
    });

    test('every spire room is crossable without a Wing', () {
      // Not "on foot end to end" — lower_spire's top ledge is DELIBERATELY
      // off on its own, and reaching it by waking a gale is Star 1's entire
      // mechanic. What must hold is that the separated ledges are served by
      // an updraft rather than by a glide.
      for (final room in air.rooms.values) {
        if (room.platforms.length < 2) continue;
        final plats = room.platforms;
        final parent = List<int>.generate(plats.length, (i) => i);
        int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
        for (var i = 0; i < plats.length; i++) {
          for (var j = i + 1; j < plats.length; j++) {
            if (plats[i].inflate(_kStep).overlaps(plats[j])) {
              parent[find(i)] = find(j);
            }
          }
        }
        final islands = {for (var i = 0; i < plats.length; i++) find(i)}.length;
        if (islands == 1) continue;
        expect(
          room.currents.any((c) {
            final len = c.dir.distance;
            return len > 0 && c.dir.dy / len <= -0.5;
          }),
          isTrue,
          reason:
              'Air/${room.id}: its ledges fall into $islands groups with no '
              'updraft to climb between them, so the spire now needs a flier '
              'it never asked for',
        );
      }
    });
  });
}
