// Earth's two early stars, which used to be one verb repeated.
//
// STAR 1 was three ribs on three separate tracks that never touched each
// other: six identical shoves. The cage is ARTICULATED now — driving a rib
// levers the one below it the other way — so the star is a mechanism.
//
// STAR 2 was four sockets charged at leisure, with a defend wave as the only
// content. The sockets LEAK now, and a holding socket feeds its neighbours,
// so the star is a route and an order.
//
// The expensive thing to get wrong in both is reachability, and one of them
// already was: coupling a rib to BOTH neighbours makes the laid-true board an
// isolated state and the star unbankable from anywhere. That is what the
// sweep here is for.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String e, String f) => CosmicPartyMember(
  instanceId: '$e$f',
  baseId: 'b',
  displayName: '$e $f',
  imagePath: null,
  element: e,
  family: f,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _barrow(String room) {
  final party = [
    _m('Earth', 'horn'),
    _m('Lightning', 'pip'),
    _m('Crystal', 'mask'),
  ];
  final g = PlanetDungeonGame(
    element: 'Earth',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = room;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

void main() {
  group('Star 1 — the cage is one bone', () {
    test('every board can still be laid true', () {
      // The sweep that would have caught the two-sided coupling instantly:
      // with it, exactly one board of 27 could reach the goal (the goal
      // itself), so the star was unbankable from every opening arrangement.
      final g = _barrow('rib_hall');
      final hall = g.currentRoom;
      for (var a = 0; a < 3; a++) {
        for (var b = 0; b < 3; b++) {
          for (var c = 0; c < 3; c++) {
            expect(
              g.ribCageDistance(hall, [a, b, c]),
              greaterThanOrEqualTo(0),
              reason: 'the cage must be solvable from ($a,$b,$c)',
            );
          }
        }
      }
    });

    test('the rolled opening is a real walk', () {
      for (var run = 0; run < 30; run++) {
        final g = _barrow('rib_hall');
        final hall = g.currentRoom;
        final board = [
          for (final r in hall.fossilRibs) g.ribNotches[r.id] ?? 0,
        ];
        expect(
          g.ribCageDistance(hall, board),
          greaterThanOrEqualTo(4),
          reason: 'never opens nearly solved',
        );
      }
    });

    test('and it is not the same opening every run', () {
      final seen = {
        for (var i = 0; i < 40; i++)
          _barrow('rib_hall')
              .let((g) => [
                    for (final r in g.currentRoom.fossilRibs)
                      g.ribNotches[r.id] ?? 0,
                  ].join()),
      };
      expect(seen.length, greaterThan(1), reason: 'rolled, not authored');
    });

    test('the laid-true board is not a dead end', () {
      // The specific failure. If nothing can move OUT of the goal, nothing
      // can move INTO it either.
      final g = _barrow('rib_hall');
      expect(g.ribCageDistance(g.currentRoom, [2, 2, 2]), 0);
      expect(
        g.ribCageDistance(g.currentRoom, [2, 2, 1]),
        greaterThan(0),
        reason: 'the goal has approaches',
      );
    });
  });

  group('Star 2 — the sockets leak', () {
    test('a sealed socket gutters out on its own', () {
      final g = _barrow('pillar_crypt');
      final p = g.currentRoom.fossilPillars.first;
      g.lockedPillars.add(p.id);
      g.pillarLife[p.id] = 1.0;
      for (var i = 0; i < 120; i++) {
        g.update(1 / 60);
      }
      expect(g.lockedPillars.contains(p.id), isFalse);
      expect(g.pillarLife.containsKey(p.id), isFalse);
    });

    test('a neighbour holding beside it halves the bleed', () {
      // The fact the route is built on: adjacent pairs keep each other alive
      // and opposite corners do not.
      final pillars = _barrow('pillar_crypt').currentRoom.fossilPillars;
      final a = pillars.first;
      final near = pillars.firstWhere(
        (p) => p.id != a.id && (p.position - a.position).distance <= 320,
      );

      double survive({required bool withNeighbour}) {
        final g = _barrow('pillar_crypt');
        g.lockedPillars.add(a.id);
        g.pillarLife[a.id] = 2.0;
        if (withNeighbour) {
          g.lockedPillars.add(near.id);
          g.pillarLife[near.id] = 999;
        }
        var t = 0.0;
        while (g.pillarLife.containsKey(a.id) && t < 12) {
          g.update(1 / 60);
          t += 1 / 60;
        }
        return t;
      }

      final alone = survive(withNeighbour: false);
      final fed = survive(withNeighbour: true);
      expect(fed, greaterThan(alone * 1.6), reason: 'fed sockets last longer');
    });

    test('the star wants all four AT ONCE, not four in total', () {
      final g = _barrow('pillar_crypt');
      final room = g.currentRoom;
      // Seal three, then let the first die before the fourth is sealed.
      for (final p in room.fossilPillars.take(3)) {
        g.lockedPillars.add(p.id);
        g.pillarLife[p.id] = 0.4;
      }
      for (var i = 0; i < 240; i++) {
        g.update(1 / 60);
      }
      expect(
        g.lockedPillars,
        isEmpty,
        reason: 'they all gutter — nothing is banked by having once been lit',
      );
      expect(g.hasStar(room.pillarStarIndex!), isFalse);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
