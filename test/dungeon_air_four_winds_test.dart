// Air's lost maxim is a puzzle you can actually reach and actually solve.
//
// The version this replaces was one press on the exact centre of the hub,
// gated on all three stars — and the hub declared no furniture, so the action
// pad never appeared in that room and the secret could not be reached AT ALL.
// Two of the tests here exist purely so that cannot come back: the hub must
// offer an action, and the maxim must not be gated on finishing the dungeon.
//
// The rest pin the puzzle: rolled per run so it is deduced rather than
// memorised, deducible from the wear alone, unforgiving of a wrong wind, and
// paid out exactly once.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: null,
  element: element,
  family: family,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _spire() {
  final els = kCosmicPlanetEntry['Air']!;
  final fams = kDungeonIdealFamilies['Air']!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = 'hub';
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

DungeonCreature _of(PlanetDungeonGame g, String element) =>
    g.creatures.firstWhere((c) => c.member.element == element);

DungeonCreature _air(PlanetDungeonGame g) => _of(g, 'Air');

/// Walk [c] to pillar [i] and press.
void _press(PlanetDungeonGame g, DungeonCreature c, int i) {
  g.activeIndex = g.creatures.indexOf(c);
  c.position = g.currentRoom.windRunes[i];
  g.activateAbility();
}

/// Let the payout reaction run to its flash.
void _settle(PlanetDungeonGame g) {
  for (var i = 0; i < 240; i++) {
    g.update(1 / 60);
  }
}

/// Put the current in: Lightning at the compass heart wakes the ring.
void _wake(PlanetDungeonGame g) {
  final c = _of(g, 'Lightning');
  g.activeIndex = g.creatures.indexOf(c);
  c.position = g.currentRoom.bounds.center;
  g.activateAbility();
}

/// Burn the rime off all four faces with Fire, so the wear can be read.
void _clean(PlanetDungeonGame g) {
  for (var i = 0; i < g.currentRoom.windRunes.length; i++) {
    _press(g, _of(g, 'Fire'), i);
  }
}

/// The whole reading pass: current in, faces cleaned.
void _open(PlanetDungeonGame g) {
  _wake(g);
  _clean(g);
}

void main() {
  group('the hub is a room you can act in', () {
    test('it declares its pillars', () {
      final hub = kPlanetDungeonLayouts['Air']!.rooms['hub']!;
      expect(
        hub.windRunes,
        hasLength(4),
        reason: 'four winds, and they have to be in the DATA — a hub with no '
            'furniture shows no action pad, which is what made the old '
            'maxim unreachable',
      );
    });

    test('so the action pad appears there', () {
      final g = _spire();
      expect(
        g.roomOffersAction,
        isTrue,
        reason: 'no button in the hub means no way to work the pillars',
      );
      expect(g.utilityAvailable, isTrue);
    });

    test('every pillar sits on the compass ring, inside the room', () {
      final hub = kPlanetDungeonLayouts['Air']!.rooms['hub']!;
      final c = hub.bounds.center;
      for (final p in hub.windRunes) {
        expect(hub.bounds.deflate(40).contains(p), isTrue, reason: '$p');
        expect((p - c).distance, closeTo(235, 3));
      }
    });
  });

  group('the wear says the order', () {
    test('it is rolled, and it is a permutation', () {
      final g = _spire();
      expect(g.firstWindOrder..sort(), [0, 1, 2, 3]);
    });

    test('the order can be read off the wear alone — oldest first', () {
      // The whole puzzle. If wear does not descend along the order, the stone
      // is lying and the answer can only be brute-forced.
      for (var run = 0; run < 40; run++) {
        final g = _spire();
        final wear = [
          for (final i in g.firstWindOrder) g.firstWindWear[i],
        ];
        for (var i = 1; i < wear.length; i++) {
          expect(
            wear[i],
            lessThan(wear[i - 1]),
            reason: 'run $run: wear must fall along the order',
          );
        }
      }
    });

    test('the steps are wide enough to see', () {
      // A puzzle about noticing, not measuring.
      for (var run = 0; run < 40; run++) {
        final g = _spire();
        final wear = [
          for (final i in g.firstWindOrder) g.firstWindWear[i],
        ];
        for (var i = 1; i < wear.length; i++) {
          expect(wear[i - 1] - wear[i], greaterThan(0.12));
        }
      }
    });

    test('it is not the same order every run', () {
      final seen = {
        for (var i = 0; i < 40; i++) _spire().firstWindOrder.join(),
      };
      expect(seen.length, greaterThan(3), reason: 'rolled, not authored');
    });
  });

  group('working the pillars', () {
    test('cold stone answers anyone, and points at the heart', () {
      // Stage 0 must never be silent — but it must never advance either.
      final g = _spire();
      for (final c in g.creatures) {
        _press(g, c, 0);
        expect(g.firstWindStage, 0);
        expect(g.firstWindScoured, isEmpty);
      }
    });

    test('only LIGHTNING wakes the ring, and only at the heart', () {
      final g = _spire();
      // Lightning at a PILLAR does nothing — the current goes in at the heart.
      _press(g, _of(g, 'Lightning'), 0);
      expect(g.firstWindStage, 0);
      // Air and Fire at the heart do nothing either.
      for (final e in ['Air', 'Fire']) {
        final c = _of(g, e);
        g.activeIndex = g.creatures.indexOf(c);
        c.position = g.currentRoom.bounds.center;
        g.activateAbility();
        expect(g.firstWindStage, 0, reason: '$e is not the current');
      }
      _wake(g);
      expect(g.firstWindStage, 1);
    });

    test('only FIRE cleans a woken face', () {
      final g = _spire();
      _wake(g);
      for (final e in ['Air', 'Lightning']) {
        _press(g, _of(g, e), 0);
        expect(g.firstWindScoured, isEmpty, reason: '$e does not clean stone');
      }
      _press(g, _of(g, 'Fire'), 0);
      expect(g.firstWindScoured, {0});
    });

    test('four cleaned faces make the wear readable', () {
      final g = _spire();
      expect(g.firstWindStage, 0);
      _open(g);
      expect(g.firstWindStage, 2);
    });

    test('every element in the party has a job', () {
      // The payout is a reaction built from all three, so the SOLVE has to be
      // too — a first pass ran the whole chain on Air alone and the puzzle
      // did not keep the promise its own payout made.
      final g = _spire();
      _open(g);
      for (final i in g.firstWindOrder) {
        _press(g, _air(g), i);
      }
      _settle(g);
      expect(g.discoveredClouds, contains(kAirFirstWindEggId));
      // And none of the three could have been left at home.
      for (final skip in ['Lightning', 'Fire', 'Air']) {
        final h = _spire();
        if (skip != 'Lightning') _wake(h);
        if (skip != 'Fire') _clean(h);
        if (skip != 'Air' && h.firstWindStage >= 2) {
          for (final i in h.firstWindOrder) {
            _press(h, _air(h), i);
          }
        }
        _settle(h);
        expect(
          h.discoveredClouds,
          isNot(contains(kAirFirstWindEggId)),
          reason: 'without $skip the winds stay asleep',
        );
      }
    });

    test('spoken in order, it pays out once', () {
      final g = _spire();
      _open(g);
      for (final i in g.firstWindOrder) {
        _press(g, _air(g), i);
      }
      _settle(g);
      expect(g.discoveredClouds, contains(kAirFirstWindEggId));
    });

    test('a wrong wind scatters them and the walk starts again', () {
      final g = _spire();
      _open(g);
      final order = [...g.firstWindOrder];
      _press(g, _air(g), order[0]);
      expect(g.firstWindSpoken, [order[0]]);
      _press(g, _air(g), order[2]); // out of turn
      expect(g.firstWindSpoken, isEmpty);
      expect(g.discoveredClouds, isNot(contains(kAirFirstWindEggId)));
      // The wear survives the failure — what the player learned is still true.
      expect(g.firstWindStage, 2);
      // And the walk can be made again.
      for (final i in order) {
        _press(g, _air(g), i);
      }
      _settle(g);
      expect(g.discoveredClouds, contains(kAirFirstWindEggId));
    });

    test('standing away from the pillars AND the heart works nothing', () {
      final g = _spire();
      final a = _air(g);
      g.activeIndex = g.creatures.indexOf(a);
      a.position = g.currentRoom.bounds.topLeft + const Offset(80, 80);
      g.activateAbility();
      expect(g.firstWindStage, 0);
      expect(g.firstWindScoured, isEmpty);
    });
  });

  group('what the old version got wrong', () {
    test('it is NOT gated on having finished the dungeon', () {
      // A secret you can only find after three stars is a secret nobody
      // finds. This game has no stars at all.
      final g = _spire();
      expect(g.starsEarnedCount, 0);
      _open(g);
      for (final i in g.firstWindOrder) {
        _press(g, _air(g), i);
      }
      _settle(g);
      expect(g.discoveredClouds, contains(kAirFirstWindEggId));
    });

    test('and it does not end on a borrowed quotation', () {
      // Air ended on Seneca — the one line on the roster that was actually
      // about its room, and still a line lifted from someone else. What
      // gathers over the rose now is the compass's OWN ring, in pieces, and
      // the payout is the Rite of Three.
      final g = _spire();
      _open(g);
      for (final i in g.firstWindOrder) {
        _press(g, _air(g), i);
      }
      expect(
        g.riteActive,
        isTrue,
        reason: 'the reaction pays it, not a popup',
      );
      for (var i = 0; i < 400; i++) {
        g.update(1 / 60);
      }
      expect(g.discoveredClouds, contains(kAirFirstWindEggId));
    });
  });
}
