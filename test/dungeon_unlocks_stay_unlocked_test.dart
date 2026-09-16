// WHAT IS OPENED STAYS OPENED — all seventeen.
//
// docs/dungeons.md §5.7. A door that a one-time act opens must never ask for
// that act again: the entry rite, a star gate, a rite sung at an altar, a key
// turned, a disc blown. The planets that re-gate space do it with a world
// STATE the player authors and can author back (Water's tide, Ice's flues,
// Dark's flip, Mud's fords, Crystal's sliding chambers) — that is a different
// thing, and it is the mechanic rather than an unlock.
//
// The three things below are the ones that hold for EVERY planet, so they are
// checked for every planet, and a new one inherits them for free.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game(String element, {bool banked = false}) {
  final els = kCosmicPlanetEntry[element] ?? const ['Fire', 'Water', 'Air'];
  const fams = ['mane', 'mask', 'wing'];
  final party = [
    for (var i = 0; i < els.length; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i % 3],
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
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  if (banked) {
    // onLoad() is Flame's, and this harness never mounts: bank them the way
    // the game does.
    g.earnStar(0);
    g.earnStar(1);
  }
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = g.layout.entranceSpawn
        ..lastSafe = g.layout.entranceSpawn,
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final element in kPlanetDungeonLayouts.keys) {
    final layout = kPlanetDungeonLayouts[element]!;

    group('$element — what is opened stays opened', () {
      test('the entry rite is not re-run after a wipe', () {
        // The entry puzzle is KNOWLEDGE, not run state: you solved it, and
        // dying does not un-solve it. (It is persisted with the discoveries,
        // so it survives leaving the planet too.)
        final g = _game(element);
        g.entryDoorRevealed = true;
        g.discoveredClouds.add(PlanetDungeonGame.entryDoorDiscoveryId);

        for (final c in g.creatures) {
          c.hp = 0;
        }
        for (var i = 0; i < 6; i++) {
          g.update(1 / 60);
        }
        expect(
          g.entryDoorRevealed,
          isTrue,
          reason: '$element made the party solve its doorway twice',
        );
      });

      test('a rite, once sung, stays sung', () {
        // Conduits LATCH (§9.1). Nothing may quietly drain one back down and
        // re-seal a guardian's chamber behind a party that already opened it.
        final rite = layout.rooms.values
            .where((r) => r.conduits.isNotEmpty)
            .toList();
        if (rite.isEmpty) return;
        final riteRoom = rite.first;
        final g = _game(element, banked: true);
        g.currentRoomId = riteRoom.id;
        // 'A' and 'B' are what the altar reads, whoever authored them: some
        // planets hand the second half to a module-owned object rather than
        // to a Conduit (Ice's cold font, Dust's ledger stone).
        for (final id in ['A', 'B', ...riteRoom.conduits.map((c) => c.id)]) {
          g.conduitEnergy[id] = double.infinity;
        }
        for (var t = 0.0; t < 30; t += 1 / 60) {
          g.update(1 / 60);
        }
        for (final id in ['A', 'B', ...riteRoom.conduits.map((c) => c.id)]) {
          expect(
            g.conduitEnergy[id],
            double.infinity,
            reason: '$element let conduit $id run back down',
          );
        }
        expect(g.altarOpen, isTrue);
      });

      test('a star gate never shuts again once the stars are banked', () {
        final ref = layout.finaleDoor;
        if (ref == null) return;
        final room = layout.rooms[ref.roomId]!;
        final door = room.doors.firstWhere(
          (d) => d.targetRoomId == ref.targetRoomId,
        );
        final g = _game(element, banked: true);
        g.currentRoomId = room.id;
        // Some planets' finale door IS the guardian's own threshold, which is
        // sealed until the rite rouses the mystic (§7, the sealed chamber).
        // That is not this test's subject: rouse it and ask about the STARS.
        g.guardianAwake = true;
        expect(g.guardianRiteUnlocked, isTrue);
        for (var t = 0.0; t < 10; t += 1 / 60) {
          g.update(1 / 60);
        }
        expect(
          g.guardianRiteUnlocked,
          isTrue,
          reason: '$element took a banked star back',
        );
        // NO EXEMPTIONS. This began with a list of planets whose finale
        // doorway was assumed to be part of an authored world state as well
        // as a star gate — and every one of them passed without it. All
        // seventeen hold the plain rule: stars banked, mystic roused, the
        // way to the rite is open and stays open.
        expect(
          g.isDoorLocked(room, door),
          isFalse,
          reason: '$element re-locked its finale door',
        );
      });
    });
  }
}
