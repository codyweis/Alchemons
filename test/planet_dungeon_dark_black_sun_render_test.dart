// THE BLACK SUN, SEEN — every room of Nythralor in a state worth looking at:
// portals open (and their windows), beams white and blood, bridges over the
// void, a chamber set, the maxim's ring. With `build/room_audit` present it
// writes DarkSun_<state>.png. It asserts that each state draws a different
// picture: it is a camera, not a judge.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(int i, String el, String fam) => CosmicPartyMember(
  instanceId: 'i$i',
  baseId: 'b$i',
  displayName: '$el $fam',
  element: el,
  family: fam,
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: i,
  staminaBars: 3,
  staminaMax: 3,
);

Future<PlanetDungeonGame> _game(String room, {int stars = 0}) async {
  final party = [_m(0, 'Dark', 'mask'), _m(1, 'Dark', 'wing'), _m(2, 'Light', 'horn')];
  final g = PlanetDungeonGame(
    element: 'Dark',
    party: party,
    initialStarMask: stars,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  await g.debugLoadSky();
  for (var i = 0; i < 3; i++) {
    if ((stars & (1 << i)) != 0) g.earnStar(i);
  }
  final b = g.layout.rooms[room]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.currentRoomId = room;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m));
  }
  g.update(1 / 60);
  return g;
}

SunAt at(String room, int x, int y) => (room: room, x: x, y: y);
SunEnd end(String room, int x, int y, int d) =>
    (room: room, face: kSunRooms[room]!.faceAt(x, y, d)!);

/// Put the three where [pos] says, with [ends] cast and Light shining [shine].
void stage(
  PlanetDungeonGame g,
  Map<String, SunAt> pos, {
  Map<String, List<SunEnd?>>? ends,
  int shine = -1,
}) {
  g.blackSun.state = g.blackSun.state.copyWith(
    pos: pos,
    ends: ends ?? g.blackSun.state.ends,
    shine: shine,
  );
  for (final c in g.creatures) {
    final n = c.member.element == 'Light'
        ? 'light'
        : identical(c, g.creatures.first)
        ? 'purple'
        : 'orange';
    final p = pos[n]!;
    c
      ..position = sunCentre(p.x, p.y)
      ..lastSafe = sunCentre(p.x, p.y);
  }
}

