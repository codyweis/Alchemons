// SOLARIN — THE SHADOW FLOOR, RENDERED: the moments, not just the rooms.
//
// The whole-room audit draws every room as it opens, with nothing cast and
// nothing set. Everything this planet is ABOUT is where the shadows fall and
// what has set into stone, so this renders the party in the moments that
// matter and asserts each is a picture of its own (Mud's lesson: a state that
// draws like its neighbour is a state the player cannot read). With
// `build/room_audit` present it writes LightShadow_*.png.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanetDungeonGame> _game(String room, {int stars = 0}) async {
  const els = ['Light', 'Dark', 'Steam'];
  const fams = ['horn', 'wing', 'pip'];
  final party = [
    for (var i = 0; i < 3; i++)
      CosmicPartyMember(
        instanceId: 'i$i',
        baseId: 'b$i',
        displayName: els[i],
        element: els[i],
        family: fams[i],
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
    element: 'Light',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  await g.debugLoadSky();
  final b = kPlanetDungeonLayouts['Light']!.rooms[room]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.entryDoorRevealed = true;
  g.currentRoomId = room;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = b.center
        ..lastSafe = b.center,
    );
  }
  return g;
}

void _place(PlanetDungeonGame g, Map<int, Sq> at) {
  for (final e in at.entries) {
    g.creatures[e.key]
      ..position = shadowCentre(e.value.x, e.value.y)
      ..lastSafe = shadowCentre(e.value.x, e.value.y);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every moment of the shadow floor draws its own picture', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final out = Directory('build/room_audit');
      final shots = <String, int>{};

      Future<void> shoot(
        String name,
        PlanetDungeonGame g, [
        int frames = 40,
      ]) async {
        for (var i = 0; i < frames; i++) {
          g.update(1 / 60);
        }
        final rec = ui.PictureRecorder();
        g.render(Canvas(rec));
        final img = await rec.endRecording().toImage(
          g.size.x.round(),
          g.size.y.round(),
        );
        if (out.existsSync()) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/room_audit/LightShadow_$name.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final b = raw!.buffer.asUint8List();
        var h = 17;
        for (var i = 0; i < b.length; i += 97) {
          h = (h * 31 + b[i]) & 0x3FFFFFFF;
        }
        shots[name] = h;
      }

      // ROOM I — the bridge: Light beside the starlight, its shadow fanned
      // over the glass, Dark out on it.
      var g = await _game('own_shadow');
      _place(g, {0: sq(1, 3), 1: sq(4, 3), 2: sq(1, 5)});
      g.setActive(1);
      await shoot('one_bridge', g);
      // …and Dark pins it: the shadow sets into stone.
      g.activateAbility();
      await shoot('one_pinned', g, 70);

      // ROOM III — two suns: one caster at each starlight.
      g = await _game('two_suns');
      _place(g, {0: sq(1, 3), 1: sq(5, 3), 2: sq(9, 3)});
      g.setActive(1);
      await shoot('three_suns', g);

      // ROOM IV — the veil hanging at the vent.
      g = await _game('two_gaps');
      _place(g, {0: sq(0, 0), 1: sq(1, 0), 2: sq(2, 1)});
      g.setActive(2);
      g.update(1 / 60);
      g.activateAbility();
      await shoot('four_veil', g, 70);

      // THE DOOR OF SHADOW — the starlight behind the door statue, and the
      // pin that cuts a doorway through the blank wall.
      g = await _game('door_of_shadow');
      final s0 = g.archive.state('door_of_shadow');
      g.archive.rooms['door_of_shadow'] = s0.copyWith(rail: 3);
      _place(g, {0: sq(1, 5), 1: sq(3, 4), 2: sq(2, 3)});
      g.setActive(1);
      await shoot('rite_aligned', g);
      g.activateAbility();
      await shoot('rite_door', g, 90);

      // THE ECLIPSE — the walls' shadow from the railed star, then walked on
      // by two turns of the crank.
      g = await _game('eclipse_walk');
      _place(g, {0: sq(0, 5), 1: sq(1, 5), 2: sq(1, 3)});
      await shoot('eclipse_start', g);
      final es = g.archive.state('eclipse_walk');
      g.archive.rooms['eclipse_walk'] = es.copyWith(rail: 3, veil: sq(1, 4));
      await shoot('eclipse_cranked', g);

      // SOLARIN — the star on its orbit, pillars throwing the only floor.
      g = await _game('solarin_orbit', stars: 3);
      _place(g, {0: sq(7, 4), 1: sq(1, 3), 2: sq(1, 5)});
      await shoot('solarin', g);
      // …its flare gathering on the square the active body stands on, and
      // Light burning on bare glass in its light.
      g.guardianAwake = true;
      g.setActive(0);
      g.creatures[0].position = shadowCentre(8, 1);
      g.archive
        ..swingNext = 99
        ..flareNext = 0;
      await shoot('solarin_flare', g, 40);
      // …and gathering to swing: its next place, and the shadow it will cast.
      g.creatures[0].position = shadowCentre(7, 4);
      g.archive
        ..swingNext = 0.5
        ..flareSq = null
        ..flareNext = 99;
      await shoot('solarin_warn', g, 10);

      // THE HALL — dark star, then the near spans set, then the whole bridge.
      g = await _game('light_hall');
      g.entryDoorRevealed = false;
      await shoot('hall_dark', g);
      g.entryDoorRevealed = true;
      g.archive.solved.addAll(['own_shadow', 'key_room']);
      await shoot('hall_near', g, 120);
      g.archive.solved.addAll(['two_suns', 'two_gaps']);
      await shoot('hall_whole', g, 120);

      // ROOM II — the arch as light, the veil with the shadow in it, the key
      // set in the lock.
      g = await _game('key_room');
      await shoot('key_light', g);
      g.archive.keyVeil = true;
      g.archive.keyLampX = 5;
      g.archive.keyLampY = 4.0;
      await shoot('key_veil', g, 90);
      g.archive.keyLampX = kKeyAnswerX;
      g.archive.keyLampY = kKeyAnswerY;
      g.archive.keyPinned = true;
      g.archive.keyT = -9;
      await shoot('key_set', g, 90);

      // Every moment is its own picture.
      final distinct = shots.values.toSet();
      expect(
        distinct.length,
        shots.length,
        reason: 'two moments drew the same picture: $shots',
      );
    });
  });
}
