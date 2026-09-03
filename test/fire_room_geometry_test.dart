// The garth you can see, and the candles that answer to being walked past.
//
// THE GARTH used to be stretched across the whole cloister — the field WAS
// the room — which made one square 137x148. A portrait phone holds about
// three columns of a six-column garden, so the chain reaction, which is the
// entire puzzle, happened mostly off the edge of the screen. It is a fixed
// 64px grid now, laid in the middle of the room with paths around it.
//
// Re-anchoring a grid is the kind of change that looks right and acts wrong:
// if the origin the drawing uses and the origin the VERBS use drift apart,
// every bed you touch is the wrong bed. So the round-trip here is driven
// through the real ability rather than through the maths.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/burn_field.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A portrait phone in logical pixels — the smallest thing the dungeon has to
/// be readable on.
const Size _kPortrait = Size(390, 844);

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

PlanetDungeonGame _fire(String room) {
  final els = kCosmicPlanetEntry['Fire']!;
  final fams = kDungeonIdealFamilies['Fire']!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: 'Fire',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = room;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = at
        ..lastSafe = at,
    );
  }
  g.onGameResize(Vector2(_kPortrait.width, _kPortrait.height));
  return g;
}

void main() {
  final cloister = kPlanetDungeonLayouts['Fire']!.rooms['cloister']!;
  final garth = cloister.garth!;

  group('the garth fits on the screen it is played on', () {
    test('the whole board, kerb included, clears a portrait viewport', () {
      final g = _fire('cloister');
      final field = g.garthField(cloister, garth).inflate(9);
      expect(
        field.width,
        lessThanOrEqualTo(_kPortrait.width),
        reason: 'a garden wider than the phone is a chain you cannot follow',
      );
      expect(field.height, lessThanOrEqualTo(_kPortrait.height));
    });

    test('and it is a garden IN a room, not the room itself', () {
      final g = _fire('cloister');
      final field = g.garthField(cloister, garth);
      expect(
        cloister.bounds.contains(field.topLeft),
        isTrue,
        reason: 'the field must sit inside the cloister with paths around it',
      );
      expect(cloister.bounds.contains(field.bottomRight), isTrue);
      expect(field.width, lessThan(cloister.bounds.width - 100));
    });

    test('the vane and its ring stand clear of the beds', () {
      // The progress ring is 108 across and a square is 64: parked at the
      // middle of the field it covered the four squares a chain most often
      // turns on. This is why the garth is no longer centred on the vane.
      final g = _fire('cloister');
      final field = g.garthField(cloister, garth);
      final vane = cloister.windVane!;
      const ringRadius = 54.0 + 11.0; // arc plus the longest tooth
      expect(
        field
            .inflate(9)
            .overlaps(Rect.fromCircle(center: vane, radius: ringRadius)),
        isFalse,
        reason: 'the ring is sitting on the garden again',
      );
      expect(
        cloister.bounds.inflate(-8).contains(vane),
        isTrue,
        reason: 'and it still has to be in the room',
      );
    });
  });

  group('the grid the verbs use is the grid that is drawn', () {
    test('planting at a square\'s centre plants THAT square', () {
      // The round-trip. Driven through the real ability, because the failure
      // this guards against is the drawing and the verbs disagreeing.
      final g = _fire('cloister');
      final field = g.burnFieldFor(cloister)!;
      final plant = g.creatures.indexWhere((c) => c.member.element == 'Plant');
      expect(plant, isNot(-1), reason: 'Fire\'s trio carries the Plant');
      g.setActive(plant);

      var planted = 0;
      for (var i = 0; i < garth.cols * garth.rows; i++) {
        if (field.at(i) != BurnCell.soil) continue;
        g.creatures[plant].position = g.garthCentre(cloister, garth, i);
        g.activateAbility();
        expect(
          field.at(i),
          BurnCell.vine,
          reason: 'standing on square $i planted something else',
        );
        planted++;
      }
      expect(planted, garth.coverageGoal);
    });

    test('standing off the field plants nothing', () {
      final g = _fire('cloister');
      final field = g.burnFieldFor(cloister)!;
      final plant = g.creatures.indexWhere((c) => c.member.element == 'Plant');
      g.setActive(plant);
      final before = [
        for (var i = 0; i < garth.cols * garth.rows; i++) field.at(i),
      ];
      // The path around the garden — walkable, and not soil.
      g.creatures[plant].position =
          g.garthField(cloister, garth).topLeft - const Offset(40, 40);
      g.activateAbility();
      for (var i = 0; i < before.length; i++) {
        expect(field.at(i), before[i], reason: 'square $i changed from a path');
      }
    });
  });

  group('the nave lights as you walk it', () {
    final nave = kPlanetDungeonLayouts['Fire']!.rooms['nave']!;

    test('walking the aisle lights the whole bay, both sides', () {
      // The pair of piers is one bay of the church. Reach is measured ACROSS
      // the nave only, so walking the runner between them lights both — a
      // radius around each stand meant detouring to the wall and back twice
      // per bay, which is not walking a nave, it is mowing it.
      final g = _fire('nave');
      final stands = g.naveCandleStands(nave);
      expect(stands, hasLength(8));
      expect(g.naveCandles, isEmpty, reason: 'a cold nave to begin with');

      // Dead centre of the runner, level with the second bay.
      g.creatures[g.activeIndex].position = Offset(
        stands[2].dx,
        nave.bounds.top + 338,
      );
      for (var i = 0; i < 60; i++) {
        g.update(1 / 60);
      }
      expect(g.naveCandles[2], 1.0, reason: 'the pier above the aisle');
      expect(g.naveCandles[3], 1.0, reason: 'and the one below it');

      // Walk away: they do not go out. The point is the avenue behind you.
      g.creatures[g.activeIndex].position = nave.bounds.topLeft;
      for (var i = 0; i < 60; i++) {
        g.update(1 / 60);
      }
      expect(g.naveCandles[2], 1.0);
      expect(g.naveCandles[3], 1.0);
    });

    test('the far end of the nave stays dark until you get there', () {
      final g = _fire('nave');
      final stands = g.naveCandleStands(nave);
      g.creatures[g.activeIndex].position = Offset(
        stands[0].dx,
        nave.bounds.top + 338,
      );
      for (var i = 0; i < 60; i++) {
        g.update(1 / 60);
      }
      expect(g.naveCandles[0], 1.0);
      expect(g.naveCandles[1], 1.0);
      // The last bay is 600 down the nave — nothing there has been walked.
      expect(g.naveCandles[6] ?? 0, 0.0);
      expect(g.naveCandles[7] ?? 0, 0.0);
    });

    test('every stand is somewhere a walker can actually reach', () {
      // A candle at the far side of a wall would never light, and nothing
      // would say so.
      final g = _fire('nave');
      for (final p in g.naveCandleStands(nave)) {
        expect(nave.bounds.inflate(-20).contains(p), isTrue, reason: '$p');
      }
    });
  });

  group('a fire that dies takes the board with it', () {
    /// Six squares planted along the top row, and the first one lit. With an
    /// east wind that chain eats the row and then has nowhere to go.
    PlanetDungeonGame lit() {
      final g = _fire('cloister');
      final f = g.burnFieldFor(cloister)!;
      for (var i = 0; i < 6; i++) {
        f.plant(i);
      }
      expect(f.light(0), isTrue);
      return g;
    }

    test('a chain that stops short wipes itself back to bare soil', () {
      // The goal is ONE chain, so a chain that stops short has already
      // failed. Leaving its ash on the board only makes the player work that
      // out themselves and press re-lay, which is a chore, not a decision.
      final g = lit();
      final before = g.burnFieldFor(cloister)!;
      var guard = 0;
      while (before.alight && guard++ < 4000) {
        g.update(1 / 60);
      }
      expect(before.alight, isFalse, reason: 'the row runs out and it dies');
      expect(g.garthWipeIn, greaterThan(0), reason: 'a beat to see it die');
      expect(
        g.burnFieldFor(cloister),
        same(before),
        reason: 'and the ash is still there while that beat runs',
      );

      for (var i = 0; i < 200; i++) {
        g.update(1 / 60);
      }
      final after = g.burnFieldFor(cloister)!;
      expect(after, isNot(same(before)), reason: 'a fresh field');
      for (var i = 0; i < garth.cols * garth.rows; i++) {
        expect(
          after.at(i),
          isNot(BurnCell.ash),
          reason: 'square $i is still burnt after the turn-over',
        );
      }
      expect(after.burntThisFire, 0);
      expect(g.garthWipeIn, 0);
    });

    test('a hand on the board beats the pending wipe', () {
      final g = lit();
      final before = g.burnFieldFor(cloister)!;
      var guard = 0;
      while (before.alight && guard++ < 4000) {
        g.update(1 / 60);
      }
      expect(g.garthWipeIn, greaterThan(0));
      g.restartRoom();
      expect(g.garthWipeIn, 0, reason: 'the re-lay already did the work');
    });

    test('a chain that covers the garden banks the star instead', () {
      // The wipe must never eat a win: coverage is checked on the beat that
      // takes the last square, before the fire has anywhere left to go.
      final g = _fire('cloister');
      final f = g.burnFieldFor(cloister)!;
      expect(g.hasStar(garth.starIndex), isFalse);
      for (var i = 0; i < garth.cols * garth.rows; i++) {
        f.plant(i);
      }
      f.light(0);
      f.burntThisFire = garth.coverageGoal - 1;
      var guard = 0;
      while (!g.hasStar(garth.starIndex) && guard++ < 4000) {
        g.update(1 / 60);
      }
      expect(
        g.hasStar(garth.starIndex),
        isTrue,
        reason: 'the beat that completes the cover releases the star',
      );
      expect(g.garthWipeIn, 0, reason: 'and nothing is turned over');
    });
  });
}
