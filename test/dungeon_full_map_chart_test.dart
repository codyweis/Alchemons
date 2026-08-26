// The expanded dungeon map has to be a map.
//
// The full map places each room by looking its id up in a hand-authored atlas
// and falling back to Offset(0.5, 0.5) when it is missing. That fallback is
// per-room, so a planet with no atlas did not get a rough chart — it got every
// single room drawn on the same point in the middle of the canvas. Eleven
// dungeons shipped that way and no test noticed, because nothing asserted that
// two different rooms end up in two different places.
//
// That is the invariant here, and it is deliberately about the OUTPUT of the
// placement rather than about atlases existing: an auto-derived chart, a
// hand-authored one, or some future third scheme all satisfy it, and all of
// them are fine. Collapsing to one point is not.

import 'package:alchemons/games/planet_dungeon/dungeon_minimap.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canvas = Size(880, 980);

  group('every dungeon charts as a real map', () {
    test('no two rooms land on the same point', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        final placed = <Offset, String>{};
        for (final id in layout.rooms.keys) {
          final p = debugFullMapNodePoint(element, id, canvas);
          final clash = placed[p];
          expect(
            clash,
            isNull,
            reason:
                '$element: rooms "$id" and "$clash" are both drawn at $p '
                '— the chart has collapsed and the map is unreadable',
          );
          placed[p] = id;
        }
      });
    });

    test('rooms are spread over the canvas, not huddled in one corner', () {
      // A chart that technically separates its rooms but packs them into a
      // few pixels is just as unusable as one that stacks them.
      kPlanetDungeonLayouts.forEach((element, layout) {
        if (layout.rooms.length < 3) return;
        final pts = [
          for (final id in layout.rooms.keys)
            debugFullMapNodePoint(element, id, canvas),
        ];
        final xs = pts.map((p) => p.dx);
        final ys = pts.map((p) => p.dy);
        final spanX =
            xs.reduce((a, b) => a > b ? a : b) -
            xs.reduce((a, b) => a < b ? a : b);
        final spanY =
            ys.reduce((a, b) => a > b ? a : b) -
            ys.reduce((a, b) => a < b ? a : b);
        // Any sane chart of 3+ rooms uses a decent fraction of both axes.
        expect(
          spanX + spanY,
          greaterThan(canvas.width * 0.35),
          reason:
              '$element: chart spans only ${spanX.toInt()}x'
              '${spanY.toInt()} on an ${canvas.width.toInt()}x'
              '${canvas.height.toInt()} canvas',
        );
      });
    });

    test('every point sits inside the canvas', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final id in layout.rooms.keys) {
          final p = debugFullMapNodePoint(element, id, canvas);
          expect(
            p.dx,
            inInclusiveRange(0, canvas.width),
            reason: '$element/$id',
          );
          expect(
            p.dy,
            inInclusiveRange(0, canvas.height),
            reason: '$element/$id',
          );
        }
      });
    });

    test('placement is stable across calls', () {
      // The derived chart is cached; a cache that rebuilt differently would
      // make the map jitter as the player walks.
      kPlanetDungeonLayouts.forEach((element, layout) {
        for (final id in layout.rooms.keys) {
          expect(
            debugFullMapNodePoint(element, id, canvas),
            debugFullMapNodePoint(element, id, canvas),
            reason: '$element/$id moved between calls',
          );
        }
      });
    });
  });
}
