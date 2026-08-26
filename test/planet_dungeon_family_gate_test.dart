// "THE SEAL REMEMBERS" (docs/dungeons.md §4 + §9.0 step 3): first contact
// with a hard family gate permanently stamps the requirement onto the
// planet's overworld descent panel, riding the existing one-time cloud
// discovery channel.
//
// Pinned here:
//   • Layout contract — every authored gate's discovery id is safe under
//     PlanetStarState's serialisation separators (`,` `=` `.` `|`), and every
//     gate answers to one of the planet's three entry slots.
//   • Stamp-on-refusal — the wrong family at each of the three shipped gates
//     (Earth rib, Water pipe-mouth, Air conduit A) speaks the refusal on the
//     BLOCKED channel and fires the discovery exactly once (idempotent).
//   • Persistence — a re-seeded gate id never re-fires the discovery.
//   • Save-compat migration (§9.0 ruling) — fully-cleared planets auto-stamp
//     their gates on load; partial clears do not.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: 'Test $slot',
    element: element,
    family: family,
    level: 10,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    slotIndex: slot,
    staminaBars: 3,
    staminaMax: 3,
  );
}

CosmicSurvivalCompanion _companion(CosmicPartyMember member, Offset position) {
  final stats = deriveCosmicSurvivalCompanionStats(member: member);
  return CosmicSurvivalCompanion(
    member: member,
    slotIndex: member.slotIndex,
    position: position,
    anchor: position,
    maxHp: stats.maxHp,
    currentHp: stats.maxHp,
    physAtk: stats.physAtk,
    elemAtk: stats.elemAtk,
    physDef: stats.physDef,
    elemDef: stats.elemDef,
    cooldownReduction: stats.cooldownReduction,
    critChance: stats.critChance,
    attackRange: stats.attackRange,
    specialAbilityRange: stats.specialAbilityRange,
    tethered: false,
    invincibleTimer: 0,
  );
}

/// A headless dungeon on [element] with [party], recording every discovery.
PlanetDungeonGame _harness(
  String element,
  List<CosmicPartyMember> party, {
  List<String>? discoveries,
  Set<String> initialDiscoveredCloudIds = const {},
}) {
  final game = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    initialDiscoveredCloudIds: initialDiscoveredCloudIds,
    onStarEarned: (_) {},
    onCloudDiscovered: discoveries?.add,
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  final spawn = game.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    final c = DungeonCreature(member: party[i])
      ..position = spawn + Offset(i * 60.0, 0)
      ..lastSafe = spawn + Offset(i * 60.0, 0);
    game.creatures.add(c);
    game.combatCompanions.add(_companion(party[i], c.position));
  }
  return game;
}

