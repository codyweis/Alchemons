// THE BLOOD RITES, SEEN — every room of Hemavorn in a state worth looking at.
// With `build/room_audit` present it writes BloodRites_<state>.png. It
// asserts that each state draws a different picture: a camera, not a judge.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_blood_rites.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _blood() => CosmicPartyMember(
  instanceId: 'i0',
  baseId: 'b0',
  displayName: 'Blood Mane',
  element: 'Blood',
  family: 'mane',
  level: 10,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  slotIndex: 0,
  staminaBars: 3,
  staminaMax: 3,
);

Future<PlanetDungeonGame> _game(String room, {Set<String> freed = const {}}) async {
  final g = PlanetDungeonGame(
    element: 'Blood',
    party: [_blood()],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  await g.debugLoadFx();
  await g.debugLoadSky();
  await g.debugLoadRiteAllies();
  for (final el in freed) {
    g.discoveredClouds.add(riteFreedId(el));
  }
  final b = g.layout.rooms[room]!.bounds;
  g.onGameResize(Vector2(b.width + 60, b.height + 60));
  g.currentRoomId = room;
  g.creatures.add(DungeonCreature(member: g.party.first));
  g.update(1 / 60);
  return g;
}

/// Put Blood on its square in the room the view is in.
void _place(PlanetDungeonGame g) {
  final at = switch (g.currentRoom.rite?.kind) {
    RiteKind.earth => g.rites.earthAt,
    RiteKind.water => g.rites.water.b,
    RiteKind.fire => g.rites.fire.b,
    RiteKind.air => g.rites.air.b,
    _ => null,
  };
  final p = at == null ? g.layout.entranceSpawn : riteCentreOf(at.x, at.y);
  g.creatures.first
    ..position = p
    ..lastSafe = p;
}

Future<List<int>> _shot(PlanetDungeonGame g, String name, {int frames = 40}) async {
  _place(g);
  for (var i = 0; i < frames; i++) {
    g.update(1 / 60);
  }
  final rec = ui.PictureRecorder();
  g.render(Canvas(rec));
  final img = await rec.endRecording().toImage(g.size.x.round(), g.size.y.round());
  final out = Directory('build/room_audit');
  if (out.existsSync()) {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/room_audit/BloodRites_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
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

  testWidgets('every Blood Rites state draws its own picture', (tester) async {
    await tester.runAsync(() async {
      final shots = <String, List<int>>{};
      const all = {'Air', 'Fire', 'Earth', 'Water'};

      // THE CIRCLE: nothing freed; all four home in their cups; two streams
      // meeting; the quintessence.
      var g = await _game('rite_circle');
      shots['circle_bare'] = await _shot(g, 'circle_bare');
      g = await _game('rite_circle', freed: all);
      shots['circle_cups'] = await _shot(g, 'circle_cups');
      g.rites.outerTurn = 0;
      g.rites.innerTurn = 1;
      shots['circle_fusion'] = await _shot(g, 'circle_fusion', frames: 60);
      g.rites.outerTurn = 1;
      g.rites.innerTurn = 1;
      shots['circle_quintessence'] = await _shot(g, 'circle_quintessence', frames: 90);

      // EARTH: as it starts; the plates turned and every tendril home.
      g = await _game('rite_earth');
      shots['earth_start'] = await _shot(g, 'earth_start');
      final f = g.rites.earthFloor;
      g.rites.earth = TendrilState(const [2, 1], tendrilRoute(f, const [2, 1])!);
      shots['earth_solved'] = await _shot(g, 'earth_solved', frames: 60);

      // WATER: as it starts (with the flip's ghost); turned over once.
      g = await _game('rite_water');
      shots['water_start'] = await _shot(g, 'water_start');
      g.rites.water = flipTurn(g.rites.waterRoom, g.rites.water).state!;
      g.rites.water = flipTurn(g.rites.waterRoom, g.rites.water).state!;
      shots['water_pool'] = await _shot(g, 'water_pool');

      // FIRE: as it starts; the twin two squares off.
      g = await _game('rite_fire');
      shots['fire_start'] = await _shot(g, 'fire_start');
      g.rites.fire = twinStep(g.rites.fireRoom, g.rites.fire, 1).state!;
      g.rites.fire = twinStep(g.rites.fireRoom, g.rites.fire, 2).state!;
      shots['fire_twin'] = await _shot(g, 'fire_twin');

      // AIR: as it starts.
      g = await _game('rite_air');
      shots['air_start'] = await _shot(g, 'air_start');

      // THE VAULT.
      g = await _game('rite_vault');
      shots['vault'] = await _shot(g, 'vault');

      final seen = <String, String>{};
      for (final e in shots.entries) {
        final k = e.value.join(',');
        expect(seen[k], isNull, reason: '${e.key} drew the same picture as ${seen[k]}');
        seen[k] = e.key;
      }
    });
  });
}
