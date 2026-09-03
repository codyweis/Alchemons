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

import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone in portrait — the surface the dungeon is actually played on.
const Size _kViewport = Size(412, 915);

/// The panels bolted to the screen, in screen coordinates. Each is measured
/// from the widget tree in `planet_dungeon_screen.dart` plus a safe-area
/// allowance, and each is pinned to a CORNER — which is what makes this a
/// solvable problem at all. A pannable room can put any point under any panel
/// at some camera position; what the player cannot escape is a panel over a
/// point the camera is CLAMPED against.
const _huds = <(String, Rect, Alignment)>[
  // Minimap: 10 padding + a 106 box, below the status bar.
  ('minimap', Rect.fromLTWH(0, 0, 126, 190), Alignment.topLeft),
  // Joystick: 104 across at bottom 24, left 16, above the gesture bar.
  ('joystick', Rect.fromLTWH(0, 715, 150, 200), Alignment.bottomLeft),
  // Action cluster + swap rail, stacked: the tallest thing on the screen.
  ('action pad', Rect.fromLTWH(202, 685, 210, 230), Alignment.bottomRight),
];

/// Where the camera's top-left sits when it is pushed as far into [corner] as
/// the room allows — the worst case for a panel in that corner. Mirrors
/// `_cameraTopLeft`; a room smaller than the viewport is centred and cannot
/// be pushed at all.
Offset _cameraClampedTo(Rect b, Alignment corner) {
  final vw = _kViewport.width, vh = _kViewport.height;
  final camX = b.width <= vw
      ? b.center.dx - vw / 2
      : (corner.x < 0 ? b.left : b.right - vw);
  final camY = b.height <= vh
      ? b.center.dy - vh / 2
      : (corner.y < 0 ? b.top : b.bottom - vh);
  return Offset(camX, camY);
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
  test('no interactive object hides under a HUD panel', () {
    final covered = <String>[];
    kPlanetDungeonLayouts.forEach((element, layout) {
      for (final room in layout.rooms.values) {
        for (final (name, box, corner) in _huds) {
          final cam = _cameraClampedTo(room.bounds, corner);
          for (final (what, world) in _touchPoints(room)) {
            final screen = world - cam;
            // A press target is a disc, not a point — clear the panel by its
            // reach, not by its centre.
            const r = 26.0;
            if (box.overlaps(Rect.fromCircle(center: screen, radius: r))) {
              covered.add(
                '$element/${room.id}: $what at $world is under the $name '
                '(screen ${screen.dx.round()}, ${screen.dy.round()})',
              );
            }
          }
        }
      }
    });
    expect(
      covered,
      isEmpty,
      reason:
          'these panels are pinned to screen corners and cannot be moved, and '
          'the camera is clamped against the room edge here, so the player '
          'has no way to see past them:\n${covered.join('\n')}',
    );
  });

  test('the padded canal gallery clears both panels by a real margin', () {
    // The two specific regressions, named so a future re-tune of the gallery
    // cannot quietly walk them back into a corner.
    final gallery = kPlanetDungeonLayouts['Water']!.rooms['ghost_gallery']!;

    // The SPRING clears the minimap sideways — it sits below the panel's
    // bottom edge only by a little, so the margin that matters is the x one.
    final spring = gallery.canalNodes.firstWhere((n) => n.isSpring);
    final atSpring =
        spring.position - _cameraClampedTo(gallery.bounds, Alignment.topLeft);
    expect(atSpring.dx - 26, greaterThan(126 + 40));

    // The SEA DRAIN clears the action pad from above. It is horizontally
    // inside the pad's column and always will be — it is the room's
    // south-east corner — so the whole clearance is vertical, and it only
    // exists because the room is deeper than the viewport and can pan.
    expect(
      gallery.bounds.height,
      greaterThan(_kViewport.height),
      reason: 'a room shorter than the screen cannot pan its floor clear',
    );
    final sea = gallery.canalNodes.firstWhere((n) => n.isSea);
    final atSea =
        sea.position - _cameraClampedTo(gallery.bounds, Alignment.bottomRight);
    expect(atSea.dy + 26, lessThan(685 - 20));
  });

  test('a room the camera cannot pan keeps its corners clear itself', () {
    // Poison's crypt is 700 deep against a 915 screen: it never pans
    // vertically, so an object's screen height is FIXED and no amount of
    // walking will pull it out from under the action pad. Its vault cache was
    // at (700, 600) — the pickup was behind the button you press to take it.
    final crypt = kPlanetDungeonLayouts['Poison']!.rooms['lazar_crypt']!;
    expect(crypt.bounds.height, lessThan(_kViewport.height));
    final cache = crypt.vaultCache!;
    final at = cache - _cameraClampedTo(crypt.bounds, Alignment.bottomRight);
    expect(at.dy + 26, lessThan(685));
  });
}
