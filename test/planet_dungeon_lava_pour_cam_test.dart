// THE POUR CAM. When a charge is released the camera leaves the party and
// rides the metal — through rooms the party is not standing in — then holds a
// beat on wherever it ended and gives the view back.
//
// This is the only place in the game that renders a room the party is not in,
// so it is the only place where "draw the room" and "draw the people" come
// apart. Everything the world render touches has to take its room from the
// argument rather than from `currentRoomId`, and a smoke render is the only
// thing that can prove it.

import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame _game() {
  final party = [
    for (final e in ['Lava', 'Earth', 'Ice'])
      CosmicPartyMember(
        instanceId: 'i$e',
        baseId: 'b$e',
        displayName: e,
        element: e,
        family: 'horn',
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: ['Lava', 'Earth', 'Ice'].indexOf(e),
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: 'Lava',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.onGameResize(Vector2(900, 600));
  g.currentRoomId = 'tap_head';
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = const Offset(200, 300)
        ..lastSafe = const Offset(200, 300),
    );
  }
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the camera rides a charge across rooms and gives itself back', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final g = _game();
      g.works.line.tapWoken = true;
      expect(g.works.line.tap(), isTrue);

      final rooms = <String>{};
      var frames = 0;
      while (frames++ < 60 * 40) {
        g.update(1 / 60);
        final watched = g.followRoomId;
        if (watched != null) rooms.add(watched);
        // Render EVERY frame: the whole risk of this feature is a painter
        // that reads `currentRoomId` behind the argument's back.
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        rec.endRecording();
        if (g.works.line.pour == null && !g.followingPour) break;
      }

      expect(
        rooms.length,
        greaterThan(1),
        reason: 'the charge crosses rooms, and the camera goes with it',
      );
      expect(
        rooms,
        contains('tap_head'),
        reason: 'it picks the charge up where it is released',
      );
      expect(
        g.followingPour,
        isFalse,
        reason: 'and lets go once the metal has landed',
      );
      expect(
        g.currentRoomId,
        'tap_head',
        reason: 'the PARTY never moved — only the view did',
      );
    });
  });

  testWidgets('a charge lost speaks WHEN it is lost, not when asked', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Reported from play: the spoil "didn't pop up". It never had. §5.6
      // makes the dungeon refuse to narrate, and `_emitHint` enforces it
      // hard — unasked objective speech is DROPPED and blocked/insight lines
      // are only remembered for the next press of HINT. Right for flavour and
      // for refusals; wrong for a consequence you have already paid for.
      final g = _game();
      g.works.line.tapWoken = true;
      // Aim the mill arm, damper shut, sluice at the KEY form — with the die
      // still dead, so plain metal reaches a form cut for warded.
      g.works.line.switches['y_yard'] = 1;
      g.works.line.switches['damper'] = 0;
      g.works.line.switches['y_sluice'] = 1;
      expect(g.works.line.dieWoken, isFalse);
      expect(g.works.line.tap(), isTrue);

      var frames = 0;
      while (g.works.line.pour != null && frames++ < 60 * 40) {
        g.update(1 / 60);
      }
      expect(
        g.works.line.molds['mold_key'],
        isNotNull,
        reason: 'the form took the charge and ruined it',
      );
      expect(g.hintText, isNotNull, reason: 'and said so, without being asked');
      expect(
        g.hintText,
        contains('STEAM'),
        reason: 'naming what was missing, not that something was',
      );
    });
  });

  testWidgets('STOP gives the view back and KEEPS it back', (tester) async {
    await tester.runAsync(() async {
      final g = _game();
      g.works.line.tapWoken = true;
      g.works.line.tap();
      for (var i = 0; i < 30; i++) {
        g.update(1 / 60);
      }
      expect(g.followingPour, isTrue);

      g.cancelPourWatch();
      expect(g.followingPour, isFalse);

      // THE BUG THIS GUARDS, and it shipped: cancelling only nulled the
      // follow, and the follow re-took it on the very next frame because the
      // metal was still running — so the button visibly did nothing. The
      // first version of this test asserted that re-acquisition as though it
      // were the design, which is how a no-op ships with a green suite.
      expect(g.works.line.pour, isNotNull, reason: 'still running');
      for (var i = 0; i < 60; i++) {
        g.update(1 / 60);
        expect(
          g.followingPour,
          isFalse,
          reason: 'waved off means waved off, for the whole charge',
        );
        if (g.works.line.pour == null) break;
      }

      // But it is not a preference: the NEXT charge is a new look.
      while (g.works.line.pour != null) {
        g.update(1 / 60);
      }
      expect(g.works.line.tap(), isTrue);
      g.update(1 / 60);
      expect(
        g.followingPour,
        isTrue,
        reason: 'declining one pour must not switch the camera off for good',
      );
    });
  });
}