/// Teleport the whole party to [pos] in [roomId] and press UTILITY once.
void _attemptAt(PlanetDungeonGame game, String roomId, Offset pos) {
  game.currentRoomId = roomId;
  for (final c in game.creatures) {
    c
      ..position = pos
      ..lastSafe = pos;
  }
  game.activateAbility();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('layout contract', () {
    test('every gate discovery id avoids the PlanetStarState separators', () {
      // `,` `=` `.` `|` are the serialisation format's split characters
      // (cosmic_data.dart, PlanetStarState.serialise) — an id carrying one
      // would corrupt every planet's persisted state on the round trip.
      for (final layout in kPlanetDungeonLayouts.values) {
        for (final gate in layout.familyGates) {
          final id = gate.discoveryId;
          expect(id, startsWith('gate:'));
          for (final forbidden in const [',', '=', '.', '|']) {
            expect(
              id.contains(forbidden),
              isFalse,
              reason:
                  '${layout.element} gate id "$id" must not contain '
                  '"$forbidden"',
            );
          }
        }
      }
    });

    test('every gate answers to one of the planet\'s three entry slots', () {
      for (final layout in kPlanetDungeonLayouts.values) {
        final slots = kCosmicPlanetEntry[layout.element];
        if (layout.familyGates.isEmpty) continue;
        expect(slots, isNotNull);
        for (final gate in layout.familyGates) {
          // A VERB-ONLY gate (kAnyElement) names no element at all — the
          // family's act is the whole requirement — so it has no entry slot
          // to sit on and this invariant does not apply to it.
          if (!gate.needsElement) continue;
          expect(
            slots,
            contains(gate.element),
            reason:
                '${layout.element}\'s gate on "${gate.objectId}" wants '
                '${gate.element}, which no entry slot carries — the §6 ideal '
                'trio could not clear it',
          );
        }
      }
    });

    test('every gate names a real family with a real dungeon verb', () {
      for (final layout in kPlanetDungeonLayouts.values) {
        for (final gate in layout.familyGates) {
          expect(
            abilityForFamily(gate.family),
            isNot(DungeonAbility.none),
            reason:
                '${layout.element} gate family "${gate.family}" maps to no '
                'dungeon ability',
          );
          expect(gate.hintLine, isNotEmpty);
        }
      }
    });

    test('the three v2 hard gates are declared (Air, Water, Earth)', () {
      expect(
        kPlanetDungeonLayouts['Air']!.familyGateFor('A')?.discoveryId,
        'gate:lightning_horn',
      );
      expect(
        kPlanetDungeonLayouts['Water']!
            .familyGateFor('pipe_mouth')
            ?.discoveryId,
        'gate:water_pip',
      );
      expect(
        kPlanetDungeonLayouts['Earth']!.familyGateFor('rib')?.discoveryId,
        'gate:earth_horn',
      );
      // The refit declared no gate for the other three planets.
      expect(kPlanetDungeonLayouts['Fire']!.familyGates, isEmpty);
      expect(kPlanetDungeonLayouts['Lightning']!.familyGates, isEmpty);
      expect(kPlanetDungeonLayouts['Steam']!.familyGates, isEmpty);
    });
  });

  group('stamp on refusal', () {
    test('the Earth rib stamps gate:earth_horn once, on the BLOCKED line', () {
      final discoveries = <String>[];
      final game = _harness('Earth', [
        _member(0, 'Earth', 'mane'),
      ], discoveries: discoveries);
      final rib = game.layout.rooms['rib_hall']!.fossilRibs.first;
      final stand = rib.notches.first - const Offset(110, 0);

      _attemptAt(game, 'rib_hall', stand);
      game.askForRoomHint();
      expect(game.hintText, 'Only an Earth horn\'s force shifts this bone');
      game.askForRoomHint();
      expect(game.hintChannel, DungeonHintChannel.blocked);
      expect(game.discoveredClouds, contains('gate:earth_horn'));
      expect(discoveries, ['gate:earth_horn']);

      // A second refusal re-speaks (attempt-edged press) but never re-stamps.
      _attemptAt(game, 'rib_hall', stand);
      expect(discoveries, ['gate:earth_horn'], reason: 'the stamp is one-time');
    });

    test('the Water pipe-mouth stamps gate:water_pip', () {
      final discoveries = <String>[];
      final game = _harness('Water', [
        _member(0, 'Water', 'horn'),
      ], discoveries: discoveries);
      final mouth = game.layout.rooms['moon_well']!.tideValves.single;

      _attemptAt(game, 'moon_well', mouth.position);
      game.askForRoomHint();
      expect(game.hintText, 'Only a Water pip slips down this pipe-mouth');
      game.askForRoomHint();
      expect(game.hintChannel, DungeonHintChannel.blocked);
      expect(discoveries, ['gate:water_pip']);
    });

    test('Air conduit A stamps gate:lightning_horn', () {
      final discoveries = <String>[];
      final game = _harness('Air', [
        _member(0, 'Lightning', 'pip'),
      ], discoveries: discoveries);
      final conduitA = game.layout.rooms['twin_conduit']!.conduits.firstWhere(
        (c) => c.id == 'A',
      );

      _attemptAt(game, 'twin_conduit', conduitA.position);
      game.askForRoomHint();
      expect(game.hintText, 'Only a Lightning horn\'s grip holds this current');
      game.askForRoomHint();
      expect(game.hintChannel, DungeonHintChannel.blocked);
      expect(discoveries, ['gate:lightning_horn']);
    });

    test('a persisted stamp never re-fires the discovery callback', () {
      final discoveries = <String>[];
      final game = _harness(
        'Earth',
        [_member(0, 'Earth', 'mane')],
        discoveries: discoveries,
        initialDiscoveredCloudIds: const {'gate:earth_horn'},
      );
      final rib = game.layout.rooms['rib_hall']!.fossilRibs.first;

      _attemptAt(game, 'rib_hall', rib.notches.first - const Offset(110, 0));
      // The refusal still speaks — knowledge is not silence — but nothing is
      // re-discovered, so the screen never re-toasts or re-persists.
      game.askForRoomHint();
      expect(game.hintChannel, DungeonHintChannel.blocked);
      expect(discoveries, isEmpty);
    });
  });

  group('save-compat migration (§9.0 ruling)', () {
    test('a fully-cleared planet auto-stamps its gates', () {
      final cleared = const PlanetStarState(starMasks: {'Earth': 7});
      final out = stampClearedPlanetFamilyGates(cleared);
      expect(out.discoveredCloudsFor('Earth'), contains('gate:earth_horn'));
      // Other planets stay untouched.
      expect(out.discoveredCloudsFor('Air'), isEmpty);
      expect(out.discoveredCloudsFor('Water'), isEmpty);
    });

    test('a partial clear does NOT auto-stamp — the gate is live content', () {
      final partial = const PlanetStarState(
        starMasks: {'Earth': 3, 'Water': 1},
      );
      final out = stampClearedPlanetFamilyGates(partial);
      expect(identical(out, partial), isTrue);
      expect(out.discoveredCloudsFor('Earth'), isEmpty);
      expect(out.discoveredCloudsFor('Water'), isEmpty);
    });

    test('the migration is idempotent and cheap to detect', () {
      final cleared = const PlanetStarState(
        starMasks: {'Air': 7, 'Water': 7, 'Earth': 7},
      );
      final once = stampClearedPlanetFamilyGates(cleared);
      expect(once.discoveredCloudsFor('Air'), contains('gate:lightning_horn'));
      expect(once.discoveredCloudsFor('Water'), contains('gate:water_pip'));
      expect(once.discoveredCloudsFor('Earth'), contains('gate:earth_horn'));
      // Nothing left to stamp → the exact same instance comes back, which is
      // how the overworld decides whether to re-persist.
      final twice = stampClearedPlanetFamilyGates(once);
      expect(identical(twice, once), isTrue);
    });

    test('stamped state survives the serialise round trip intact', () {
      final stamped = stampClearedPlanetFamilyGates(
        const PlanetStarState(starMasks: {'Water': 7}),
      );
      final revived = PlanetStarState.deserialise(stamped.serialise());
      expect(revived.discoveredCloudsFor('Water'), contains('gate:water_pip'));
      expect(revived.starsEarned('Water'), 3);
    });
  });
}
