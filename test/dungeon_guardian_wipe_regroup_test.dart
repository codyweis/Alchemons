// A WIPE AT THE GUARDIAN REGROUPS AT ITS DOOR (2026-11-02).
//
// Falling to a guardian used to wake the party at the planet's entrance with
// every puzzle undone. Now, on every planet whose fight allows it, the party
// stands up whole where it came into the lair, the guardian descends again at
// full strength, and the run's stars and finds are untouched. Poison, Dark,
// Light and Blood keep the full reset (their fights spend what the run cannot
// give back, or stand bodies on floors where a regroup could place one
// wrong), and a wipe anywhere else still resets the run.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

const _fullReset = {'Poison', 'Dark', 'Light', 'Blood'};

PlanetDungeonGame _game(String element, {required void Function() onDown}) {
  final els = kCosmicPlanetEntry[element] ?? [element, 'Air', 'Fire'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: const ['mane', 'mask', 'horn'][i % 3],
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 3, // the two stars that open the lair
    onStarEarned: (_) {},
    onPlayerDown: onDown,
    onChanged: () {},
  );
  g.entryDoorRevealed = true;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = g.layout.entranceSpawn
        ..lastSafe = g.layout.entranceSpawn,
    );
  }
  return g;
}

/// Walk the party in through a door of the guardian's lair, wake it, and let
/// it land.
({String lair, DungeonDoor door})? _enterTheFight(PlanetDungeonGame g) {
  final lair = g.layout.rooms.values.where((r) => r.guardian != null);
  if (lair.isEmpty) return null;
  final id = lair.first.id;
  for (final room in g.layout.rooms.values) {
    for (final d in room.doors) {
      if (d.targetRoomId != id || room.id == id) continue;
      g.currentRoomId = room.id;
      for (final c in g.creatures) {
        c.position = d.rect.center;
      }
      g.passThroughDoor(d);
      g.guardianAwake = true;
      for (var i = 0; i < 300; i++) {
        g.update(1 / 60);
      }
      return (lair: id, door: d);
    }
  }
  return null;
}

void main() {
  final fought = <String>[];
  for (final element in kPlanetDungeonLayouts.keys) {
    test('$element: a wipe at the guardian '
        '${_fullReset.contains(element) ? 'still resets the run' : 'regroups at its door'}',
        () {
      var downs = 0;
      final g = _game(element, onDown: () => downs++);
      final fight = _enterTheFight(g);
      if (fight == null) return; // no reachable lair to test
      expect(g.currentRoomId, fight.lair);
      if (!g.inGuardianFight) return; // a lair that needs its own rite first
      fought.add(element);
      final finds = {...g.discoveredClouds};
      final stars = [for (var i = 0; i < 3; i++) g.hasStar(i)];

      for (final c in g.creatures) {
        c.hp = 0;
      }
      g.update(1 / 60);

      expect(downs, 1, reason: 'the fall is still shown');
      expect(
        [for (var i = 0; i < 3; i++) g.hasStar(i)],
        stars,
        reason: 'stars are kept',
      );
      expect(g.discoveredClouds, containsAll(finds));
      if (_fullReset.contains(element)) {
        expect(g.currentRoomId, g.layout.entranceRoomId);
        return;
      }
      expect(g.currentRoomId, fight.lair, reason: 'back at the lair door');
      expect(g.creatures.every((c) => c.alive && c.hp == c.maxHp), isTrue);
      expect(g.guardianAwake, isTrue);
      expect(g.guardianVulnerable, isFalse);
      expect(g.inGuardianFight, isTrue, reason: 'the fight starts over');
      // The guardian comes down again, whole.
      for (var i = 0; i < 300; i++) {
        g.update(1 / 60);
      }
      expect(g.guardianHpFractionForTest, closeTo(1.0, 0.05));
    });
  }

  test('the fight was really reached on almost every planet', () {
    // ignore: avoid_print
    print('regroup fights reached: $fought');
    expect(fought.length, greaterThanOrEqualTo(14));
  });
}
