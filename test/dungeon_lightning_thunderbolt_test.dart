// Lightning's lost maxim, rebuilt to the MAXIM STANDARD.
//
// It used to fire off Star 3's beam — if a Lightning Horn happened to be
// standing among the conductors when the tower lit. A secret that rides a
// star's coat-tails and asks nothing of its own.
//
// It is built out of the one thing this planet owns that no other does: the
// dynamo is ZERO-SUM. It feeds one trunk and darkens the rest, and every wing
// you have lit cost you the other three. The secret is refusing that — fuse
// every breaker shut so the dynamo has nowhere left to choose, and throw it.

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

PlanetDungeonGame _dynamo() {
  final party = [
    _m('Lightning', 'horn'),
    _m('Air', 'wing'),
    _m('Fire', 'mask'),
  ];
  final g = PlanetDungeonGame(
    element: 'Lightning',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.dynamoRoomId!;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

void _at(PlanetDungeonGame g, String element, Offset p) {
  final c = g.creatures.firstWhere((x) => x.member.element == element);
  g.activeIndex = g.creatures.indexOf(c);
  c
    ..position = p
    ..lastSafe = p;
  g.activateAbility();
}

void _wind(PlanetDungeonGame g) =>
    _at(g, 'Air', g.currentRoom.bounds.center);

void _fuseAll(PlanetDungeonGame g) {
  _wind(g);
  for (final t in g.layout.dynamoTrunks) {
    _at(g, 'Fire', t.breakerPosition);
  }
}

void main() {
  test('the rotor must be over its limit before anything will fuse', () {
    final g = _dynamo();
    final t = g.layout.dynamoTrunks.first;
    _at(g, 'Fire', t.breakerPosition);
    expect(
      g.weldedBreakers,
      isEmpty,
      reason: 'cold jaws will not weld — Air has to wind it first',
    );
    _wind(g);
    expect(g.rotorOverspeed, greaterThan(0));
    _at(g, 'Fire', t.breakerPosition);
    expect(g.weldedBreakers, contains(t.id));
  });

  test('and the wind bleeds out on its own', () {
    // The clock the whole rite runs against.
    final g = _dynamo();
    _wind(g);
    for (var i = 0; i < 60 * 30; i++) {
      g.update(1 / 60);
    }
    expect(g.rotorOverspeed, 0);
    final t = g.layout.dynamoTrunks.last;
    _at(g, 'Fire', t.breakerPosition);
    expect(g.weldedBreakers, isNot(contains(t.id)));
  });

  test('all four fused, and Lightning throws it', () {
    final g = _dynamo();
    _fuseAll(g);
    expect(g.dynamoFused, isTrue);
    _at(g, 'Lightning', g.currentRoom.bounds.center);
    expect(g.riteActive, isTrue, reason: 'the works lets go');
    for (var i = 0; i < 300; i++) {
      g.update(1 / 60);
    }
    expect(g.discoveredClouds, contains(kLightningThunderboltEggId));
  });

  test('three of four is not the secret', () {
    final g = _dynamo();
    _wind(g);
    for (final t in g.layout.dynamoTrunks.take(3)) {
      _at(g, 'Fire', t.breakerPosition);
    }
    expect(g.dynamoFused, isFalse);
    _at(g, 'Lightning', g.currentRoom.bounds.center);
    expect(g.riteActive, isFalse);
  });

  test('a fused breaker is not stuck — the storm blows the weld off', () {
    // The undo, and the reason the rite is allowed a wrong turn at all.
    final g = _dynamo();
    _fuseAll(g);
    final t = g.layout.dynamoTrunks.first;
    _at(g, 'Lightning', t.breakerPosition);
    expect(g.weldedBreakers, isNot(contains(t.id)));
    expect(g.dynamoFused, isFalse);
    // …and it can be fused again.
    _wind(g);
    _at(g, 'Fire', t.breakerPosition);
    expect(g.dynamoFused, isTrue);
  });

  test('all three elements have a job in it', () {
    // The standard's test. Drop any one and the chain does not complete.
    for (final skip in const ['Air', 'Fire', 'Lightning']) {
      final g = _dynamo();
      if (skip != 'Air') _wind(g);
      if (skip != 'Fire') {
        for (final t in g.layout.dynamoTrunks) {
          _at(g, 'Fire', t.breakerPosition);
        }
      }
      if (skip != 'Lightning') {
        _at(g, 'Lightning', g.currentRoom.bounds.center);
      }
      for (var i = 0; i < 300; i++) {
        g.update(1 / 60);
      }
      expect(
        g.discoveredClouds,
        isNot(contains(kLightningThunderboltEggId)),
        reason: 'without $skip the works never lets go',
      );
    }
  });
}
