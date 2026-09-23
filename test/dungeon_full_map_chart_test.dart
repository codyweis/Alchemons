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

import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_chart_layout.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_minimap.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _painterTests();
  const canvas = Size(880, 980);

  group('the chart agrees with the walking', () {
    // THE MAP IS DRAWN FROM THE DOORS (dungeon_chart_layout.dart): a room
    // through an east door is to the east. This is the property the old
    // "rows by distance from the entrance" chart did not have, and the reason
    // it read as weird. Rings (Spirit, Light, Blood) cannot satisfy it all
    // the way round, and floor hatches go DOWN a level, so both are exempt.
    const rings = {'Spirit', 'Light', 'Blood'};
    kPlanetDungeonLayouts.forEach((element, layout) {
      if (rings.contains(element)) return;
      test('$element: every wall door points the way its room is drawn', () {
        final chart = dungeonChartFor(element);
        final wrong = <String>[];
        for (final room in layout.rooms.values) {
          for (final d in room.doors) {
            final to = layout.rooms[d.targetRoomId];
            if (to == null) continue;
            if (chartPairIsHatch(layout, room.id, to.id)) continue;
            // Mud's bowl and fane: a reciprocal pair that exists only for
            // the door invariant and is never walked (door_compass_test).
            if (element == 'Mud' &&
                {
                  room.id,
                  to.id,
                }.containsAll({'drowned_fane', 'sunken_lotus'})) {
              continue;
            }
            final a = chart.rooms[room.id]!.center;
            final b = chart.rooms[to.id]!.center;
            final ok = switch (chartDoorWall(room.bounds, d.rect)) {
              'E' => b.dx > a.dx,
              'W' => b.dx < a.dx,
              'N' => b.dy < a.dy,
              'S' => b.dy > a.dy,
              _ => true,
            };
            if (!ok) wrong.add('${room.id} -> ${to.id}');
          }
        }
        expect(wrong, isEmpty);
      });
    });

    test('no two rooms overlap on any chart', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        final boxes = dungeonChartFor(element).rooms.entries.toList();
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            expect(
              boxes[i].value.overlaps(boxes[j].value),
              isFalse,
              reason: '$element: ${boxes[i].key} / ${boxes[j].key}',
            );
          }
        }
      });
    });
  });

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

// ─────────────────────────────────────────────────────────
// AND THE PAINTER HAS TO ASK THE SAME QUESTION THE TEST DOES.
//
// The invariant above held perfectly while the map drew NOTHING. The chart
// helper has always fallen back to the derived layout; the painter did not
// ask the helper — it iterated the hand-authored atlas directly and built an
// empty position map for every planet without one, so eleven dungeons opened
// their full map on a background with no nodes, no threads and no "you are
// here". A test that exercises a helper proves the helper.
//
// So this one renders the widget and counts ink.

Future<int> _inkOfMap(PlanetDungeonGame game) async {
  const size = Size(880, 980);
  final rec = ui.PictureRecorder();
  debugPaintFullMap(game, Canvas(rec), size);
  final img = await rec.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = raw!.buffer.asUint8List();
  // The chart's background is a dark vertical gradient; anything the painter
  // puts down is brighter than it. Count what stands out from its own row.
  var lit = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] > 70 || bytes[i + 1] > 70 || bytes[i + 2] > 90) lit++;
  }
  return lit;
}

PlanetDungeonGame _mapGame(String element) {
  final els = kCosmicPlanetEntry[element] ?? const ['Mud', 'Mud', 'Mud'];
  final game = PlanetDungeonGame(
    element: element,
    party: [
      for (var i = 0; i < els.length; i++)
        CosmicPartyMember(
          instanceId: 'i$i',
          baseId: 'b$i',
          displayName: els[i],
          element: els[i],
          family: 'mane',
          level: 10,
          statSpeed: 3,
          statIntelligence: 3,
          statStrength: 3,
          statBeauty: 3,
          slotIndex: i,
          staminaBars: 3,
          staminaMax: 3,
        ),
    ],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  return game;
}

void _painterTests() {
  group('the full map actually draws', () {
    testWidgets('every planet puts nodes and threads on the chart', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final element in kPlanetDungeonLayouts.keys) {
          final lit = await _inkOfMap(_mapGame(element));
          expect(
            lit,
            greaterThan(400),
            reason:
                '$element: the full map drew background and nothing else — '
                'this is what an empty position map looks like',
          );
        }
      });
    });

    testWidgets('Palusia draws its crossings by STATE, not as one thread', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final game = _mapGame('Mud');
        final open = await _inkOfMap(game);
        // A dragged road is a heavier, brighter thread; a drowned one all but
        // disappears. The chart has to move when the fen does — it is the
        // only planet whose edges are the puzzle.
        game.bog.field.harden('tarn_head');
        final dragged = await _inkOfMap(game);
        expect(
          dragged,
          isNot(open),
          reason: 'the fen changed and the map did not',
        );
      });
    });
  });
}
