// PALUSIA, DRAWN. A smoke render of every room in the Sinking Altar, plus the
// fen states that matter — untouched mire, a dragged road, a drowned channel,
// the lotus adrift.
//
// It asserts only that the painters run and that the fen's states look
// DIFFERENT from one another, because that is the part a unit test cannot
// reach and the part that has broken most often on every other planet. Pass
// nothing: `mkdir -p build/mud_shots` and run this to get the pictures, which
// is the whole reason the file exists (the Poison precedent — `flutter test`
// passes neither --dart-define nor the environment through to the isolate).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_mud.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _out = 'build/mud_shots';

PlanetDungeonGame _game() {
  const els = ['Mud', 'Plant', 'Water'];
  const fams = {'Mud': 'mane', 'Plant': 'pip', 'Water': 'mask'};
  final party = [
    for (final e in els)
      CosmicPartyMember(
        instanceId: 'i$e',
        baseId: 'b$e',
        displayName: e,
        element: e,
        family: fams[e]!,
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
    element: 'Mud',
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

Future<int> _shot(
  PlanetDungeonGame g,
  String room,
  String name, {
  Offset? at,
}) async {
  g.currentRoomId = room;
  final stand = at ?? mudLayout.rooms[room]!.bounds.center;
  for (final c in g.creatures) {
    c
      ..position = stand
      ..lastSafe = stand;
  }
  // Let the camera arrive: it lerps toward the party, so one tick leaves the
  // shot pointing wherever the last one was.
  for (var i = 0; i < 24; i++) {
    g.update(1 / 60);
  }
  final rec = ui.PictureRecorder();
  g.render(Canvas(rec));
  final img = await rec.endRecording().toImage(900, 600);
  if (Directory(_out).existsSync()) {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = raw!.buffer.asUint8List();
  var sum = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    sum = (sum + bytes[i] * 3 + bytes[i + 1] * 5 + bytes[i + 2] * 7) & 0x3FFFFFF;
  }
  return sum;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every room in the fen puts ink down', (tester) async {
    await tester.runAsync(() async {
      final g = _game();
      final seen = <String, int>{};
      for (final id in mudLayout.rooms.keys) {
        final sum = await _shot(g, id, id);
        expect(sum, isNonZero, reason: '$id drew nothing at all');
        seen[id] = sum;
      }
      expect(seen, hasLength(mudLayout.rooms.length));
    });
  });

  testWidgets('the fen LOOKS different in its three states', (tester) async {
    await tester.runAsync(() async {
      final g = _game()..entryDoorRevealed = true;
      g.bog.field.reset();
      final mire = await _shot(g, 'mire_gate', 'fen_0_mire');

      // Drag the gate's own crossing to sod; its slough-neighbour drowns.
      g.bog.field.harden('add_head');
      final dragged = await _shot(g, 'mire_gate', 'fen_1_sod');
      expect(
        dragged,
        isNot(mire),
        reason: 'a dragged crossing has to CHANGE the picture of the fen',
      );

      // THE GATE WITH ALL THREE STATES AT ONCE — the picture that has to be
      // readable from the middle of the room.
      g.bog.field.reset();
      g.bog.field.harden('add_head'); // sod; drowns add_neck (not here)
      g.bog.field.harden('cor_neck'); // drowns cor_head, at the gate
      await _shot(g, 'mire_gate', 'fen_3_all_three');

      // The lotus, cut adrift and riding down.
      g.bog.field.reset();
      g.bog.field.harden('cor_neck');
      g.bog.field.harden('add_neck');
      final adrift = await _shot(g, 'lotus_knoll', 'fen_2_adrift');
      expect(adrift, isNonZero);
    });
  });

  testWidgets('the knolls, with the fen open', (tester) async {
    await tester.runAsync(() async {
      final g = _game()..entryDoorRevealed = true;
      g.bog.field.reset();
      g.bog.field.harden('add_neck');
      for (final id in const [
        'mire_gate',
        'hag_knoll',
        'altar_knoll',
        'sedge_knoll',
        'cairn_knoll',
        'lotus_knoll',
      ]) {
        expect(await _shot(g, id, 'open_' + id), isNonZero);
      }
    });
  });
}
