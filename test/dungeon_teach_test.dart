// Teaching without narrating.
//
// A planet whose whole rule is invisible — "burnt ground never takes vine
// again", "the heart does not wait for you" — cannot be deduced by looking at
// a room, so the primer and the room teaches exist. But walking in says
// nothing (the author, 2026-10-08: "only pop them up when we request hints"):
// they are held for the HINT button, which lights, and spent the first time
// they are read. These pin that they wait, and that once read they stay read.

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

    test('the primer waits for HINT on the first descent', () {
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element)..beginRun();
        expect(g.hintText, isNull, reason: '$element spoke on arrival');
        expect(g.hintHasAnswer, isTrue, reason: element);
        expect(g.discoveredClouds, isNot(contains('teach:primer')));
        g.askForRoomHint();
        expect(
          g.hintText,
          contains(kPlanetDungeonLayouts[element]!.primer.first),
          reason: element,
        );
        expect(g.discoveredClouds, contains('teach:primer'), reason: element);
      }
    });

    test('and never again', () {
      // The whole point. A second descent, or a death and a re-entry, has
      // nothing new to hold — otherwise this is chatter wearing a hat.
      for (final element in kPlanetDungeonLayouts.keys) {
        final g = _game(element, known: {'teach:primer'});
        g.beginRun();
        final room = g.currentRoom;
        if (room.teach != null) continue; // that room teaches something else
        expect(g.hintText, isNull, reason: element);
        expect(
          g.hintHasAnswer,
          isFalse,
          reason: '$element held its primer again on a later descent',
        );
      }
    });

    test('an unread primer is still held after the room changes', () {
      final g = _game('Fire')..beginRun();
      final door = g.currentRoom.doors.first;
      g.passThroughDoor(door);
      expect(g.hintText, isNull);
      g.askForRoomHint();
      expect(g.hintText, contains(g.layout.primer.first));
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
      expect(g.hintText, isNull, reason: 'walking in says nothing');
      expect(g.hintHasAnswer, isTrue);
      g.askForRoomHint(); // the primer
      expect(g.discoveredClouds, isNot(contains('teach:cloister')));
      g.askForRoomHint(); // the room's teach
      expect(g.hintText, contains('Every square must burn'));
      expect(g.discoveredClouds, contains('teach:cloister'));

      // Walking back in later has nothing new to hold.
      g.hintText = null;
      g.beginRun();
      expect(g.hintText, isNull);
      expect(
        g.hintHasAnswer,
        isFalse,
        reason: 'a teach the player already read is chatter',
      );
      expect(cloister.teach, isNotNull);
    });

    test('a teach nobody asked for is held again next time', () {
      final g = _game('Fire', known: {'teach:primer'});
      g.currentRoomId = 'cloister';
      g.beginRun();
      expect(g.hintHasAnswer, isTrue);
      // Left unread: not spent.
      expect(g.discoveredClouds, isNot(contains('teach:cloister')));
      g.beginRun();
      g.askForRoomHint();
      expect(g.hintText, contains('Every square must burn'));
    });

    test('a room with nothing new to teach stays quiet', () {
      final g = _game('Fire', known: {'teach:primer'});
      // narthex is the entrance and teaches no verb.
      expect(g.layout.rooms['narthex']!.teach, isNull);
      g.beginRun();
      expect(g.hintText, isNull);
      expect(g.hintHasAnswer, isFalse);
    });
  });
}