Future<List<int>> _shot(PlanetDungeonGame g, String name, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    g.update(1 / 60);
  }
  final rec = ui.PictureRecorder();
  g.render(Canvas(rec));
  final img = await rec.endRecording().toImage(g.size.x.round(), g.size.y.round());
  final out = Directory('build/room_audit');
  if (out.existsSync()) {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/room_audit/DarkSun_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = raw!.buffer.asUint8List();
  var h = 0;
  for (var i = 0; i < bytes.length; i += 4 * 97) {
    h = (h * 31 + bytes[i] + bytes[i + 1] * 7 + bytes[i + 2] * 13) & 0x3fffffff;
  }
  return [h, bytes.length];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every Black Sun state draws its own picture', (tester) async {
    await tester.runAsync(() async {
      final shots = <String, List<int>>{};

      // The porch, bare, and with the purple portal across the void.
      var g = await _game('sun_porch');
      shots['porch_bare'] = await _shot(g, 'porch_bare');
      stage(
        g,
        {'purple': at('sun_porch', 1, 1), 'light': at('sun_porch', 2, 2), 'orange': at('sun_porch', 2, 3)},
        ends: {
          'purple': [end('sun_porch', 0, 2, 1), end('sun_porch', 10, 2, 3)],
          'orange': [null, null],
        },
      );
      shots['porch_portal'] = await _shot(g, 'porch_portal');

      // II: the beam round the corner through the orange portal.
      g = await _game('through_the_dark');
      stage(
        g,
        {'light': at('through_the_dark', 1, 3), 'purple': at('through_the_dark', 3, 1), 'orange': at('through_the_dark', 7, 1)},
        ends: {
          'purple': [null, null],
          'orange': [end('through_the_dark', 10, 3, 3), end('through_the_dark', 5, 5, 0)],
        },
        shine: 1,
      );
      shots['two_white'] = await _shot(g, 'two_white');

      // III: blood on the red seal, through both.
      g = await _game('two_darks');
      stage(
        g,
        {'light': at('two_darks', 1, 2), 'purple': at('two_darks', 5, 3), 'orange': at('two_darks', 6, 1)},
        ends: {
          'purple': [end('two_darks', 7, 2, 3), end('two_darks', 1, 4, 0)],
          'orange': [end('two_darks', 1, 0, 2), end('two_darks', 3, 4, 0)],
        },
        shine: 1,
      );
      shots['three_blood'] = await _shot(g, 'three_blood');

      // IV: the blood bridge, the orange Dark walking into it.
      g = await _game('into_the_light');
      stage(
        g,
        {'light': at('into_the_light', 1, 1), 'purple': at('into_the_light', 3, 2), 'orange': at('into_the_light', 7, 3)},
        ends: {
          'purple': [end('into_the_light', 12, 4, 3), end('into_the_light', 2, 6, 0)],
          'orange': [end('into_the_light', 0, 4, 1), end('into_the_light', 12, 3, 3)],
        },
      );
      shots['four_bridge'] = await _shot(g, 'four_bridge');

      // The Hall with its stars lit, the island bridge, and a window from
      // the Hall into the porch.
      g = await _game('sun_hall', stars: 1);
      stage(
        g,
        {'light': at('sun_hall', 5, 3), 'purple': at('sun_hall', 4, 4), 'orange': at('sun_hall', 3, 6)},
        ends: {
          'purple': [end('sun_hall', 10, 7, 3), end('sun_hall', 2, 8, 0)],
          'orange': [end('sun_hall', 2, 0, 2), end('sun_hall', 5, 0, 2)],
        },
      );
      shots['hall_island'] = await _shot(g, 'hall_island');
      stage(
        g,
        {'light': at('sun_hall', 5, 7), 'purple': at('sun_hall', 4, 6), 'orange': at('sun_hall', 6, 7)},
        ends: {
          'purple': [end('sun_hall', 2, 8, 0), end('sun_porch', 10, 2, 3)],
          'orange': [null, null],
        },
      );
      shots['hall_window'] = await _shot(g, 'hall_window');
      // At a phone's size: the room pulls back to fit, whole.
      g.onGameResize(Vector2(820, 420));
      shots['hall_phone'] = await _shot(g, 'hall_phone');

      // The Heart, and the arena's black holes.
      // The rite: the Lantern with Light holding the door and the star's
      // beam thrown down through purple's portal; the Heart with the chain
      // burning on the Great Seal and the red black sun rising.
      g = await _game('sun_lantern', stars: 3);
      stage(
        g,
        {
          'light': at('sun_lantern', 2, 3),
          'purple': at('sun_heart', 1, 1),
          'orange': at('sun_heart', 4, 1),
        },
        ends: {
          'purple': [end('sun_lantern', 9, 2, 3), end('sun_heart', 0, 2, 1)],
          'orange': [end('sun_heart', 9, 2, 3), end('sun_heart', 3, 0, 2)],
        },
        shine: 2,
      );
      shots['lantern'] = await _shot(g, 'lantern');
      g = await _game('sun_heart', stars: 3);
      stage(
        g,
        {
          'light': at('sun_lantern', 2, 3),
          'purple': at('sun_heart', 1, 1),
          'orange': at('sun_heart', 5, 1),
        },
        ends: {
          'purple': [end('sun_lantern', 9, 2, 3), end('sun_heart', 0, 2, 1)],
          'orange': [end('sun_heart', 9, 2, 3), end('sun_heart', 3, 0, 2)],
        },
        shine: 2,
      );
      g.blackSun.state = g.blackSun.state.copyWith(latched: {kSunRiteLatch});
      shots['heart'] = await _shot(g, 'heart', frames: 160);
      g = await _game('noctryos_totality', stars: 3);
      shots['arena'] = await _shot(g, 'arena');

      // Every state is its own picture.
      final seen = <String>{};
      for (final e in shots.entries) {
        expect(seen.add('${e.value}'), isTrue, reason: '${e.key} drew the same picture as another state');
      }
      expect(shots.length, greaterThan(8));
      expect(pi, isNonZero);
    });
  });
}
