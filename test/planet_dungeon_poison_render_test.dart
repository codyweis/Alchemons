// THE ROOMS, DRAWN. A smoke render of every surface the cauldron redesign
// added — the pot with nothing in it, with one thing in it, and with a brew
// standing on its rim; and each ward's ingredient board.
//
// It asserts only that the painters run and put ink down, because that is the
// part a unit test cannot reach and the part that has broken most often. Pass
// `--dart-define=OUT=<dir>` to keep the PNGs and actually look at them, which
// is the whole reason this file exists.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = String.fromEnvironment('OUT');

PlanetDungeonGame _game() {
  const els = ['Poison', 'Plant', 'Mud'];
  final party = [
    for (final e in els)
      CosmicPartyMember(
        instanceId: 'i$e',
        baseId: 'b$e',
        displayName: e,
        element: e,
        family: e == 'Poison' ? 'mask' : (e == 'Plant' ? 'horn' : 'mane'),
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: els.indexOf(e),
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: 'Poison',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.onGameResize(Vector2(900, 600));
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = const Offset(200, 300)
        ..lastSafe = const Offset(200, 300),
    );
  }
  return g;
}

/// Renders [room] and returns a checksum of the pixels. The whole canvas is
/// opaque, so counting lit pixels proves nothing (it is always 900×600) —
/// what matters is whether the ink CHANGED.
Future<int> _shot(PlanetDungeonGame g, String room, String name) async {
  g.currentRoomId = room;
  final b = poisonLayout.rooms[room]!.bounds;
  for (final c in g.creatures) {
    c.position = b.center;
    c.lastSafe = b.center;
  }
  g.update(1 / 60);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  g.render(canvas);
  final img = await rec.endRecording().toImage(900, 600);
  if (_out.isNotEmpty) {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = raw!.buffer.asUint8List();
  var sum = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    sum =
        (sum + bytes[i] * 3 + bytes[i + 1] * 5 + bytes[i + 2] * 7) & 0x3FFFFFF;
  }
  return sum;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('the cauldron and the boards actually draw', (tester) async {
    await tester.runAsync(() async {
      final g = _game();
      final empty = await _shot(g, 'apothecary', 'p_pot_empty');
      expect(empty, isNonZero, reason: 'the room drew nothing at all');

      final still = poisonLayout.rooms['apothecary']!.apothecary!;
      final a = g.creatures.first..position = still.cistern;
      a.lastSafe = still.cistern;
      g.activeIndex = 0;
      g.activateAbility();
      expect(g.monastery.pot, hasLength(1));
      final one = await _shot(g, 'apothecary', 'p_pot_one');
      expect(
        one,
        isNot(empty),
        reason:
            'a give has to CHANGE the pot — an unchanged pot is why this '
            'read as pressing a button at a prop',
      );

      final b = g.creatures[1]..position = still.cistern;
      b.lastSafe = still.cistern;
      g.activeIndex = 1;
      g.activateAbility();
      expect(g.monastery.carriedPotion, isNotNull);
      final made = await _shot(g, 'apothecary', 'p_pot_made');
      expect(
        made,
        isNot(one),
        reason: 'a finished brew has to be visible on the rim',
      );

      for (final p in kPlaguePotions) {
        final lit = await _shot(g, p.wardId, 'p_${p.wardId}');
        expect(lit, isNonZero, reason: '\${p.wardId} drew nothing');
      }
    });
  });
}
