// The rematch button, and the one rule it is allowed to break.
//
// A guardian retires the moment its star is banked, which is right for a run
// and useless for measuring one: the Simurgh fight is where the frame budget
// falls apart, and reaching it costs a whole descent. The debug rematch calls
// it back down anyway.
//
// What must NOT break: banking. A boss you can kill repeatedly is a boss that
// could pay repeatedly, and the debug path must never be a progress exploit.

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

/// [stars] is banked through [PlanetDungeonGame.earnStar] rather than the
/// constructor's mask: the mask is only unpacked in onLoad, which never runs
/// headlessly, so a game built with 0x7 here still believes it has nothing.
PlanetDungeonGame _game(String element, {int stars = 0}) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  for (var i = 0; i < 3; i++) {
    if ((stars & (1 << i)) != 0) g.earnStar(i);
  }
  return g;
}

void main() {
  group('the debug rematch', () {
    test('every dungeon it offers itself in really has a guardian', () {
      // The button only shows where hasGuardianRoom is true, so that getter
      // is the promise that pressing it will do something.
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element);
        final rooms = g.layout.rooms.values.where((r) => r.guardian != null);
        expect(
          g.hasGuardianRoom,
          rooms.isNotEmpty,
          reason: '$element disagrees about whether it has a lair',
        );
      }
    });

    test('it carries the party to the lair and wakes the guardian', () {
      final g = _game('Fire');
      expect(g.currentRoom.guardian, isNull, reason: 'starts at the door');
      expect(g.guardianAwake, isFalse);

      g.debugSpawnGuardian();

      expect(g.currentRoom.guardian, isNotNull, reason: 'moved to the lair');
      expect(g.guardianAwake, isTrue);
      expect(g.debugGuardianRematch, isTrue);
      for (final c in g.creatures) {
        expect(
          g.currentRoom.bounds.inflate(4).contains(c.position),
          isTrue,
          reason: 'the party came along: ${c.position}',
        );
      }
    });

    test('a banked star no longer retires it', () {
      // The whole point. With all three stars the lair is normally empty.
      final g = _game('Fire', stars: 0x7);
      g.debugSpawnGuardian();
      final lair = g.currentRoom;
      expect(g.hasStar(lair.guardian!.starIndex), isTrue);

      var guard = 0;
      while (g.combatEnemies.isEmpty && guard++ < 1200) {
        g.update(1 / 60);
      }
      expect(
        g.combatEnemies,
        isNotEmpty,
        reason: 'the guardian must come back down for a rematch',
      );
    });

    test('and without the rematch it stays retired', () {
      // The control. If this ever spawns, the debug flag is not what is
      // doing the work and the normal run has a resurrecting boss.
      final g = _game('Fire', stars: 0x7);
      DungeonRoom? lair;
      for (final r in g.layout.rooms.values) {
        if (r.guardian != null) lair = r;
      }
      g.currentRoomId = lair!.id;
      g.guardianAwake = true;
      for (var i = 0; i < 1200; i++) {
        g.update(1 / 60);
      }
      expect(g.combatEnemies, isEmpty);
    });

    test('a rematch cannot pay twice', () {
      // earnStar is idempotent, and this is the property that makes the whole
      // debug path safe to ship behind the tools switch.
      final paid = <int>[];
      final els = kCosmicPlanetEntry['Fire']!;
      final fams = kDungeonIdealFamilies['Fire']!;
      final g = PlanetDungeonGame(
        element: 'Fire',
        party: [
          for (var i = 0; i < els.length; i++)
            _m(els[i], fams[i].toLowerCase()),
        ],
        initialStarMask: 0,
        onStarEarned: paid.add,
        onPlayerDown: () {},
        onChanged: () {},
      );
      g.onGameResize(Vector2(412, 915));
      DungeonRoom? lair;
      for (final r in g.layout.rooms.values) {
        if (r.guardian != null) lair = r;
      }
      final star = lair!.guardian!.starIndex;
      g.earnStar(star);
      g.earnStar(star);
      g.earnStar(star);
      expect(paid, [star], reason: 'banked once, however often it is killed');
    });
  });
}
