// Teaching without narrating.
//
// The dungeon stopped speaking on room entry because constant chatter trains
// the player to ignore the capsule. But a planet whose whole rule is invisible
// — "burnt ground never takes vine again", "the heart does not wait for you" —
// cannot be deduced by looking at a room, and silence there is not restraint,
// it is a missing tutorial.
//
// So there is exactly one exception, and it is bounded: a line shown ONCE in a
// save. These pin that it stays once.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String element, String family) => CosmicPartyMember(
  instanceId: '$element$family',
  baseId: 'b',
  displayName: '$element $family',
  imagePath: '',
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

PlanetDungeonGame _game(String element, {Set<String>? known}) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
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
  if (known != null) g.discoveredClouds.addAll(known);
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = at
        ..lastSafe = at,
    );
  }
  g.onGameResize(Vector2(390, 844));
  return g;
}

void main() {
  group('every planet states its rule once', () {
    test('all seventeen author a primer', () {
      kPlanetDungeonLayouts.forEach((element, layout) {
        expect(
          layout.primer,
          isNotEmpty,
          reason: '$element has no primer — its world rule is unteachable',
        );
        for (final line in layout.primer) {
          expect(line.length, greaterThan(20), reason: element);
          expect(line.endsWith('.'), isTrue, reason: '$element: "$line"');
        }
      });
    });

    test('the primer speaks on the first descent', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element)..beginRun();
        expect(g.hintText, isNotNull, reason: element);
        expect(
          g.hintText,
          contains(kPlanetDungeonLayouts[element]!.primer.first),
          reason: element,
        );
      }
    });

    test('and never again', () {
      // The whole point. A second descent, or a death and a re-entry, must be
      // silent — otherwise this is the old objective chatter wearing a hat.
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element, known: {'teach:primer'});
        g.beginRun();
        final room = g.currentRoom;
        if (room.teach != null) continue; // that room teaches something else
        expect(
          g.hintText,
          isNull,
          reason: '$element repeated its primer on a later descent',
        );
      }
    });
  });

  group('a room teaches its own verb once', () {
    test("Fire's three mechanic rooms carry a teach", () {
      final fire = kPlanetDungeonLayouts['Fire']!;
      for (final id in ['cloister', 'choir', 'scriptorium']) {
        expect(fire.rooms[id]!.teach, isNotNull, reason: id);
      }
    });

    test('a teach fires once and is remembered', () {
      final g = _game('Fire');
      final cloister = g.layout.rooms['cloister']!;
      g.currentRoomId = 'cloister';

      g.beginRun();
      expect(g.hintText, contains('walks itself'));
      expect(g.discoveredClouds, contains('teach:cloister'));

      // Walking back in later says nothing.
      g.hintText = null;
      g.beginRun();
      expect(
        g.hintText,
        isNull,
        reason: 'a teach the player already read is chatter',
      );
      expect(cloister.teach, isNotNull);
    });

    test('a room with nothing new to teach stays quiet', () {
      final g = _game('Fire', known: {'teach:primer'});
      // narthex is the entrance and teaches no verb.
      expect(g.layout.rooms['narthex']!.teach, isNull);
      g.beginRun();
      expect(g.hintText, isNull);
    });
  });
}
