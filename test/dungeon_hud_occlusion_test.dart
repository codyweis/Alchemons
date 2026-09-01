// Nothing you have to touch sits under the HUD.
//
// The minimap is pinned to the screen's top-left. In a room WIDER and TALLER
// than the viewport the camera clamps to the room's own edges, so the room's
// north-west corner lands exactly under it — and anything authored there is
// covered by a panel the player cannot move.
//
// Water's canal gallery is why this exists: the SPRING, the one basin that
// always answers a hand and the reason a lost lantern can never end a run,
// was at (100, 110) in a 1000x720 room. The gallery is padded now. This walks
// every room on every planet so the next one is caught before a playtest.

import 'dart:math';

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone in portrait — the surface the dungeon is actually played on.
const Size _kViewport = Size(412, 915);

/// The minimap's screen box: 10px padding + a 106px box, plus a generous
/// allowance for the status-bar safe area it sits below.
const Rect _kMiniMap = Rect.fromLTWH(0, 0, 126, 190);

/// Where the camera's top-left sits when it is pushed as far north-west as
/// the room allows — the worst case for the HUD. Mirrors `_cameraTopLeft`.
Offset _cameraNorthWest(Rect b) {
  final vw = _kViewport.width, vh = _kViewport.height;
  return Offset(
    b.width <= vw ? b.center.dx - vw / 2 : b.left,
    b.height <= vh ? b.center.dy - vh / 2 : b.top,
  );
}

/// Everything in [room] a player has to walk to and press.
Iterable<(String, Offset)> _touchPoints(DungeonRoom room) sync* {
  for (final v in room.tideValves) {
    yield ('tideValve', v.position);
  }
  for (final n in room.canalNodes) {
    yield ('canalNode:${n.id}', n.position);
  }
  for (final s in room.gustShrines) {
    yield ('gustShrine:${s.id}', s.position);
  }
  for (final v in room.galeVents) {
    yield ('galeVent:${v.id}', v.position);
  }
  for (final a in room.anchors) {
    yield ('anchor:${a.id}', a.position);
  }
  for (final c in room.conduits) {
    yield ('conduit:${c.id}', c.position);
  }
  for (final p in room.windRunes) {
    yield ('windRune', p);
  }
  for (final t in room.muralTorches) {
    yield ('muralTorch', t);
  }
  for (final b in room.braziers) {
    yield ('brazier', b.position);
  }
  final cache = room.vaultCache;
  if (cache != null) yield ('vaultCache', cache);
}

void main() {
  test('no interactive object hides under the minimap', () {
    final covered = <String>[];
    kPlanetDungeonLayouts.forEach((element, layout) {
      for (final room in layout.rooms.values) {
        final cam = _cameraNorthWest(room.bounds);
        for (final (what, world) in _touchPoints(room)) {
          final screen = world - cam;
          // A press target is a disc, not a point — clear the panel by its
          // reach, not by its centre.
          const r = 26.0;
          if (_kMiniMap.overlaps(
            Rect.fromCircle(center: screen, radius: r),
          )) {
            covered.add(
              '$element/${room.id}: $what at $world lands at '
              '(${screen.dx.round()}, ${screen.dy.round()})',
            );
          }
        }
      }
    });
    expect(
      covered,
      isEmpty,
      reason:
          'the minimap is pinned top-left and cannot be moved, so anything '
          'here is unreachable-looking until the player guesses:\n'
          '${covered.join('\n')}',
    );
  });

  test('the padded canal gallery clears it by a real margin', () {
    // The specific regression. Named so a future re-tune of the gallery
    // cannot quietly walk the spring back into the corner.
    final gallery = kPlanetDungeonLayouts['Water']!.rooms['ghost_gallery']!;
    final spring = gallery.canalNodes.firstWhere((n) => n.isSpring);
    final screen = spring.position - _cameraNorthWest(gallery.bounds);
    expect(screen.dx, greaterThan(_kMiniMap.right + 40));
    expect(
      max(0.0, _kMiniMap.bottom - screen.dy),
      0,
      reason: 'and it is below the panel too',
    );
  });
}
